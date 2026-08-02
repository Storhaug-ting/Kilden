#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Fail unless a test run reported that it executed at least one test.

.DESCRIPTION
    A test job is only worth having when it can tell 'I verified this' apart
    from 'there was nothing to verify'. Pester reports a suite that holds no
    test as a pass - 'Result' is 'Passed', 'Executed' is true, and the total is
    zero - so a suite emptied by accident is green having proved nothing.

    This reads the count a run reported and exits 0 only when it is a positive
    whole number.

    A missing count fails too, and that case is the point of the script rather
    than an afterthought. In the workflow the count arrives from the
    'TotalCount' output of the pinned 'PSModule/Invoke-Pester' action. If a
    later version renames or drops that output, the value arrives here as an
    empty string - and a check that read empty as 'not zero, carry on' would
    quietly stop measuring anything, which is the exact failure it exists to
    catch.

.EXAMPLE
    ./scripts/Assert-TestCount.ps1 -TotalCount 13
    Reports that 13 tests were executed and exits 0.

.EXAMPLE
    ./scripts/Assert-TestCount.ps1 -TotalCount 0
    Exits 1, because a run that executed no test proved nothing.

.EXAMPLE
    ./scripts/Assert-TestCount.ps1 -TotalCount ''
    Exits 1, because no count was reported at all.
#>
[CmdletBinding()]
param(
    # The number of tests the run reported executing, as the workflow received
    # it. Empty when the output it is read from no longer exists.
    [Parameter()]
    [AllowEmptyString()]
    [AllowNull()]
    [string] $TotalCount
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($TotalCount)) {
    Write-Output "::error title=Tests::No test count was reported. The count comes from the 'TotalCount' output of PSModule/Invoke-Pester; if a version bump renamed or dropped it, this check is measuring nothing and has to be updated."
    exit 1
}

# Printable ASCII only, so a value carrying a newline cannot open a workflow
# command of its own on the line below it.
$shown = $TotalCount -replace '[^\x20-\x7E]', '?'
if ($TotalCount -notmatch '^\s*\d+\s*$') {
    Write-Output "::error title=Tests::The reported test count [$shown] is not a whole number, so nothing can be concluded from it."
    exit 1
}

if ([int] $TotalCount -eq 0) {
    Write-Output '::error title=Tests::The suites ran but executed no test - the run proved nothing. A check that checked nothing is a failure, not a pass.'
    exit 1
}

Write-Output "$([int] $TotalCount) test(s) executed."
