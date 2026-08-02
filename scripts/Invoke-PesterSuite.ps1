#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Run the Pester suites in this repository and gate the pull request on the result.

.DESCRIPTION
    Discovers every '*.Tests.ps1' file under 'tests', runs them in one Pester
    session, and exits 0 only when every discovered test passed.

    Discovery is from disk rather than a list in this script, so a new suite is
    gated the moment the file lands. That only holds as long as discovering
    nothing is a failure: a run that found no suite, or suites holding no test,
    is green and worthless, and it is the same mistake the check under test made
    when it reported that every one of zero links resolved. Both cases exit 1.

    Pester is pinned to an exact version so a new release cannot turn an
    untouched pull request red. Keep the pin inside the range the suites'
    '#Requires' lines declare.

.EXAMPLE
    ./scripts/Invoke-PesterSuite.ps1
    Runs every suite under 'tests' and exits non-zero if any test fails.

.EXAMPLE
    ./scripts/Invoke-PesterSuite.ps1 -Path ./tests -RequiredVersion 6.0.1
    Runs the suites in an explicit directory with an explicit Pester version.

.LINK
    https://msxorg.github.io/docs/Coding-Standards/Testing/
#>
[CmdletBinding()]
param(
    # Directory holding the Pester suites. Every '*.Tests.ps1' beneath it is run.
    [Parameter()]
    [string] $Path = (Join-Path (Split-Path -Parent $PSScriptRoot) 'tests'),

    # Exact Pester version to run with.
    [Parameter()]
    [string] $RequiredVersion = '6.0.1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$installed = @(Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version.ToString() -eq $RequiredVersion })
if ($installed.Count -eq 0) {
    Write-Output "Pester $RequiredVersion is not installed - installing it for the current user."
    Install-Module -Name Pester -RequiredVersion $RequiredVersion -Repository PSGallery -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module -Name Pester -RequiredVersion $RequiredVersion -Force

$root = (Resolve-Path -LiteralPath $Path).ProviderPath
$suites = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.Tests.ps1' | Sort-Object FullName)
if ($suites.Count -eq 0) {
    Write-Output "No '*.Tests.ps1' file was found under $root - nothing was run."
    Write-Output 'A test run that discovered nothing is a failure, not a pass.'
    exit 1
}
Write-Output "Discovered $($suites.Count) suite(s) under ${root}:"
$suites | ForEach-Object { Write-Output "  - $([System.IO.Path]::GetRelativePath($root, $_.FullName))" }

$configuration = New-PesterConfiguration
$configuration.Run.Path = $suites.FullName
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$configuration.Output.CIFormat = 'GithubActions'
$result = Invoke-Pester -Configuration $configuration

if ($result.TotalCount -eq 0) {
    Write-Output "The $($suites.Count) discovered suite(s) held no test - the run proved nothing."
    exit 1
}
if ($result.Result -eq 'Passed' -and $result.FailedContainersCount -eq 0) {
    Write-Output "$($result.PassedCount) test(s) passed in $($suites.Count) suite(s)."
    exit 0
}
Write-Output "$($result.FailedCount) of $($result.TotalCount) test(s) failed, and $($result.FailedContainersCount) suite(s) failed to run."
exit 1
