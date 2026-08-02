#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0'; MaximumVersion = '6.*' }

Describe 'Test-MarkdownLink' {
    BeforeAll {
        $script:sourceScript = Join-Path $PSScriptRoot '..' 'scripts' 'Test-MarkdownLink.ps1'
        $script:pwsh = (Get-Process -Id $PID).Path
        $script:utf8 = [System.Text.UTF8Encoding]::new($false)

        function New-LinkFixture {
            <#
                .SYNOPSIS
                Create a throwaway repository for the link check to run against.

                .DESCRIPTION
                Lay out what 'Test-MarkdownLink.ps1' expects - a copy of itself under
                'scripts', so its root resolves to the fixture - and write the page under
                test to 'docs/Page.md'. 'docs/Real.md' always exists as a valid link
                target with a '#section' anchor; 'Missing.md' never exists.

                Omitting '-Content' leaves the fixture without a single Markdown file,
                which is the empty-run case. '-BelowHiddenDirectory' puts the whole
                fixture under a directory whose name begins with a dot, the way a
                checkout under '.cache' or '.copilot' sits.

                .EXAMPLE
                New-LinkFixture -Content '# Page'
                Returns the fixture root and the path of the script copy to invoke.

                .OUTPUTS
                [pscustomobject]
            #>
            [CmdletBinding(SupportsShouldProcess)]
            param(
                # The Markdown body written to 'docs/Page.md'. Omit it to create a
                # repository holding no Markdown at all.
                [Parameter()]
                [AllowEmptyString()]
                [string] $Content,

                # Further files to write, keyed by their path relative to the fixture
                # root. Parent directories are created as needed.
                [Parameter()]
                [hashtable] $ExtraFile = @{},

                # Create the fixture below a directory whose name begins with a dot.
                [Parameter()]
                [switch] $BelowHiddenDirectory
            )

            $prefix = if ($BelowHiddenDirectory) { '.kilden-' } else { 'kilden-' }
            $container = Join-Path ([System.IO.Path]::GetTempPath()) "$prefix$([guid]::NewGuid().ToString('N'))"
            $root = Join-Path $container 'Kilden'
            if (-not $PSCmdlet.ShouldProcess($root, 'Create link check fixture')) {
                return
            }

            $scripts = New-Item -ItemType Directory -Path (Join-Path $root 'scripts')
            Copy-Item -LiteralPath $script:sourceScript -Destination $scripts.FullName

            if ($PSBoundParameters.ContainsKey('Content')) {
                $docs = New-Item -ItemType Directory -Path (Join-Path $root 'docs')
                [System.IO.File]::WriteAllText((Join-Path $docs.FullName 'Real.md'), "# Real`n`n## Section`n", $script:utf8)
                [System.IO.File]::WriteAllText((Join-Path $docs.FullName 'Page.md'), $Content, $script:utf8)
            }

            foreach ($relative in $ExtraFile.Keys) {
                $destination = Join-Path $root $relative
                $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination)
                [System.IO.File]::WriteAllText($destination, $ExtraFile[$relative], $script:utf8)
            }

            return [pscustomobject]@{
                Container = $container
                Root = $root
                ScriptPath = Join-Path $scripts.FullName 'Test-MarkdownLink.ps1'
            }
        }

        function Invoke-LinkFixture {
            <#
                .SYNOPSIS
                Run a fixture's copy of the link check and capture what it reported.

                .DESCRIPTION
                Invoke the script in a separate PowerShell process, so the assertion is
                made on the exit code and the console output an operator and a workflow
                see, and not on internal state a caller could reach around. The counts
                in the summary line are parsed out, because the number of links checked
                is what separates a check that passed from a check that ran over
                nothing.

                .EXAMPLE
                Invoke-LinkFixture -ScriptPath $fixture.ScriptPath
                Returns the exit code, the combined output, and the two counts.

                .OUTPUTS
                [pscustomobject]
            #>
            [CmdletBinding()]
            param(
                # Path to the fixture's copy of 'Test-MarkdownLink.ps1'.
                [Parameter(Mandatory)]
                [string] $ScriptPath,

                # Arguments passed on to the script.
                [Parameter()]
                [string[]] $ArgumentList = @()
            )

            $output = & $script:pwsh -NoProfile -File $ScriptPath @ArgumentList 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
            $summary = [regex]::Match($output, '(?<links>\d+) link\(s\) checked in (?<files>\d+) file\(s\)')

            return [pscustomobject]@{
                ExitCode = $exitCode
                Output = $output
                Links = if ($summary.Success) { [int] $summary.Groups['links'].Value } else { $null }
                Files = if ($summary.Success) { [int] $summary.Groups['files'].Value } else { $null }
            }
        }
    }

    AfterEach {
        if ((Test-Path -LiteralPath 'variable:fixture') -and $fixture -and (Test-Path -LiteralPath $fixture.Container)) {
            Remove-Item -LiteralPath $fixture.Container -Recurse -Force
        }
    }

    Context 'A checkout that sits somewhere unusual' {
        It 'checks the files in a checkout below a hidden directory' {
            $fixture = New-LinkFixture -BelowHiddenDirectory -Content @'
# Page

See [the real page](./Real.md) and [its section](./Real.md#section).
'@

            $result = Invoke-LinkFixture -ScriptPath $fixture.ScriptPath

            $result.ExitCode | Should -Be 0
            $result.Files | Should -BeGreaterThan 0
            $result.Links | Should -BeGreaterThan 0
            $result.Output | Should -Match 'Every one of them resolves\.'
        }

        It 'still skips a hidden directory inside the repository' {
            $fixture = New-LinkFixture -Content @'
# Page

See [the real page](./Real.md).
'@ -ExtraFile @{ '.venv/Ignored.md' = "# Ignored`n`n[nowhere](./Nope.md)`n" }

            $result = Invoke-LinkFixture -ScriptPath $fixture.ScriptPath

            $result.ExitCode | Should -Be 0
            $result.Files | Should -Be 2
            $result.Output | Should -Not -Match 'Nope\.md'
        }
    }

    Context 'A run that examined nothing' {
        It 'fails when it found no Markdown file' {
            $fixture = New-LinkFixture

            $result = Invoke-LinkFixture -ScriptPath $fixture.ScriptPath

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match 'No markdown files were found'
            $result.Output | Should -Match 'A check that checked nothing is a failure, not a pass\.'
            $result.Output | Should -Not -Match 'resolves'
        }

        It 'fails and names the file when -Path does not exist' {
            $fixture = New-LinkFixture -Content '# Page'

            $result = Invoke-LinkFixture -ScriptPath $fixture.ScriptPath -ArgumentList '-Path', 'docs/Absent.md'

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match 'docs/Absent\.md'
            $result.Output | Should -Match 'do not name a file'
            # A stack trace pointing at a line number is not a report.
            $result.Output | Should -Not -Match 'Get-Item'
        }

        It 'checks only the file -Path names' {
            $fixture = New-LinkFixture -Content @'
# Page

See [the real page](./Real.md).
'@

            $result = Invoke-LinkFixture -ScriptPath $fixture.ScriptPath -ArgumentList '-Path', 'docs/Page.md'

            $result.ExitCode | Should -Be 0
            $result.Files | Should -Be 1
            $result.Links | Should -Be 1
        }
    }

    Context 'A link that leads nowhere' {
        It 'accepts a page whose links and anchors all resolve' {
            $fixture = New-LinkFixture -Content @'
# Page

See [the real page](./Real.md), [its section](./Real.md#section), and
[this page](#page).
'@

            $result = Invoke-LinkFixture -ScriptPath $fixture.ScriptPath

            $result.ExitCode | Should -Be 0
            $result.Links | Should -Be 3
            $result.Output | Should -Match 'Every one of them resolves\.'
        }

        It 'reports a relative link whose target does not exist' {
            $fixture = New-LinkFixture -Content @'
# Page

See [the missing page](./Missing.md).
'@

            $result = Invoke-LinkFixture -ScriptPath $fixture.ScriptPath

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match '1 do not resolve:'
            $result.Output | Should -Match "docs/Page\.md:3: '\./Missing\.md' - the target does not exist"
        }

        It 'reports an anchor no heading on the page produces' {
            $fixture = New-LinkFixture -Content @'
# Page

See [the missing section](#absent-section).
'@

            $result = Invoke-LinkFixture -ScriptPath $fixture.ScriptPath

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match "docs/Page\.md:3: '#absent-section' - no heading on this page produces that anchor"
        }

        It 'reports an anchor no heading in the target file produces' {
            $fixture = New-LinkFixture -Content @'
# Page

See [the missing section](./Real.md#absent-section).
'@

            $result = Invoke-LinkFixture -ScriptPath $fixture.ScriptPath

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match "'\./Real\.md#absent-section' - no heading in the target file produces that anchor"
        }
    }

    Context 'Anchors GitHub computes in a particular way' {
        # The expected anchors are the ones github-slugger produces, written out
        # literally rather than derived here. A test that recomputed them the way
        # the script does would only confirm the script agrees with itself.
        It 'accepts the suffixes a repeated heading is given' {
            $fixture = New-LinkFixture -Content @'
# Duplicates

## Same

## Same

## Same

## Same-1

[first](#same), [second](#same-1), [third](#same-2), [fourth](#same-1-1).
'@

            $result = Invoke-LinkFixture -ScriptPath $fixture.ScriptPath

            $result.ExitCode | Should -Be 0
            $result.Links | Should -Be 4
        }

        It 'reports a suffix no repeated heading reaches' {
            $fixture = New-LinkFixture -Content @'
# Duplicates

## Same

## Same

[fourth](#same-3).
'@

            $result = Invoke-LinkFixture -ScriptPath $fixture.ScriptPath

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match "'#same-3' - no heading on this page produces that anchor"
        }

        It 'accepts the anchor of a heading holding inline code' {
            $fixture = New-LinkFixture -Content @'
# Page

## The `slug` function

See [the function](#the-slug-function).
'@

            $result = Invoke-LinkFixture -ScriptPath $fixture.ScriptPath

            $result.ExitCode | Should -Be 0
            $result.Links | Should -Be 1
        }
    }
}
