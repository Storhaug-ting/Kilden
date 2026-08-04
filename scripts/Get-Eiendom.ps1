#Requires -Version 7.0
<#
.SYNOPSIS
    Slår opp eiendom (matrikkel) og peker til grunnbok/eier via Kartverkets åpne Geonorge-API-er.

.DESCRIPTION
    Get-Eiendom bruker Kartverkets åpne REST-API-er på Geonorge (ingen innlogging kreves):
      Kommuneinfo : https://ws.geonorge.no/kommuneinfo/v1
      Eiendom     : https://ws.geonorge.no/eiendom/v1     (geokoding/lokalisering av matrikkelenheter)
      Adresser    : https://ws.geonorge.no/adresser/v1

    Kommandoen driller nedover i matrikkelhierarkiet ut fra hvor mange nummer du oppgir:
      (ingen)          -> lister alle kommuner
      Knr              -> lister alle gårdsnummer (Gnr) i kommunen
      Knr Gnr          -> lister alle bruksnummer (Bnr) under gården
      Knr Gnr Bnr      -> henter eiendommen (matrikkelenhet), adresser og seksjoner (om de finnes)
      Knr Gnr Bnr Snr  -> henter den enkelte seksjonen

    VIKTIG om grunnbok og eier (hjemmelshaver):
      Grunnboken deles IKKE som åpne data på Geonorge, og eier/hjemmelshaver er ikke tilgjengelig
      via de åpne API-ene (regulert av utleveringsforskriften). Kommandoen returnerer derfor en
      direkte lenke (GrunnbokUrl) til Kartverkets Eiendomsregister der grunnbok og eier kan slås
      opp, i tillegg til all åpen matrikkelinformasjon. Se .NOTES for programmatisk tilgang.

.PARAMETER Knr
    Kommunenummer (4 siffer, f.eks. 0301 for Oslo). Godtar både "0301" og 301 (nulles ut til 4 siffer).

.PARAMETER Gnr
    Gårdsnummer.

.PARAMETER Bnr
    Bruksnummer.

.PARAMETER Snr
    Seksjonsnummer.

.PARAMETER Adresse
    Fritekst-adresse (f.eks. "Helge Ingstads vei 52, 1820 Spydeberg"). Oversettes til matrikkel
    (Address -> Matrikkel). For seksjonerte eiendommer finnes eksakt seksjonsnummer via Kartverkets
    Eiendomsregister, slik at en leilighet/seksjonsadresse gir riktig seksjon. Flere treff (f.eks.
    et leilighetsbygg) returnerer en kandidatliste. Kan ikke kombineres med Knr/Gnr/Bnr/Snr.

.PARAMETER Fnr
    Festenummer (valgfritt, 0 = ingen feste).

.PARAMETER Omrade
    Ta med teig-/områdegeometri (polygon) i tillegg til representasjonspunkt.

.PARAMETER Koordsys
    SRID for koordinater i svaret. Standard 4258 (~WGS84/GPS).

.PARAMETER Raw
    Returner rå API-objekter i stedet for tilpassede objekter.

.EXAMPLE
    Get-Eiendom
    Lister alle kommuner.

.EXAMPLE
    Get-Eiendom 0301
    Lister alle gårdsnummer i Oslo.

.EXAMPLE
    Get-Eiendom 0301 223
    Lister alle bruksnummer under gnr 223 i Oslo.

.EXAMPLE
    Get-Eiendom 0301 223 60
    Henter eiendommen 0301-223/60 med adresser, seksjoner og lenke til grunnbok/eier.

.EXAMPLE
    Get-Eiendom 3413 6 501 2
    Henter seksjon 2 på 3413-6/501.

.EXAMPLE
    Get-Eiendom -Adresse 'Helge Ingstads vei 52, 1820 Spydeberg'
    Slår opp adressen, finner eksakt seksjon (3118-411/93/0/7) og henter den.

.EXAMPLE
    Get-Eiendom -Knr 0301 | Where-Object Gnr -in 1..10
    Filtrerer i pipeline (alle grener returnerer objekter).

