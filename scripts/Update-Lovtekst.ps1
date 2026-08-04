#requires -Version 7.0
<#
.SYNOPSIS
    Henter lovtekster og forskrifter fra Lovdata sitt åpne API på nytt,
    kontrollerer dem og regenererer markdown.

.DESCRIPTION
    Kildene i denne repoen kommer i to slag. De fleste er en fil utgiveren har
    lagt ut på nett med en fast sjekksum – de kontrolleres av
    `Update-Source.ps1`. Regelverk fra Lovdata er annerledes: Lovdata har ingen
    enkelt fil å laste ned, bare et åpent API som pakker sammen ALT gjeldende
    regelverk i noen få store datasett, og Lovdata ajourfører dem hver natt. Det
    finnes ingen fast sjekksum å feste seg til hos utgiveren – provenansen er
    «denne lovens XML, slik den sto i datasettet vi hentet på denne datoen»,
    ikke «denne filen, publisert på denne datoen».

    Dette skriptet håndterer den typen kilde. Det virker på hver mappe under
    `docs/` der `kilde.psd1` har `Opphav.Kilde = 'lovdata-api'`, og gjør fire
    ting per kilde:

    1. Henter datasettet kilden hører til (`Opphav.Datasett`) fra Lovdata. Ett
       datasett dekker alt regelverket i sitt slag, så hvert datasett lastes ned
       bare én gang per kjøring – uansett hvor mange kilder som bruker det.
    2. Finner dokumentets XML i datasettet og sammenligner sjekksummen med den
       lokale kopien (`<kortnavn>.xml`). Avvik betyr at Lovdata har ajourført
       teksten siden forrige gang vi hentet den.
    3. Konverterer den lokale XML-kopien til markdown med `Lovdata.psm1`.
    4. Sammenligner resultatet med markdown-filen som ligger i repoet.

    Uten brytere rapporterer skriptet bare hva som er i utakt. Bruk `-Skriv`
    for å oppdatere markdown-filen, og `-GodtaNyVersjon` for å ta inn en ny
    XML-snapshot fra datasettet (oppdaterer den lokale XML-filen, sjekksummen
    og hentet-datoen).

.PARAMETER Navn
    Mappenavnet til kilden under `docs/`. Utelates det, behandles alle
    Lovdata-kilder (`Opphav.Kilde = 'lovdata-api'`).

.PARAMETER Skriv
    Skriv den genererte markdown-filen til repoet.

.PARAMETER GodtaNyVersjon
    Godta at Lovdata har ajourført teksten: ta inn den nye XML-en fra
    datasettet, oppdater sjekksum og hentet-dato i `kilde.psd1`, og regenerer
    markdown.

.PARAMETER Frakoblet
    Hopp over å hente datasettet fra Lovdata. Kontrollerer bare den lokale
    XML-snapshoten mot sjekksummen og regenererer markdown fra den. Dette er
    kontrollen som kjører i CI, slik at en pull request ikke blir rød bare
    fordi Lovdata la ut et nytt datasett i natt.

.EXAMPLE
    ./Update-Lovtekst.ps1
    Kontrollerer alle kildene mot Lovdata og mot innsjekket markdown.

.EXAMPLE
    ./Update-Lovtekst.ps1 veglova -Skriv
    Regenererer markdown for én kilde.

.EXAMPLE
    ./Update-Lovtekst.ps1 -GodtaNyVersjon -Skriv
    Tar inn ferske XML-snapshot fra Lovdata for alle kildene.

.EXAMPLE
    ./Update-Lovtekst.ps1 -Frakoblet
    Kontrollerer uten å nå ut på nett. Dette kjører CI.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Navn,
    [switch]$Skriv,
    [switch]$GodtaNyVersjon,
    [switch]$Frakoblet
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Lovdata.psm1') -Force

$sourcesRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'docs'

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Set-ManifestValue {
    <#
        Erstatter én verdi i kilde.psd1 uten å skrive filen på nytt, slik at
        kommentarer og formatering beholdes. Samme funksjon som i
        Update-Source.ps1.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Value
    )
    $content = Get-Content -LiteralPath $Path -Raw
    $pattern = "(?m)^(\s*$([regex]::Escape($Key))\s*=\s*)'[^']*'"
    if ($content -notmatch $pattern) { throw "Fant ikke '$Key' i $Path." }
    $updated = [regex]::Replace($content, $pattern, "`${1}'$Value'")
    Set-Content -LiteralPath $Path -Value $updated -Encoding utf8NoBOM -NoNewline
}

