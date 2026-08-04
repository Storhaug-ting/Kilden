#requires -Version 7.0
<#
.SYNOPSIS
    Kildemodul: Lovdata sitt åpne API – gjeldende lover og sentrale forskrifter
    som maskinlesbar XML.

.DESCRIPTION
    Henter FAKTA – den offisielle, konsoliderte regelverksteksten – fra Lovdata
    sitt åpne API, og gjør den om til markdown på et fast, deterministisk
    format. Modulen tolker ikke innholdet; den speiler kildens struktur
    (kapittel, paragraf, ledd, liste, endringsnote, fotnote) 1:1.

    Kilder:
      https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2
      https://api.lovdata.no/v1/publicData/get/gjeldende-sentrale-forskrifter.tar.bz2

    Datasettene inneholder alle gjeldende norske lover, respektive alle
    gjeldende sentrale forskrifter, som XML-kompatibel HTML med semantisk
    struktur (section / legalArticle / legalP / defaultList). Begge datasettene
    bruker samme oppmerking, så konverteringen er den samme; det som skiller
    dem er filnavn, katalogoppsett og hvilken adresse dokumentet har på
    lovdata.no. Se $script:Dokumenttyper. Én nedlasting dekker hele datasettet,
    og Lovdata legger ut nye pakker hver natt.

    Determinisme er hele poenget: samme kildefil gir alltid nøyaktig samme
    markdown, byte for byte. Derfor skrives det aldri tidsstempler eller andre
    variable verdier inn i markdownen. Provenans (hentedato + SHA256) håndteres
    av ../Update-Lovtekst.ps1 i hver kildes egen kilde.psd1.

    Rettslig grunnlag: åndsverklova § 14 – lover, forskrifter og andre vedtak
    av offentlig myndighet er uten opphavsrettslig vern. Lovdata tilbyr i
    tillegg gjeldende regelverk gjennom dette API-et «helt uten
    bruksbegrensninger», mot at Lovdata krediteres som kilde. Hver genererte
    fil inneholder derfor en kildehenvisning til Lovdata.

    Denne modulen er en trimmet versjon med færre funksjoner enn en full
    Lovdata-klient. Funksjoner for å søke opp et dokument på navn
    (Get-LovdataDatasettliste, Get-LovdataIndeks, Find-LovdataLov) er ikke
    tatt med her, siden hver kilde i Kilden allerede har lov-id-en sin i
    kilde.psd1 og ikke trenger søk.
#>

Set-StrictMode -Version Latest

$script:ApiBase = 'https://api.lovdata.no/v1/publicData'
$script:StandardDatasett = 'gjeldende-lover'
$script:Headers = @{ 'User-Agent' = 'Kilden-lovtekst-generator' }

# Det som skiller de to datasettene fra hverandre. Oppmerkingen inne i XML-en er
# den samme, så konverteringen trenger ingen særtilfeller – men filnavnet,
# løpenummerbredden og adressen dokumentet har på lovdata.no er ulik:
#
#   Filprefiks   nl- for lover, sf- for forskrifter.
#   Nummerbredde Lover har tresifret løpenummer (nl-19630621-023), forskrifter
#                firesifret (sf-20100326-0488).
#   Dokumentsti  lover ligger under NL/lov, forskrifter under SF/forskrift.
$script:Dokumenttyper = @{
    'gjeldende-lover'                 = @{
        Filprefiks   = 'nl'
        Nummerbredde = 3
        Dokumentsti  = 'NL/lov'
    }
    'gjeldende-sentrale-forskrifter'  = @{
        Filprefiks   = 'sf'
        Nummerbredde = 4
        Dokumentsti  = 'SF/forskrift'
    }
}

