#requires -Version 7.0
<#
.SYNOPSIS
    Henter en ekstern kilde på nytt, kontrollerer den og regenererer markdown.

.DESCRIPTION
    Hver kilde under `sources/` er beskrevet i en `kilde.psd1` med hvor
    originalen ligger på nett, hvilken sjekksum den skal ha, og hvilke regler
    som gjelder for konvertering til markdown.

    Skriptet gjør fire ting:

    1. Laster ned originalen fra `Opphav.Url`.
    2. Sammenligner SHA256 med `Opphav.Sha256`. Avvik betyr at utgiveren har
       publisert en ny versjon.
    3. Konverterer den lokale originalen til markdown med
       `Convert-PdfToMarkdown.py`, og kontrollerer at alle ordene i PDF-en
       finnes igjen i markdown-filen.
    4. Sammenligner resultatet med markdown-filen som ligger i repoet.

    Uten brytere rapporterer skriptet bare hva som er i utakt. Bruk `-Skriv`
    for å oppdatere markdown-filen, og `-GodtaNyVersjon` for å ta inn en ny
    utgave fra nett (oppdaterer original, sjekksum og hentet-dato).

.PARAMETER Navn
    Mappenavnet under `sources/`. Utelates den, behandles alle kilder.

.PARAMETER Skriv
    Skriv den genererte markdown-filen til repoet.

.PARAMETER GodtaNyVersjon
    Godta at originalen på nett er endret: last ned den nye filen, oppdater
    sjekksum og hentet-dato i `kilde.psd1`, og regenerer markdown.

.PARAMETER Frakoblet
    Hopp over nedlasting. Kontrollerer bare den lokale originalen mot
    sjekksummen og regenererer markdown.

.EXAMPLE
    ./Update-Source.ps1
    Kontrollerer alle kilder mot nett og mot innsjekket markdown.

.EXAMPLE
    ./Update-Source.ps1 veileder-bruksordning-for-veg -Skriv
    Regenererer markdown for én kilde.

.EXAMPLE
    ./Update-Source.ps1 -GodtaNyVersjon -Skriv
    Tar inn nye utgaver fra nett for alle kilder.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Navn,
    [switch]$Skriv,
    [switch]$GodtaNyVersjon,
    [switch]$Frakoblet
)

$ErrorActionPreference = 'Stop'

$sourcesRoot = Split-Path $PSScriptRoot -Parent
$converter = Join-Path $PSScriptRoot 'Convert-PdfToMarkdown.py'

