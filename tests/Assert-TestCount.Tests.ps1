#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0'; MaximumVersion = '6.*' }

Describe 'Assert-TestCount' {
    BeforeAll {
        $script:sourceScript = Join-Path $PSScriptRoot '..' 'scripts' 'Assert-TestCount.ps1'
        $script:pwsh = (Get-Process -Id $PID).Path

        function Invoke-Guard {
            <#
                .SYNOPSIS
                Run the guard and capture what it reported.

                .DESCRIPTION
                Invoke the script in a separate PowerShell process, because what this
                guard is worth is entirely in its exit code: the workflow step around it
                reads nothing else. Asserting in process would test a different thing
                than the one CI relies on.

                .EXAMPLE
                Invoke-Guard -ArgumentList '-TotalCount', '13'
                Returns the exit code and combined output.

                .OUTPUTS
                [pscustomobject]
            #>
            [CmdletBinding()]
            param(
                # Arguments passed on to the guard.
                [Parameter()]
                [string[]] $ArgumentList = @()
            )

            $output = & $script:pwsh -NoProfile -File $script:sourceScript @ArgumentList 2>&1 | Out-String

            return [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Output = $output
            }
        }
    }

    Context 'A run that executed something' {
        It 'passes a count above zero and says how many ran' {
            $result = Invoke-Guard -ArgumentList '-TotalCount', '13'

            $result.ExitCode | Should -Be 0
            $result.Output | Should -Match '13 test\(s\) executed\.'
        }

        It 'passes a count of one' {
            $result = Invoke-Guard -ArgumentList '-TotalCount', '1'

            $result.ExitCode | Should -Be 0
        }

        It 'passes a count padded with whitespace' {
            $result = Invoke-Guard -ArgumentList '-TotalCount', ' 7 '

            $result.ExitCode | Should -Be 0
            $result.Output | Should -Match '7 test\(s\) executed\.'
        }
    }

    Context 'A run that executed nothing' {
        It 'fails a count of zero and says the run proved nothing' {
            $result = Invoke-Guard -ArgumentList '-TotalCount', '0'

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match 'executed no test - the run proved nothing'
            $result.Output | Should -Match '::error title=Tests::'
        }
    }

    Context 'A count that never arrived' {
        # These are the cases a renamed or dropped action output produces. An
        # absent value must fail: a guard that reads empty as 'not zero, carry
        # on' has stopped measuring anything, and says so to nobody.
        It 'fails an empty count and names the output it comes from' {
            $result = Invoke-Guard -ArgumentList '-TotalCount', ''

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match 'No test count was reported'
            $result.Output | Should -Match 'TotalCount'
            $result.Output | Should -Match 'PSModule/Invoke-Pester'
        }

        It 'fails when the parameter is not passed at all' {
            $result = Invoke-Guard

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match 'No test count was reported'
        }

        It 'fails a count that is only whitespace' {
            $result = Invoke-Guard -ArgumentList '-TotalCount', '   '

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match 'No test count was reported'
        }

        It 'fails a count that is not a number' {
            $result = Invoke-Guard -ArgumentList '-TotalCount', 'null'

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match 'is not a whole number'
        }

        It 'fails a count that is negative' {
            $result = Invoke-Guard -ArgumentList '-TotalCount', '-1'

            $result.ExitCode | Should -Be 1
        }
    }
}