# Tagger som alltid starter en ny markdown-blokk.
$script:BlokkTagger = @('section', 'article', 'ol', 'ul', 'li', 'footer', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6')

# Metadatafelt som ikke hører hjemme i markdownen:
#   table-of-contents – gjengis allerede som overskrifter i selve teksten
#   title             – står som H1 øverst
$script:HoppOverMeta = @('table-of-contents', 'title')

#region Datasett

function Get-LovdataDokumenttype {
    <#
    .SYNOPSIS
        Slår opp filnavn- og adressekonvensjonene for et datasett.
    .DESCRIPTION
        Se $script:Dokumenttyper. Et ukjent datasett stoppes her, med de kjente
        navnene i feilmeldingen, framfor å gi et filnavn som ikke finnes.
    .PARAMETER Datasett
        Datasettnavn, f.eks. «gjeldende-lover».
    .OUTPUTS
        Hashtabell med Filprefiks, Nummerbredde og Dokumentsti.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Datasett)

    $type = $script:Dokumenttyper[$Datasett]
    if (-not $type) {
        $kjente = ($script:Dokumenttyper.Keys | Sort-Object) -join ', '
        throw "Ukjent datasett: '$Datasett'. Modulen håndterer $kjente."
    }
    $type
}

function Get-LovdataDatasett {
    <#
    .SYNOPSIS
        Laster ned og pakker ut et datasett fra Lovdata sitt åpne API.
    .DESCRIPTION
        Datasettet lastes ned én gang og pakkes ut i en cache-mappe.
        Bruk -Force for å hente på nytt selv om cachen finnes.

        NB: API-et tilbyr kun GJELDENDE (konsolidert) regelverk. Historiske og
        opphevede versjoner ligger i Lovdata Pro og er ikke tilgjengelige her.
        Vil du feste deg til en bestemt utgave, bruk Sha256 fra dette objektet
        - det identifiserer nøyaktig hvilken pakke tekstene kom fra.
    .PARAMETER Navn
        Datasett fra Lovdata. Standard «gjeldende-lover».
    .PARAMETER CachePath
        Mappe for nedlasting/utpakking. Standard: undermappe i temp.
    .PARAMETER Force
        Last ned på nytt selv om arkivet allerede er hentet.
    .OUTPUTS
        PSCustomObject med Navn, Url, ArkivSti, XmlKataloger, Sha256 og AntallDokumenter.
    .EXAMPLE
        Get-LovdataDatasett
    .EXAMPLE
        Get-LovdataDatasett -Navn gjeldende-sentrale-forskrifter
    #>
    [CmdletBinding()]
    param(
        [string] $Navn = $script:StandardDatasett,
        [string] $CachePath,
        [switch] $Force
    )

    Get-LovdataDokumenttype -Datasett $Navn | Out-Null

    if (-not $CachePath) {
        $CachePath = Join-Path ([System.IO.Path]::GetTempPath()) "lovdata-$Navn"
    }

    $url = "$script:ApiBase/get/$Navn.tar.bz2"
    $arkiv = Join-Path $CachePath "$Navn.tar.bz2"
    $utpakket = Join-Path $CachePath 'utpakket'

    if ($Force -or -not (Test-Path $arkiv)) {
        New-Item -ItemType Directory -Force -Path $CachePath | Out-Null
        Write-Verbose "Lovdata API: laster ned $url"
        Invoke-WebRequest -Uri $url -Headers $script:Headers -OutFile $arkiv -TimeoutSec 600
    } else {
        Write-Verbose "Lovdata API: bruker hurtiglagret arkiv $arkiv"
    }

    if ($Force -or -not (Test-Path $utpakket)) {
        if (Test-Path $utpakket) { Remove-Item $utpakket -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $utpakket | Out-Null
        Write-Verbose 'Lovdata API: pakker ut arkivet'
        tar -xjf $arkiv -C $utpakket
        if ($LASTEXITCODE -ne 0) { throw "Klarte ikke å pakke ut $arkiv (tar ga kode $LASTEXITCODE)." }
    }

    # Arkivet legger dokumentene i undermapper. Lovene ligger samlet i én (nl),
    # mens forskriftene er delt på fire (sf, del, ins, stv) etter hva slags
    # vedtak de er. Alle må med, ellers finner vi ikke igjen dokumentet.
    $xmlKataloger = @(Get-ChildItem $utpakket -Directory | Sort-Object Name | Select-Object -ExpandProperty FullName)
    if (-not $xmlKataloger) { throw "Fant ingen dokumentkatalog i det utpakkede datasettet ($utpakket)." }

    [pscustomobject]@{
        Navn             = $Navn
        Url              = $url
        ArkivSti         = $arkiv
        XmlKataloger     = $xmlKataloger
        Sha256           = (Get-FileHash -Path $arkiv -Algorithm SHA256).Hash.ToLowerInvariant()
        AntallDokumenter = @($xmlKataloger | ForEach-Object { Get-ChildItem $_ -Filter '*.xml' -File }).Count
    }
}

function ConvertTo-LovdataFilnavn {
    <#
    .SYNOPSIS
        Gjør en Lovdata-id om til filnavnet datasettet bruker.
    .DESCRIPTION
        «1965-06-18-6» blir «nl-19650618-006.xml». Lover uten løpenummer
        («1968-11-29») får 000. Forskriftsdatasettet bruker prefikset sf- og
        firesifret løpenummer, så «2010-03-26-488» blir «sf-20100326-0488.xml».
    .PARAMETER LovId
        Lovdata-id, f.eks. «1963-06-21-23».
    .PARAMETER Datasett
        Datasettet id-en hører til. Standard «gjeldende-lover».
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $LovId,
        [string] $Datasett = $script:StandardDatasett
    )

    $type = Get-LovdataDokumenttype -Datasett $Datasett

    $deler = $LovId -split '-'
    if ($deler.Count -lt 3) { throw "Ugyldig lov-id: '$LovId'. Forventet formatet ÅÅÅÅ-MM-DD[-nr]." }

    $dato = '{0:0000}{1:00}{2:00}' -f [int]$deler[0], [int]$deler[1], [int]$deler[2]
    $nummer = if ($deler.Count -ge 4) { [int]$deler[3] } else { 0 }
    '{0}-{1}-{2}.xml' -f $type.Filprefiks, $dato, ([string]$nummer).PadLeft($type.Nummerbredde, '0')
}