function Get-Python {
    foreach ($candidate in 'python', 'python3', 'py') {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    throw 'Fant ikke Python på PATH. Installer Python 3.9 eller nyere.'
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Set-ManifestValue {
    <#
        Erstatter én verdi i kilde.psd1 uten å skrive filen på nytt, slik at
        kommentarer og formatering beholdes.
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

function Update-Source {
    param([Parameter(Mandatory)][System.IO.DirectoryInfo]$Directory)

    $name = $Directory.Name
    $manifestPath = Join-Path $Directory.FullName 'kilde.psd1'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Write-Verbose "Hopper over $name (ingen kilde.psd1)."
        return
    }

    $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
    $origin = $manifest.Opphav
    $originalPath = Join-Path $Directory.FullName $origin.Original
    $markdownPath = Join-Path $Directory.FullName $origin.Markdown

    $result = [ordered]@{
        Kilde    = $name
        Nett     = 'ikke sjekket'
        Original = 'mangler'
        Markdown = 'ikke sjekket'
        Dekning  = ''
    }

    # 1-2. Originalen på nett kontra sjekksummen vi har registrert.
    if (-not $Frakoblet) {
        $downloaded = Join-Path ([System.IO.Path]::GetTempPath()) "kilde_$([guid]::NewGuid()).tmp"
        try {
            $previous = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $origin.Url -OutFile $downloaded -UseBasicParsing
            $ProgressPreference = $previous

            $onlineHash = Get-Sha256 -Path $downloaded
            if ($onlineHash -eq $origin.Sha256.ToUpperInvariant()) {
                $result.Nett = 'uendret'
            } elseif ($GodtaNyVersjon) {
                Copy-Item -LiteralPath $downloaded -Destination $originalPath -Force
                Set-ManifestValue -Path $manifestPath -Key 'Sha256' -Value $onlineHash
                Set-ManifestValue -Path $manifestPath -Key 'Hentet' -Value (Get-Date -Format 'yyyy-MM-dd')
                Set-ManifestValue -Path $manifestPath -Key 'Bytes' -Value ((Get-Item -LiteralPath $originalPath).Length)
                $origin.Sha256 = $onlineHash
                $result.Nett = 'ny versjon tatt inn'
            } else {
                $result.Nett = 'ENDRET på nett'
                Write-Warning "$name : originalen på nett er endret. Kjør med -GodtaNyVersjon -Skriv for å ta den inn."
            }
        } finally {
            Remove-Item -LiteralPath $downloaded -ErrorAction SilentlyContinue
        }
    }

    if (-not (Test-Path -LiteralPath $originalPath)) {
        throw "$name : finner ikke den lokale kopien $($origin.Original)."
    }
    $localHash = Get-Sha256 -Path $originalPath
    $result.Original = if ($localHash -eq $origin.Sha256.ToUpperInvariant()) {
        'i samsvar'
    } else {
        'AVVIK fra sjekksum'
    }

    # 3. Konverter til markdown i en midlertidig fil.
    $profilePath = Join-Path ([System.IO.Path]::GetTempPath()) "profil_$([guid]::NewGuid()).json"
    $headerPath = Join-Path ([System.IO.Path]::GetTempPath()) "topptekst_$([guid]::NewGuid()).md"
    $generated = Join-Path ([System.IO.Path]::GetTempPath()) "kilde_$([guid]::NewGuid()).md"
    try {
        $manifest.Profil | ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath $profilePath -Encoding utf8NoBOM

        # Topptekst genereres fra manifestet, slik at kildehenvisningen i
        # markdown-filen aldri kan komme i utakt med opphavet.
        $header = @(
            "# $($origin.Tittel)"
            ''
            "> Maskingenerert markdown-gjengivelse av [$($origin.Original)]($($origin.Original))."
            "> Originalen er utgitt av $($origin.Utgiver) og hentet fra"
            "> <$($origin.Url)>."
            "> Ikke rediger denne filen for hånd – kjør ``sources/scripts/Update-Source.ps1`` i stedet."
            "> Se [README.md](README.md) for opphav og sjekksum."
            ''
        )
        Set-Content -LiteralPath $headerPath -Value ($header -join "`n") -Encoding utf8NoBOM

        $python = Get-Python
        $minimum = if ($null -ne $manifest.MinsteDekning) { $manifest.MinsteDekning } else { 0.0 }
        $output = & $python $converter $originalPath $generated `
            --profile $profilePath --header $headerPath --min-coverage $minimum 2>&1
        $output | Write-Verbose
        if ($LASTEXITCODE -ne 0) {
            $output | Write-Host
            throw "$name : konverteringen feilet."
        }
        $result.Dekning = (($output | Select-String 'Tekstdekning' | Select-Object -Last 1) -split ': ')[-1]

        # 4. Sammenlign med det som ligger i repoet.
        $new = Get-Content -LiteralPath $generated -Raw
        $old = if (Test-Path -LiteralPath $markdownPath) { Get-Content -LiteralPath $markdownPath -Raw } else { $null }
        if ($old -eq $new) {
            $result.Markdown = 'i samsvar'
        } elseif ($Skriv) {
            Set-Content -LiteralPath $markdownPath -Value $new -Encoding utf8NoBOM -NoNewline
            $result.Markdown = if ($null -eq $old) { 'opprettet' } else { 'oppdatert' }
        } else {
            $result.Markdown = 'AVVIK - kjør med -Skriv'
        }
    } finally {
        Remove-Item -LiteralPath $profilePath, $headerPath, $generated -ErrorAction SilentlyContinue
    }

    [pscustomobject]$result
}

$directories = if ($Navn) {
    @(Get-Item -LiteralPath (Join-Path $sourcesRoot $Navn))
} else {
    Get-ChildItem -LiteralPath $sourcesRoot -Directory |
        Where-Object { $_.Name -ne 'scripts' } |
        Sort-Object Name
}

$results = foreach ($directory in $directories) { Update-Source -Directory $directory }
$results | Format-Table -AutoSize

if ($results | Where-Object { $_.Original -like 'AVVIK*' -or $_.Markdown -like 'AVVIK*' }) {
    throw 'Én eller flere kilder er ute av takt. Se tabellen over.'
}