function Test-LovdataManifest {
    <#
        En docs/*/kilde.psd1 hører til denne kontrollen hvis Opphav.Kilde er
        satt til 'lovdata-api'. Mangler nøkkelen (den statiske kildens
        kilde.psd1), hører den til Update-Source.ps1 i stedet.
    #>
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $manifest = Import-PowerShellDataFile -LiteralPath $Path
    $manifest.Opphav.Kilde -eq 'lovdata-api'
}

function Get-Datasettnavn {
    <#
        Hvilket Lovdata-datasett en kilde hører til. Alle kildene oppgir det i
        `Opphav.Datasett`; lovene er standarden hvis nøkkelen mangler, slik at
        en kilde skrevet før forskriftene kom til fortsatt leses.
    #>
    param([Parameter(Mandatory)][hashtable]$Origin)

    if ($Origin.Contains('Datasett') -and $Origin.Datasett) { $Origin.Datasett } else { 'gjeldende-lover' }
}

function Update-Lovtekst {
    param(
        [Parameter(Mandatory)][System.IO.DirectoryInfo]$Directory,
        [hashtable]$Datasett = @{}
    )

    $name = $Directory.Name
    $manifestPath = Join-Path $Directory.FullName 'kilde.psd1'
    $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
    $origin = $manifest.Opphav
    $originalPath = Join-Path $Directory.FullName $origin.Original
    $markdownPath = Join-Path $Directory.FullName $origin.Markdown
    $datasettNavn = Get-Datasettnavn -Origin $origin

    $result = [ordered]@{
        Kilde    = $name
        Lovdata  = 'ikke sjekket'
        Original = 'mangler'
        Markdown = 'ikke sjekket'
    }

    # 1-2. Dokumentets XML i datasettet kontra sjekksummen vi har registrert.
    if (-not $Frakoblet) {
        $kildedatasett = $Datasett[$datasettNavn]
        $dokument = Find-LovdataDokument -Datasett $kildedatasett -LovId $origin.LovId
        if (-not $dokument) {
            $filnavn = ConvertTo-LovdataFilnavn -LovId $origin.LovId -Datasett $datasettNavn
            throw "$name : fant ikke $filnavn ($($origin.LovId)) i datasettet $datasettNavn. Er teksten fortsatt gjeldende?"
        }

        $datasettHash = Get-Sha256 -Path $dokument.Sti
        if ($datasettHash -eq $origin.Sha256.ToUpperInvariant()) {
            $result.Lovdata = 'uendret'
        } elseif ($GodtaNyVersjon) {
            Copy-Item -LiteralPath $dokument.Sti -Destination $originalPath -Force
            Set-ManifestValue -Path $manifestPath -Key 'Sha256' -Value $datasettHash
            Set-ManifestValue -Path $manifestPath -Key 'DatasettSha256' -Value $kildedatasett.Sha256
            Set-ManifestValue -Path $manifestPath -Key 'Kildefil' -Value $dokument.Filnavn
            Set-ManifestValue -Path $manifestPath -Key 'Hentet' -Value (Get-Date -Format 'yyyy-MM-dd')
            $origin.Sha256 = $datasettHash
            $result.Lovdata = 'ny versjon tatt inn'
        } else {
            $result.Lovdata = 'AJOURFØRT hos Lovdata'
            Write-Warning "$name : Lovdata har ajourført teksten siden forrige gang. Kjør med -GodtaNyVersjon -Skriv for å ta den inn."
        }
    }

    if (-not (Test-Path -LiteralPath $originalPath)) {
        throw "$name : finner ikke den lokale XML-snapshoten $($origin.Original)."
    }
    $localHash = Get-Sha256 -Path $originalPath
    $result.Original = if ($localHash -eq $origin.Sha256.ToUpperInvariant()) {
        'i samsvar'
    } else {
        'AVVIK fra sjekksum'
    }

    # 3. Konverter den lokale XML-snapshoten til markdown.
    $generatedText = ConvertFrom-LovdataXml -Path $originalPath -LovId $origin.LovId -Datasett $datasettNavn

    # 4. Sammenlign med det som ligger i repoet.
    $old = if (Test-Path -LiteralPath $markdownPath) { Get-Content -LiteralPath $markdownPath -Raw } else { $null }
    if ($old -ceq $generatedText) {
        $result.Markdown = 'i samsvar'
    } elseif ($Skriv) {
        [System.IO.File]::WriteAllText($markdownPath, $generatedText, [System.Text.UTF8Encoding]::new($false))
        $result.Markdown = if ($null -eq $old) { 'opprettet' } else { 'oppdatert' }
    } else {
        $result.Markdown = 'AVVIK - kjør med -Skriv'
    }

    [pscustomobject]$result
}

$directories = if ($Navn) {
    @(Get-Item -LiteralPath (Join-Path $sourcesRoot $Navn))
} else {
    Get-ChildItem -LiteralPath $sourcesRoot -Directory | Sort-Object Name
}

$directories = $directories | Where-Object { Test-LovdataManifest -Path (Join-Path $_.FullName 'kilde.psd1') }

if (-not $directories) {
    Write-Host 'Ingen Lovdata-kilder (Opphav.Kilde = lovdata-api) funnet under docs/.' -ForegroundColor Yellow
    return
}

# Ett datasett dekker alt regelverket i sitt slag, og forskriftspakken er stor.
# Derfor hentes hvert datasett kildene faktisk bruker, én gang, uansett hvor
# mange kilder som deler det.
$datasett = @{}
if (-not $Frakoblet) {
    $datasettNavn = $directories |
        ForEach-Object { Get-Datasettnavn -Origin (Import-PowerShellDataFile -LiteralPath (Join-Path $_.FullName 'kilde.psd1')).Opphav } |
        Sort-Object -Unique

    foreach ($n in $datasettNavn) {
        Write-Host "Lovdata: henter datasettet $n..." -ForegroundColor Cyan
        $datasett[$n] = Get-LovdataDatasett -Navn $n
        Write-Host "  $($datasett[$n].AntallDokumenter) dokumenter i datasettet (sha256 $($datasett[$n].Sha256.Substring(0,12))...)" -ForegroundColor DarkGray
    }
}

$results = foreach ($directory in $directories) { Update-Lovtekst -Directory $directory -Datasett $datasett }
$results | Format-Table -AutoSize

if ($results | Where-Object { $_.Original -like 'AVVIK*' -or $_.Markdown -like 'AVVIK*' }) {
    throw 'Én eller flere Lovdata-kilder er ute av takt. Se tabellen over.'
}