function Find-LovdataDokument {
    <#
    .SYNOPSIS
        Finner XML-filen til ett dokument i et utpakket datasett.
    .DESCRIPTION
        Leter i alle dokumentkatalogene i datasettet, siden forskriftene er delt
        på flere. Returnerer $null hvis dokumentet ikke finnes, slik at den som
        kaller kan si hvilken kilde det gjaldt.
    .PARAMETER Datasett
        Resultatet fra Get-LovdataDatasett.
    .PARAMETER LovId
        Lovdata-id på formen «2010-03-26-488».
    .OUTPUTS
        PSCustomObject med Filnavn og Sti, eller $null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][psobject] $Datasett,
        [Parameter(Mandatory)][string] $LovId
    )

    $filnavn = ConvertTo-LovdataFilnavn -LovId $LovId -Datasett $Datasett.Navn

    foreach ($katalog in $Datasett.XmlKataloger) {
        $sti = Join-Path $katalog $filnavn
        if (Test-Path -LiteralPath $sti) {
            return [pscustomobject]@{ Filnavn = $filnavn; Sti = $sti }
        }
    }

    $null
}

#endregion

#region XML-hjelpere

function ConvertTo-LovdataXml {
    <#
    .SYNOPSIS
        Leser en lovfil (fra datasettet eller en lokal snapshot) og returnerer rot-elementet.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    $innhold = [System.IO.File]::ReadAllText($Path)
    # Filene starter med en HTML-doctype som XML-parseren ikke trenger.
    $innhold = [regex]::Replace($innhold, '^\s*<!DOCTYPE[^>]*>', '')

    $doc = [System.Xml.XmlDocument]::new()
    $doc.PreserveWhitespace = $true
    $doc.LoadXml($innhold)
    $doc.DocumentElement
}