.NOTES
    Programmatisk tilgang til grunnbok/eier krever avtale med Kartverket og autentisering via
    Maskinporten (Grunnbok-API / Matrikkel-API), jf. utleveringsforskriften. De åpne
    Geonorge-API-ene inneholder ikke disse opplysningene.

    Seksjoner som listes under en eiendom (uten -Adresse) er kun de med eget uteareal (egen teig);
    komplett seksjonsliste krever Matrikkel-API (autentisert).

    -Adresse bruker i tillegg det interne, uautentiserte API-et bak Kartverkets Eiendomsregister
    (soekEtterEiendom + adresserForMatrikkelenhet) for å finne eksakt seksjon. Dette er udokumentert
    og kan endres uten forvarsel; ved feil faller kommandoen tilbake til det åpne adresse-API-et
    (gnr/bnr uten seksjon).

.LINK
    https://ws.geonorge.no/eiendom/v1/
.LINK
    https://www.kartverket.no/api-og-data/eiendomsdata
#>
function Get-Eiendom {
    [CmdletBinding(DefaultParameterSetName = 'Matrikkel')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0, ParameterSetName = 'Matrikkel')]
        [Alias('Kommune', 'Kommunenummer')]
        [string]$Knr,

        [Parameter(Position = 1, ParameterSetName = 'Matrikkel')]
        [Alias('Gardsnummer', 'Gaardsnummer')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Gnr,

        [Parameter(Position = 2, ParameterSetName = 'Matrikkel')]
        [Alias('Bruksnummer')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Bnr,

        [Parameter(Position = 3, ParameterSetName = 'Matrikkel')]
        [Alias('Seksjonsnummer')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Snr,

        [Parameter(Mandatory, ParameterSetName = 'Adresse')]
        [Alias('Address')]
        [string]$Adresse,

        [Alias('Festenummer')]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$Fnr = 0,

        [switch]$Omrade,

        [int]$Koordsys = 4258,

        [switch]$Raw
    )

    # --- Endepunkter (via Geonorge; kan byttes til https://api.kartverket.no som er anbefalt nyere host) ---
    $KommuneInfoBase = 'https://ws.geonorge.no/kommuneinfo/v1'
    $EiendomBase = 'https://ws.geonorge.no/eiendom/v1'
    $AdresseBase = 'https://ws.geonorge.no/adresser/v1'
    $EiendomsregisterBase = 'https://eiendomsregisteret.kartverket.no/eiendom'
    # Internt (uautentisert) API bak Kartverkets Eiendomsregister-portal. Udokumentert og kan endres,
    # men er den eneste åpne kilden som kobler adresse -> eksakt matrikkelenhet inkl. seksjonsnummer.
    $EiendomsregisterApi = 'https://eiendomsregisteret.kartverket.no/api'

    $GrunnbokNote = 'Grunnbok/eier (hjemmelshaver) er ikke åpne data - se GrunnbokUrl i Kartverkets Eiendomsregister.'

    # ---------------------------------------------------------------- hjelpere
    function Invoke-GeonorgeApi {
        param([Parameter(Mandatory)][string]$Uri)
        try {
            Invoke-RestMethod -Uri $Uri -Headers @{ Accept = 'application/json' } -ErrorAction Stop
        } catch {
            $status = $null
            try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = $null }
            $detail = $_.ErrorDetails.Message
            $msg = if ($detail) { $detail } else { $_.Exception.Message }
            throw "Geonorge-kall feilet ($status): $Uri`n$msg"
        }
    }

    function Get-KommuneNavn {
        param([Parameter(Mandatory)][string]$K)
        try {
            $info = Invoke-GeonorgeApi "$KommuneInfoBase/kommuner/$K"
            if ($info.kommunenavnNorsk) { $info.kommunenavnNorsk } else { $info.kommunenavn }
        } catch { $null }
    }

    # Paginerer adresse-API-et (maks 1000/side, totalt maks 10 000 treff fra API-et).
    function Get-AdressePaged {
        param([Parameter(Mandatory)][string]$Query, [string]$Filtrer)
        $all = [System.Collections.Generic.List[object]]::new()
        $side = 0; $total = 0; $truncated = $false
        $maxPages = 12
        while ($true) {
            $uri = "$AdresseBase/sok?$Query&treffPerSide=1000&side=$side&asciiKompatibel=false"
            if ($Filtrer) { $uri += "&filtrer=$Filtrer" }
            $resp = Invoke-GeonorgeApi $uri
            $batch = @($resp.adresser)
            if ($batch.Count -gt 0) { $all.AddRange([object[]]$batch) }
            $total = [int]$resp.metadata.totaltAntallTreff
            $viserTil = [int]$resp.metadata.viserTil
            $side++
            if ($viserTil -ge $total -or $batch.Count -eq 0) { break }
            if ($side -ge $maxPages) { $truncated = $true; break }
        }
        [pscustomobject]@{ Adresser = $all; Total = $total; Truncated = $truncated }
    }

    function Get-Geokoding {
        param([int]$G, [int]$B, [int]$F, [Nullable[int]]$S)
        $q = "kommunenummer=$Knr&gardsnummer=$G&bruksnummer=$B"
        if ($F -gt 0) { $q += "&festenummer=$F" }
        if ($null -ne $S) { $q += "&seksjonsnummer=$S" }
        $q += "&utkoordsys=$Koordsys"
        if ($Omrade) { $q += '&omrade=true' }
        Invoke-GeonorgeApi "$EiendomBase/geokoding?$q"
    }

    function Get-Representasjonspunkt {
        param($Features)
        $pf = @($Features) | Where-Object { $_.geometry.type -eq 'Point' } | Select-Object -First 1
        if ($pf) {
            $c = $pf.geometry.coordinates
            [pscustomobject]@{ Lon = $c[0]; Lat = $c[1]; Koordsys = $Koordsys }
        }
    }

    # Slår opp fritekst-adresse mot adresse-API-et (Address -> Matrikkel, gnr/bnr - ikke seksjon).
    function Resolve-Adresse {
        param([Parameter(Mandatory)][string]$Tekst)
        $clean = (($Tekst -replace ',', ' ') -replace '\s+', ' ').Trim()
        $enc = [uri]::EscapeDataString($clean)
        $resp = Invoke-GeonorgeApi "$AdresseBase/sok?sok=$enc&treffPerSide=100&utkoordsys=$Koordsys"
        @($resp.adresser)
    }

    # Tolker matrikkelenhet-ident fra Eiendomsregisteret. Feltet kan være enten en streng
    # "knr-gnr/bnr/fnr/snr" ELLER et objekt {kommunenummer,gaardsnummer,bruksnummer,festenummer,seksjonsnummer}.
    function ConvertFrom-MatrikkelIdent {
        param($Ident)
        if ($Ident -is [string]) {
            if ($Ident -match '^(\d+)-(\d+)/(\d+)/(\d+)/(\d+)$') {
                return [pscustomobject]@{ Knr = $Matches[1]; Gnr = [int]$Matches[2]; Bnr = [int]$Matches[3]; Fnr = [int]$Matches[4]; Snr = [int]$Matches[5] }
            }
            return $null
        }
        if ($null -ne $Ident.gaardsnummer) {
            return [pscustomobject]@{
                Knr = [string]$Ident.kommunenummer; Gnr = [int]$Ident.gaardsnummer; Bnr = [int]$Ident.bruksnummer
                Fnr = [int]$Ident.festenummer; Snr = [int]$Ident.seksjonsnummer
            }
        }
        return $null
    }

    # Normaliserer svar fra adresserForMatrikkelenhet. Én backend gir en array av objekter; en
    # annen gir kolonneform (ett objekt med parallelle arrays adresse[]/matrikkelenhetIdent[]).
    function Get-AdresseListe {
        param($Raw)
        $items = @($Raw)
        if ($items.Count -eq 1 -and $items[0].adresse -is [System.Array]) {
            $obj = $items[0]
            $adr = @($obj.adresse)
            $idn = @($obj.matrikkelenhetIdent)
            for ($k = 0; $k -lt $adr.Count; $k++) {
                $identVal = if ($k -lt $idn.Count) { $idn[$k] } else { $null }
                [pscustomobject]@{ adresse = $adr[$k]; matrikkelenhetIdent = $identVal }
            }
            return
        }
        $items
    }

    # Slår opp adresse i Eiendomsregisteret og finner EKSAKT matrikkelenhet inkl. seksjonsnummer.
    # (Adresse-API-et gir bare gnr/bnr; seksjonen ligger kun i matrikkelen bak denne portalen.)
    function Resolve-AdressePortal {
        param([Parameter(Mandatory)][string]$Tekst)
        $search = ($Tekst -replace '\s+', ' ').Trim()
        # matchestreng: uten postnr/poststed og uten komma
        $qNorm = ((($search -replace '(?i),?\s*\d{4}\s+.*$', '') -replace ',', ' ') -replace '\s+', ' ').Trim().ToUpperInvariant()

        # Portal-søket er følsomt for format; prøv som oppgitt, så med komma foran postnr.
        $enheter = @()
        foreach ($variant in (@($search, ($search -replace '(?i)\s+(\d{4}\s)', ', $1')) | Select-Object -Unique)) {
            $sok = Invoke-GeonorgeApi "$EiendomsregisterApi/soekEtterEiendom?searchstring=$([uri]::EscapeDataString($variant))"
            $enheter = @($sok.matrikkelenheter)
            if ($enheter) { break }
        }
        if (-not $enheter) { return @() }

        $res = [System.Collections.Generic.List[object]]::new()

        foreach ($m in $enheter) {
            if ([int]$m.seksjonsnummer -gt 0) {
                $res.Add([pscustomobject]@{
                        Knr = [string]$m.kommunenummer; Gnr = [int]$m.gaardsnummer; Bnr = [int]$m.bruksnummer
                        Fnr = [int]$m.festenummer; Snr = [int]$m.seksjonsnummer
                        Adresse = $m.veiadresse; BoligType = $m.boligType
                    })
                continue
            }
            # snr 0: grunneiendom eller sameie/borettslag -> match eksakt adresse for å finne seksjon
            $matchet = $false
            try {
                $adrListe = Get-AdresseListe (Invoke-GeonorgeApi "$EiendomsregisterApi/adresserForMatrikkelenhet/$($m.id)")
                foreach ($x in $adrListe) {
                    $stripped = ($x.adresse -replace '-[A-Za-z]\d{4}$', '').Trim().ToUpperInvariant()
                    $full = (($x.adresse -replace '-', ' ') -replace '\s+', ' ').Trim().ToUpperInvariant()
                    if ($qNorm -ne $stripped -and $qNorm -ne $full) { continue }
                    $mk = ConvertFrom-MatrikkelIdent $x.matrikkelenhetIdent
                    if ($mk) {
                        $res.Add([pscustomobject]@{
                                Knr = $mk.Knr; Gnr = $mk.Gnr; Bnr = $mk.Bnr; Fnr = $mk.Fnr; Snr = $mk.Snr
                                Adresse = $x.adresse; BoligType = $m.boligType
                            })
                        $matchet = $true
                    }
                }
            } catch { Write-Verbose "Adresseoppslag for matrikkelenhet $($m.id) feilet." }
            if (-not $matchet) {
                $res.Add([pscustomobject]@{
                        Knr = [string]$m.kommunenummer; Gnr = [int]$m.gaardsnummer; Bnr = [int]$m.bruksnummer
                        Fnr = [int]$m.festenummer; Snr = [int]$m.seksjonsnummer
                        Adresse = $m.veiadresse; BoligType = $m.boligType
                    })
            }
        }
        $res | Sort-Object Knr, Gnr, Bnr, Fnr, Snr -Unique
    }

    # ---------------------------------------------------------------- adresse -> matrikkel (om oppgitt)
    $oppgittAdresse = $null
    if ($PSCmdlet.ParameterSetName -eq 'Adresse') {
        Write-Verbose "Slår opp adresse '$Adresse' ..."
        $kandidater = @()
        try { $kandidater = @(Resolve-AdressePortal $Adresse) }
        catch { Write-Verbose "Eiendomsregister-oppslag feilet: $($_.Exception.Message)" }

        if (-not $kandidater) {
            Write-Verbose 'Faller tilbake til adresse-API-et (gir gnr/bnr, ikke seksjon).'
            $treff = Resolve-Adresse $Adresse
            if (-not $treff) { throw "Fant ingen adresse som matcher '$Adresse'." }
            $kandidater = @($treff | ForEach-Object {
                    [pscustomobject]@{
                        Knr = [string]$_.kommunenummer; Gnr = [int]$_.gardsnummer; Bnr = [int]$_.bruksnummer
                        Fnr = [int]$_.festenummer; Snr = 0
                        Adresse = "$($_.adressetekst), $($_.postnummer) $($_.poststed)"; BoligType = $null
                    }
                })
        }

        if ($kandidater.Count -gt 1) {
            Write-Warning "Adressen '$Adresse' treffer $($kandidater.Count) matrikkelenheter (f.eks. leiligheter). Presiser med bruksenhet (H0101) eller matrikkelnummer. Kandidater:"
            return $kandidater | ForEach-Object {
                [pscustomobject]@{
                    Adresse = $_.Adresse
                    Matrikkel = "$($_.Knr)-$($_.Gnr)/$($_.Bnr)" + $(if ($_.Fnr -gt 0 -or $_.Snr -gt 0) { "/$($_.Fnr)/$($_.Snr)" })
                    Knr = $_.Knr; Gnr = $_.Gnr; Bnr = $_.Bnr; Fnr = $_.Fnr; Snr = $_.Snr; BoligType = $_.BoligType
                }
            }
        }

        $a = $kandidater[0]
        $Knr = [string]$a.Knr; $Gnr = [int]$a.Gnr; $Bnr = [int]$a.Bnr; $Fnr = [int]$a.Fnr
        $oppgittAdresse = $a.Adresse
        $hasKnr = $true; $hasGnr = $true; $hasBnr = $true
        if ([int]$a.Snr -gt 0) { $Snr = [int]$a.Snr; $hasSnr = $true } else { $hasSnr = $false }
        Write-Verbose "Adresse '$($a.Adresse)' -> matrikkel $Knr-$Gnr/$Bnr$(if ($hasSnr) { "/$Fnr/$Snr" })"
    } else {
        $hasKnr = -not [string]::IsNullOrWhiteSpace($Knr)
        $hasGnr = $PSBoundParameters.ContainsKey('Gnr')
        $hasBnr = $PSBoundParameters.ContainsKey('Bnr')
        $hasSnr = $PSBoundParameters.ContainsKey('Snr')
    }

    # ---------------------------------------------------------------- hierarki-validering
    if ($hasSnr -and -not $hasBnr) { throw 'Snr krever at Bnr også oppgis.' }
    if ($hasBnr -and -not $hasGnr) { throw 'Bnr krever at Gnr også oppgis.' }
    if ($hasGnr -and -not $hasKnr) { throw 'Gnr krever at Knr også oppgis.' }

    if ($hasKnr) {
        $Knr = $Knr.Trim()
        if ($Knr -notmatch '^\d{1,4}$') { throw "Ugyldig kommunenummer '$Knr'. Forventer 1-4 siffer." }
        $Knr = $Knr.PadLeft(4, '0')
    }

    # ---------------------------------------------------------------- 1) ingen input -> kommuner
    if (-not $hasKnr) {
        Write-Verbose 'Henter alle kommuner ...'
        $kommuner = Invoke-GeonorgeApi "$KommuneInfoBase/kommuner"
        if ($Raw) { return $kommuner }
        return $kommuner | Sort-Object kommunenummer | ForEach-Object {
            [pscustomobject]@{
                Knr     = $_.kommunenummer
                Kommune = if ($_.kommunenavnNorsk) { $_.kommunenavnNorsk } else { $_.kommunenavn }
            }
        }
    }

    $kommuneNavn = Get-KommuneNavn $Knr
    if (-not $kommuneNavn) { throw "Fant ikke kommune $Knr." }

    # ---------------------------------------------------------------- 2) Knr -> gårdsnummer
    if (-not $hasGnr) {
        Write-Verbose "Henter gårdsnummer i $Knr $kommuneNavn (utledes fra adresser) ..."
        $paged = Get-AdressePaged -Query "kommunenummer=$Knr" -Filtrer 'metadata,adresser.gardsnummer'
        if ($paged.Truncated) {
            Write-Warning 'Kommunen har svært mange adresser; lista kan være ufullstendig (adresse-API-et returnerer maks 10 000 treff).'
        }
        $gnrs = $paged.Adresser.gardsnummer | Where-Object { $null -ne $_ } | Sort-Object -Unique
        if ($Raw) { return $gnrs }
        return $gnrs | ForEach-Object {
            [pscustomobject]@{ Knr = $Knr; Kommune = $kommuneNavn; Gnr = [int]$_ }
        }
    }

    # ---------------------------------------------------------------- 3) Knr+Gnr -> bruksnummer
    if (-not $hasBnr) {
        Write-Verbose "Henter bruksnummer under $Knr-$Gnr ..."
        $paged = Get-AdressePaged -Query "kommunenummer=$Knr&gardsnummer=$Gnr" -Filtrer 'metadata,adresser.bruksnummer'
        if ($paged.Truncated) { Write-Warning 'Mange treff; lista kan være ufullstendig.' }
        $bnrs = $paged.Adresser.bruksnummer | Where-Object { $null -ne $_ } | Sort-Object -Unique
        if (-not $bnrs) {
            Write-Warning "Fant ingen bruksnummer med registrert adresse under $Knr-$Gnr. Eiendommer uten adresse listes ikke her."
        }
        if ($Raw) { return $bnrs }
        return $bnrs | ForEach-Object {
            [pscustomobject]@{ Knr = $Knr; Kommune = $kommuneNavn; Gnr = $Gnr; Bnr = [int]$_ }
        }
    }

    # ---------------------------------------------------------------- 4) Knr+Gnr+Bnr -> eiendom + seksjoner
    if (-not $hasSnr) {
        Write-Verbose "Henter eiendom $Knr-$Gnr/$Bnr ..."
        $geo = Get-Geokoding -G $Gnr -B $Bnr -F $Fnr -S $null
        if (-not $geo.features) { throw "Fant ingen matrikkelenhet $Knr-$Gnr/$Bnr$(if ($Fnr) { "/$Fnr" })." }
        if ($Raw) { return $geo }

        $props = $geo.features.properties
        $matrikkel = ($props.matrikkelnummertekst | Where-Object { $_ } | Sort-Object -Unique) -join ', '
        $seksjoner = $props.seksjonsnummer | Where-Object { $_ -gt 0 } | Sort-Object -Unique

        $adresser = @()
        try {
            $ap = Get-AdressePaged -Query "kommunenummer=$Knr&gardsnummer=$Gnr&bruksnummer=$Bnr" -Filtrer 'metadata,adresser.adressetekst'
            $adresser = $ap.Adresser.adressetekst | Where-Object { $_ } | Sort-Object -Unique
        } catch { Write-Verbose "Adresseoppslag feilet: $($_.Exception.Message)" }

        $fnrPart = if ($Fnr -gt 0) { $Fnr } else { 0 }

        return [pscustomobject]@{
            Matrikkel      = "$Knr-$Gnr/$Bnr" + $(if ($Fnr -gt 0) { "/$Fnr" })
            OppgittAdresse = $oppgittAdresse
            Knr            = $Knr
            Kommune        = $kommuneNavn
            Gnr            = $Gnr
            Bnr            = $Bnr
            Fnr            = $Fnr
            Matrikkeltekst = $matrikkel
            Adresser       = @($adresser)
            Seksjoner      = @($seksjoner)
            AntallTeiger   = @($geo.features).Count
            Punkt          = Get-Representasjonspunkt $geo.features
            Oppdatert      = ($props.oppdateringsdato | Where-Object { $_ } | Sort-Object -Unique | Select-Object -Last 1)
            Hjemmelshaver  = $null
            Grunnbok       = $null
            GrunnbokUrl    = "$EiendomsregisterBase/$Knr/$Gnr/$Bnr/$fnrPart/0"
            Omrade         = if ($Omrade) { $geo.features.geometry } else { $null }
            Merknad        = "$GrunnbokNote Seksjoner viser kun de med eget uteareal; komplett liste krever Matrikkel-API."
        }
    }

    # ---------------------------------------------------------------- 5) Knr+Gnr+Bnr+Snr -> seksjon/grunnbok
    Write-Verbose "Henter seksjon $Knr-$Gnr/$Bnr/$Snr ..."
    $geo = Get-Geokoding -G $Gnr -B $Bnr -F $Fnr -S $Snr
    if (-not $geo.features) { throw "Fant ingen seksjon $Snr på $Knr-$Gnr/$Bnr." }
    if ($Raw) { return $geo }

    $props = $geo.features.properties
    $fnrPart = if ($Fnr -gt 0) { $Fnr } else { 0 }

    return [pscustomobject]@{
        Matrikkel      = "$Knr-$Gnr/$Bnr/$fnrPart/$Snr"
        OppgittAdresse = $oppgittAdresse
        Knr            = $Knr
        Kommune        = $kommuneNavn
        Gnr            = $Gnr
        Bnr            = $Bnr
        Fnr            = $Fnr
        Snr            = $Snr
        Matrikkeltekst = ($props.matrikkelnummertekst | Where-Object { $_ } | Sort-Object -Unique) -join ', '
        Punkt          = Get-Representasjonspunkt $geo.features
        Oppdatert      = ($props.oppdateringsdato | Where-Object { $_ } | Sort-Object -Unique | Select-Object -Last 1)
        Hjemmelshaver  = $null
        Grunnbok       = $null
        GrunnbokUrl    = "$EiendomsregisterBase/$Knr/$Gnr/$Bnr/$fnrPart/$Snr"
        Omrade         = if ($Omrade) { $geo.features.geometry } else { $null }
        Merknad        = $GrunnbokNote
    }
}

Set-Alias -Name Get-Grunnbok -Value Get-Eiendom

# Kjør funksjonen direkte når scriptet startes som fil (ikke ved dot-sourcing).
if ($MyInvocation.InvocationName -ne '.') {
    Get-Eiendom @args
}
