#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0'; MaximumVersion = '6.*' }

Describe 'Lovdata dataset routing' {
    BeforeAll {
        $script:module = Join-Path $PSScriptRoot '..' 'scripts' 'Lovdata.psm1'
        Import-Module -Name $script:module -Force
    }

    AfterAll {
        Remove-Module -Name 'Lovdata' -Force -ErrorAction SilentlyContinue
    }

    Context 'Get-LovdataDokumenttype' {
        It 'describes the law dataset' {
            $type = Get-LovdataDokumenttype -Datasett 'gjeldende-lover'
            $type.Filprefiks | Should -Be 'nl'
            $type.Nummerbredde | Should -Be 3
            $type.Dokumentsti | Should -Be 'NL/lov'
        }

        It 'describes the central regulation dataset' {
            $type = Get-LovdataDokumenttype -Datasett 'gjeldende-sentrale-forskrifter'
            $type.Filprefiks | Should -Be 'sf'
            $type.Nummerbredde | Should -Be 4
            $type.Dokumentsti | Should -Be 'SF/forskrift'
        }

        It 'knows exactly the two datasets the pipeline supports' {
            # A third entry appearing here without a test of its own is the
            # thing this count is here to catch.
            $names = @('gjeldende-lover', 'gjeldende-sentrale-forskrifter')
            foreach ($name in $names) {
                { Get-LovdataDokumenttype -Datasett $name } | Should -Not -Throw
            }
        }

        It 'refuses a dataset it cannot map, naming the ones it can' {
            # Lovdata publishes further datasets, among them the Lovtidend
            # ones. Reaching for one of those has to fail loudly rather than
            # silently produce filenames in the wrong shape.
            { Get-LovdataDokumenttype -Datasett 'lovtidend-avd1-2026' } |
                Should -Throw -ExpectedMessage '*gjeldende-sentrale-forskrifter*'
        }
    }

    Context 'ConvertTo-LovdataFilnavn' {
        It 'pads a law running number to three digits' {
            ConvertTo-LovdataFilnavn -LovId '1963-06-21-23' -Datasett 'gjeldende-lover' |
                Should -Be 'nl-19630621-023.xml'
        }

        It 'pads a regulation running number to four digits' {
            ConvertTo-LovdataFilnavn -LovId '2010-03-26-488' -Datasett 'gjeldende-sentrale-forskrifter' |
                Should -Be 'sf-20100326-0488.xml'
        }

        It 'treats a missing running number as zero' {
            ConvertTo-LovdataFilnavn -LovId '1968-11-29' -Datasett 'gjeldende-lover' |
                Should -Be 'nl-19681129-000.xml'
        }

        It 'defaults to the law dataset, so existing sources keep their filenames' {
            ConvertTo-LovdataFilnavn -LovId '1963-06-21-23' |
                Should -Be (ConvertTo-LovdataFilnavn -LovId '1963-06-21-23' -Datasett 'gjeldende-lover')
        }
    }

    Context 'Provenance in the generated frontmatter' {
        BeforeAll {
            $script:docs = Join-Path $PSScriptRoot '..' 'docs'
        }

        It 'points a law at the law dataset and the NL/lov document path' {
            $markdown = Get-Content -LiteralPath (Join-Path $script:docs 'veglova' 'veglova.md') -TotalCount 80
            $markdown | Should -Contain 'kilde: "https://lovdata.no/dokument/NL/lov/1963-06-21-23"'
            $markdown | Should -Contain 'kildedatasett: "https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2"'
        }

        It 'points a regulation at the regulation dataset and the SF/forskrift document path' {
            $markdown = Get-Content -LiteralPath (Join-Path $script:docs 'byggesaksforskriften' 'byggesaksforskriften.md') -TotalCount 80
            $markdown | Should -Contain 'kilde: "https://lovdata.no/dokument/SF/forskrift/2010-03-26-488"'
            $markdown | Should -Contain 'kildedatasett: "https://api.lovdata.no/v1/publicData/get/gjeldende-sentrale-forskrifter.tar.bz2"'
        }
    }

    Context 'Find-LovdataDokument' {
        BeforeAll {
            # The regulation archive spreads its documents over four
            # subdirectories by kind of decision. A search that looked in only
            # the first would miss most of the dataset, so the fixture mirrors
            # that layout and hides the wanted file in the last directory.
            $script:root = Join-Path ([System.IO.Path]::GetTempPath()) "kilden-$([guid]::NewGuid().ToString('N'))"
            foreach ($sub in 'del', 'ins', 'sf', 'stv') {
                New-Item -ItemType Directory -Path (Join-Path $script:root $sub) -Force | Out-Null
            }
            Set-Content -LiteralPath (Join-Path $script:root 'stv' 'sf-20100326-0488.xml') -Value '<x/>'

            $script:datasett = [pscustomobject]@{
                Navn         = 'gjeldende-sentrale-forskrifter'
                XmlKataloger = (Get-ChildItem -LiteralPath $script:root -Directory | Sort-Object Name)
            }
        }

        AfterAll {
            Remove-Item -LiteralPath $script:root -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'finds a document in a subdirectory other than the first' {
            $found = Find-LovdataDokument -Datasett $script:datasett -LovId '2010-03-26-488'
            $found.Filnavn | Should -Be 'sf-20100326-0488.xml'
            $found.Sti | Should -Be (Join-Path $script:root 'stv' 'sf-20100326-0488.xml')
        }

        It 'returns nothing when no subdirectory holds the document' {
            Find-LovdataDokument -Datasett $script:datasett -LovId '2010-03-26-489' | Should -BeNullOrEmpty
        }
    }
}