function Get-CssClass {
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Xml.XmlNode] $Node)

    if ($Node.NodeType -ne [System.Xml.XmlNodeType]::Element) { return @() }
    $raw = ([System.Xml.XmlElement]$Node).GetAttribute('class')
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    $raw -split '\s+' | Where-Object { $_ }
}

function Format-Avsnitt {
    <#
    .SYNOPSIS
        Normaliserer whitespace i et avsnitt til én linje.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Text)

    $t = $Text -replace '\u00A0', ' '
    $t = $t -replace '\s+', ' '
    $t.Trim()
}

#endregion

#region Inline-rendering

function ConvertTo-InlineMarkdown {
    <#
    .SYNOPSIS
        Gjengir innholdet i en node som markdown på én linje.
    .DESCRIPTION
        Kryssreferanser (<a>) flates ut til ren tekst. De peker på
        Lovdata-interne, relative URL-er som ikke gir mening i en markdown-fil,
        og lovteksten er ordrett den samme uten dem.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Xml.XmlNode] $Node)

    $sb = [System.Text.StringBuilder]::new()

    foreach ($child in $Node.ChildNodes) {
        if ($child.NodeType -in @([System.Xml.XmlNodeType]::Text,
                [System.Xml.XmlNodeType]::Whitespace,
                [System.Xml.XmlNodeType]::SignificantWhitespace)) {
            [void]$sb.Append($child.Value)
            continue
        }
        if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }

        switch ($child.LocalName) {
            { $_ -in 'em', 'i' } {
                $inner = (ConvertTo-InlineMarkdown -Node $child).Trim()
                if ($inner) { [void]$sb.Append("*$inner*") }
                break
            }
            { $_ -in 'strong', 'b' } {
                $inner = (ConvertTo-InlineMarkdown -Node $child).Trim()
                if ($inner) { [void]$sb.Append("**$inner**") }
                break
            }
            'sup' {
                $inner = (ConvertTo-InlineMarkdown -Node $child).Trim()
                if ($inner) { [void]$sb.Append("<sup>$inner</sup>") }
                break
            }
            'br' { [void]$sb.Append(' '); break }
            default { [void]$sb.Append((ConvertTo-InlineMarkdown -Node $child)) }
        }
    }

    $sb.ToString()
}

function Get-DirekteTekst {
    <#
    .SYNOPSIS
        Gjengir en node inline, men hopper over blokk-barn.
    .DESCRIPTION
        Et <article class="legalP"> kan inneholde både løpende tekst og en
        nøstet liste. Teksten og lista skal bli hver sin markdown-blokk, så
        lister/underartikler holdes utenfor når selve avsnittet gjengis.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Xml.XmlNode] $Node)

    $sb = [System.Text.StringBuilder]::new()

    foreach ($child in $Node.ChildNodes) {
        if ($child.NodeType -in @([System.Xml.XmlNodeType]::Text,
                [System.Xml.XmlNodeType]::Whitespace,
                [System.Xml.XmlNodeType]::SignificantWhitespace)) {
            [void]$sb.Append($child.Value)
            continue
        }
        if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
        if ($child.LocalName -in $script:BlokkTagger) { continue }
        [void]$sb.Append((ConvertTo-InlineMarkdown -Node $child))
    }

    $sb.ToString()
}

#endregion

#region Blokk-rendering

function ConvertTo-BlockMarkdown {
    <#
    .SYNOPSIS
        Går rekursivt gjennom lovteksten og sender ut én streng per markdown-blokk.
    .PARAMETER Node
        Noden som skal gjengis.
    .PARAMETER Depth
        Innrykksnivå for lister (0 = ingen innrykk).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Xml.XmlNode] $Node,
        [int] $Depth = 0
    )

    foreach ($child in $Node.ChildNodes) {
        if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }

        $classes = Get-CssClass -Node $child

        switch -Regex ($child.LocalName) {

            '^h[1-6]$' {
                $level = [int]$child.LocalName.Substring(1)
                $text = if ($classes -contains 'legalArticleHeader') {
                    Get-ParagrafOverskrift -Header $child
                } else {
                    Format-Avsnitt (ConvertTo-InlineMarkdown -Node $child)
                }
                $text = Format-Overskrift $text
                if ($text) { ('#' * $level) + ' ' + $text }
                break
            }

            '^(section|footer)$' {
                ConvertTo-BlockMarkdown -Node $child -Depth $Depth
                break
            }

            '^article$' {
                # changesToParent = Lovdatas endringsnote, gjengis i kursiv.
                if ($classes -contains 'changesToParent') {
                    $text = Format-Avsnitt (ConvertTo-InlineMarkdown -Node $child)
                    if ($text) { "*$text*" }
                    break
                }
                if ($classes -contains 'footnote') {
                    $note = Get-Fotnote -Node $child -Depth $Depth
                    if ($note) { $note }
                    break
                }

                # Egen tekst først, deretter eventuelle nøstede lister.
                $egen = Format-Avsnitt (Get-DirekteTekst -Node $child)
                if ($egen) { (' ' * (4 * $Depth)) + $egen }
                ConvertTo-BlockMarkdown -Node $child -Depth $Depth
                break
            }

            '^(ol|ul)$' {
                ConvertTo-BlockMarkdown -Node $child -Depth ($Depth + 1)
                break
            }

            '^li$' {
                Get-ListePunkt -Item $child -Depth $Depth
                break
            }

            '^p$' {
                $text = Format-Avsnitt (Get-DirekteTekst -Node $child)
                if ($text) { (' ' * (4 * $Depth)) + $text }
                ConvertTo-BlockMarkdown -Node $child -Depth $Depth
                break
            }

            default {
                ConvertTo-BlockMarkdown -Node $child -Depth $Depth
            }
        }
    }
}

# Forkortelser som slutter på punktum uten å ha interne punktum. Uten denne
# lista ville «Meldingar mv.» blitt til «Meldingar mv» når overskrifter renskes.
# Forkortelser med interne punktum (o.a., m.m., m.v., o.l.) fanges av regelen
# i Format-Overskrift og trenger ikke stå her.
$script:Forkortelser = @(
    'mv.', 'osv.', 'jf.', 'nr.', 'pkt.', 'flg.', 'mfl.', 'kap.', 'jfr.', 'evt.'
)

function Format-Overskrift {
    <#
    .SYNOPSIS
        Fjerner avsluttende punktum fra en overskrift.
    .DESCRIPTION
        Lovdata setter punktum etter kapitteltitler og paragrafnummer
        («Kva lova gjeld.», «§ 1.»). I markdown er det støy i overskriftene, så
        det avsluttende punktumet fjernes.

        Punktum midt i overskriften beholdes – «§ 1-1. Verkeområde» er
        paragrafnummer og tittel, ikke en avsluttet setning.

        Forkortelser beskyttes: «Meldingar mv.» og «Bruk o.a.» beholder
        punktumet, ellers ville forkortelsen blitt feil.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Tekst)

    $t = $Tekst.Trim()
    if (-not $t.EndsWith('.')) { return $t }

    $siste = ($t -split '\s+')[-1]

    # Interne punktum betyr forkortelse: o.a., m.m., m.v., o.l.
    if ($siste.TrimEnd('.').Contains('.')) { return $t }

    if ($script:Forkortelser -contains $siste.ToLowerInvariant()) { return $t }

    $t.TrimEnd('.').TrimEnd()
}

function Get-ParagrafOverskrift {
    <#
    .SYNOPSIS
        Setter sammen «§ 1-1. Verkeområde. Definisjonar» fra paragrafhodet.
    .DESCRIPTION
        Paragrafnummeret ligger i span.legalArticleValue, punktumet som fri
        tekst etter, og en eventuell tittel i span.legalArticleTitle.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Xml.XmlNode] $Header)

    $verdi = ''
    $tittel = ''
    foreach ($span in $Header.SelectNodes('.//span')) {
        $klasser = Get-CssClass -Node $span
        if ($klasser -contains 'legalArticleValue') {
            $verdi = Format-Avsnitt (ConvertTo-InlineMarkdown -Node $span)
        } elseif ($klasser -contains 'legalArticleTitle') {
            $tittel = Format-Avsnitt (ConvertTo-InlineMarkdown -Node $span)
        }
    }

    if (-not $verdi) { return Format-Avsnitt (ConvertTo-InlineMarkdown -Node $Header) }
    if ($tittel) { "$verdi. $tittel" } else { "$verdi." }
}

function Get-ListePunkt {
    <#
    .SYNOPSIS
        Gjengir et listepunkt med kildens eget merke («a.», «1.», …).
    .DESCRIPTION
        Merket står i data-name på <li>. Første tekstblokk slås sammen med
        merket; eventuelle flere avsnitt i samme punkt kommer som egne blokker
        med samme innrykk.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Xml.XmlNode] $Item,
        [int] $Depth = 0
    )

    $merke = ([System.Xml.XmlElement]$Item).GetAttribute('data-name')
    $innrykk = ' ' * (4 * [Math]::Max(0, $Depth - 1))

    $blokker = @(ConvertTo-BlockMarkdown -Node $Item -Depth $Depth)
    if ($blokker.Count -eq 0) {
        if ($merke) { "$innrykk$merke" }
        return
    }

    $forste = $blokker[0].TrimStart()
    if ($merke) { "$innrykk$merke $forste" } else { "$innrykk$forste" }
    if ($blokker.Count -gt 1) { $blokker[1..($blokker.Count - 1)] }
}

function Get-Fotnote {
    <#
    .SYNOPSIS
        Gjengir en fotnote i kursiv, med kildens eget nummer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Xml.XmlNode] $Node,
        [int] $Depth = 0
    )

    $nummer = ''
    $etikett = $Node.SelectSingleNode('./span[contains(@class,"footnoteLabel")]')
    if ($etikett) { $nummer = Format-Avsnitt (ConvertTo-InlineMarkdown -Node $etikett) }

    # Selve noteteksten er alt utenom etiketten.
    $sb = [System.Text.StringBuilder]::new()
    foreach ($child in $Node.ChildNodes) {
        if ($etikett -and $child.Equals($etikett)) { continue }
        if ($child.NodeType -in @([System.Xml.XmlNodeType]::Text,
                [System.Xml.XmlNodeType]::Whitespace,
                [System.Xml.XmlNodeType]::SignificantWhitespace)) {
            [void]$sb.Append($child.Value); continue
        }
        if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
        [void]$sb.Append((ConvertTo-InlineMarkdown -Node $child))
    }

    $tekst = Format-Avsnitt $sb.ToString()
    if (-not $tekst) { return '' }

    $innrykk = ' ' * (4 * $Depth)
    if ($nummer) { "$innrykk*<sup>$nummer</sup> $tekst*" } else { "$innrykk*$tekst*" }
}

#endregion

#region Metadata

function Get-Metadata {
    <#
    .SYNOPSIS
        Leser metadatafeltene (dl.data-document-key-info) fra dokumenthodet.
    .DESCRIPTION
        Nøkkelen hentes fra class-attributtet, ikke fra den synlige etiketten.
        Klassenavnene er språkuavhengige og stabile («dateInForce»), mens
        etikettene varierer med målform («I kraft frå» / «I kraft fra»). Det
        gir frontmatter-nøkler som ikke endrer seg mellom lover.

        Verdiene gjengis som ren tekst – frontmatter skal ikke inneholde
        markdown-formatering.
    .OUTPUTS
        PSCustomObject (Nokkel, Etikett, Verdier) i kildens rekkefølge.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Xml.XmlNode] $Root)

    $dl = $Root.SelectSingleNode('.//dl[contains(@class,"data-document-key-info")]')
    if (-not $dl) { return }

    $nokkel = $null
    $etikett = $null
    foreach ($child in $dl.ChildNodes) {
        if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
        $klasser = @(Get-CssClass -Node $child)

        if ($child.LocalName -eq 'dt') {
            $nokkel = if ($klasser | Where-Object { $_ -in $script:HoppOverMeta }) {
                $null
            } else {
                $klasser | Select-Object -First 1
            }
            $etikett = Format-Avsnitt $child.InnerText
            continue
        }

        if ($child.LocalName -eq 'dd' -and $nokkel) {
            # Lister (departement, rettsområde) blir egne verdier.
            $punkter = @($child.SelectNodes('.//li'))
            $verdier = if ($punkter.Count -gt 0) {
                @($punkter | ForEach-Object { Format-Avsnitt $_.InnerText }) | Where-Object { $_ }
            } else {
                @(Format-Avsnitt $child.InnerText) | Where-Object { $_ }
            }
            if ($verdier) {
                [pscustomobject]@{ Nokkel = $nokkel; Etikett = $etikett; Verdier = @($verdier) }
            }
            $nokkel = $null
        }
    }
}

function ConvertTo-YamlVerdi {
    <#
    .SYNOPSIS
        Skriver en streng som en trygg YAML-skalar i doble anførselstegn.
    .DESCRIPTION
        Lovtitler og noter inneholder klammer, kolon, apostrofer og
        anførselstegn. Doble anførselstegn med escaping er den varianten som
        håndterer alt dette uten spesialtilfeller.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Verdi)

    '"' + ($Verdi -replace '\\', '\\' -replace '"', '\"') + '"'
}

function Get-Frontmatter {
    <#
    .SYNOPSIS
        Bygger YAML-frontmatter for en lov eller forskrift.
    .PARAMETER Root
        Rot-elementet i kildefilen.
    .PARAMETER LovId
        Lovdata-id.
    .PARAMETER Tittel
        Dokumentets tittel.
    .PARAMETER Datasett
        Datasettet dokumentet kommer fra. Bestemmer adressen i «kilde» og
        «kildedatasett». Standard «gjeldende-lover».
    .OUTPUTS
        [string[]] – linjene i frontmatter-blokken, inkludert '---' i begge ender.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Xml.XmlNode] $Root,
        [Parameter(Mandatory)][string] $LovId,
        [Parameter(Mandatory)][string] $Tittel,
        [string] $Datasett = $script:StandardDatasett
    )

    $type = Get-LovdataDokumenttype -Datasett $Datasett

    $linjer = [System.Collections.Generic.List[string]]::new()
    $linjer.Add('---')
    $linjer.Add('lovId: ' + (ConvertTo-YamlVerdi $LovId))
    $linjer.Add('tittel: ' + (ConvertTo-YamlVerdi $Tittel))

    foreach ($felt in Get-Metadata -Root $Root) {
        if ($felt.Verdier.Count -eq 1) {
            $linjer.Add(($felt.Nokkel + ': ' + (ConvertTo-YamlVerdi $felt.Verdier[0])))
        } else {
            $linjer.Add($felt.Nokkel + ':')
            foreach ($v in $felt.Verdier) { $linjer.Add('  - ' + (ConvertTo-YamlVerdi $v)) }
        }
    }

    $linjer.Add('kilde: ' + (ConvertTo-YamlVerdi "https://lovdata.no/dokument/$($type.Dokumentsti)/$LovId"))
    $linjer.Add('kildedatasett: ' + (ConvertTo-YamlVerdi "$script:ApiBase/get/$Datasett.tar.bz2"))
    $linjer.Add('generertAv: ' + (ConvertTo-YamlVerdi 'scripts/Update-Lovtekst.ps1'))
    $linjer.Add('---')
    $linjer
}

#endregion

#region Offentlige funksjoner

function ConvertFrom-LovdataXml {
    <#
    .SYNOPSIS
        Gjør en fil fra et Lovdata-datasett om til deterministisk markdown.
    .PARAMETER Path
        Sti til XML-filen, f.eks. .../nl/nl-19650618-006.xml.
    .PARAMETER LovId
        Lovdata-id, brukes til kildehenvisningen.
    .PARAMETER Datasett
        Datasettet filen kommer fra. Standard «gjeldende-lover».
    .OUTPUTS
        [string] – hele markdown-dokumentet, LF-linjeskift, ett avsluttende linjeskift.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $LovId,
        [string] $Datasett = $script:StandardDatasett
    )

    $rot = ConvertTo-LovdataXml -Path $Path

    $main = $rot.SelectSingleNode('.//main')
    if (-not $main) { throw "Fant ikke lovteksten (<main>) i $Path." }

    $h1 = $main.SelectSingleNode('./h1')
    if (-not $h1) { throw "Fant ikke tittel (<h1>) i $Path." }
    $tittel = Format-Avsnitt (ConvertTo-InlineMarkdown -Node $h1)

    $linjer = [System.Collections.Generic.List[string]]::new()
    foreach ($l in Get-Frontmatter -Root $rot -LovId $LovId -Tittel $tittel -Datasett $Datasett) { $linjer.Add($l) }

    $linjer.Add('')
    $linjer.Add("# $tittel")
    $linjer.Add('')
    $linjer.Add('> Generert fil. Ikke rediger for hånd – kjør `scripts/Update-Lovtekst.ps1`.')
    $linjer.Add('> Se `kilde.psd1` i denne mappa for hentedato og sjekksum. Ved tvil gjelder Lovdata sin offisielle versjon.')

    # H1-en i <main> er samme tittel som allerede står øverst i filen.
    $main.RemoveChild($h1) | Out-Null

    foreach ($blokk in ConvertTo-BlockMarkdown -Node $main) {
        if ([string]::IsNullOrWhiteSpace($blokk)) { continue }
        $linjer.Add('')
        $linjer.Add($blokk)
    }

    ($linjer -join "`n") + "`n"
}

function Get-LovdataMarkdown {
    <#
    .SYNOPSIS
        Henter ett dokument fra et datasett og returnerer markdown + provenans.
    .PARAMETER LovId
        Lovdata-id på formen «1963-06-21-23».
    .PARAMETER Datasett
        Resultatet fra Get-LovdataDatasett. Hentes automatisk hvis utelatt.
    .OUTPUTS
        PSCustomObject med LovId, Fil, Sti, Sha256 og Markdown.
    .EXAMPLE
        Get-LovdataMarkdown -LovId 1965-06-18-6
    .EXAMPLE
        # Gjenbruk datasettet når du henter flere lover
        $d = Get-LovdataDatasett
        '1963-06-21-23','1966-12-09-1' | ForEach-Object { Get-LovdataMarkdown -LovId $_ -Datasett $d }
    .EXAMPLE
        # Byggesaksforskriften ligger i forskriftsdatasettet
        Get-LovdataMarkdown -LovId 2010-03-26-488 -Datasett (Get-LovdataDatasett -Navn gjeldende-sentrale-forskrifter)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string] $LovId,
        [psobject] $Datasett
    )

    if (-not $Datasett) { $Datasett = Get-LovdataDatasett }

    $dokument = Find-LovdataDokument -Datasett $Datasett -LovId $LovId
    if (-not $dokument) {
        $filnavn = ConvertTo-LovdataFilnavn -LovId $LovId -Datasett $Datasett.Navn
        throw "Fant ikke $filnavn i datasettet $($Datasett.Navn). Er $LovId fortsatt gjeldende?"
    }

    [pscustomobject]@{
        LovId    = $LovId
        Fil      = $dokument.Filnavn
        Sti      = $dokument.Sti
        Sha256   = (Get-FileHash -Path $dokument.Sti -Algorithm SHA256).Hash.ToLowerInvariant()
        Markdown = ConvertFrom-LovdataXml -Path $dokument.Sti -LovId $LovId -Datasett $Datasett.Navn
    }
}

#endregion

Export-ModuleMember -Function Get-LovdataDokumenttype, Get-LovdataDatasett,
ConvertTo-LovdataFilnavn, Find-LovdataDokument, ConvertTo-LovdataXml,
ConvertFrom-LovdataXml, Get-LovdataMarkdown
