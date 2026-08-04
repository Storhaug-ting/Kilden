@{
    # ---------------------------------------------------------------------
    # Opphav – hvor innholdet kommer fra
    # ---------------------------------------------------------------------
    # Kilde = 'lovdata-api' skiller denne typen kilde fra de statiske
    # nedlastingene: teksten kommer ikke fra én fil utgiveren har publisert
    # med fast sjekksum, men fra Lovdata sitt åpne API, som ajourfører
    # datasettet hver natt. Se README.md i denne mappa for hva det betyr for
    # sporbarheten. scripts/Update-Lovtekst.ps1 håndterer denne typen kilde,
    # ikke scripts/Update-Source.ps1.
    #
    # Dette er en forskrift, ikke en lov, så den ligger i datasettet med
    # gjeldende sentrale forskrifter og har filnavn med sf- i stedet for nl-.
    Opphav   = @{
        Kilde          = 'lovdata-api'
        Tittel         = 'Forskrift om byggesak (byggesaksforskriften)'
        Utgiver        = 'Lovdata'
        LovId          = '2010-03-26-488'
        Url            = 'https://lovdata.no/dokument/SF/forskrift/2010-03-26-488'
        Datasett       = 'gjeldende-sentrale-forskrifter'
        DatasettUrl    = 'https://api.lovdata.no/v1/publicData/get/gjeldende-sentrale-forskrifter.tar.bz2'
        DatasettSha256 = '733f07c9840604c54f9a4d9d8f966e8e43a2ecb6e833a52f65246b9d7f56d859'
        Kildefil       = 'sf-20100326-0488.xml'
        Original       = 'byggesaksforskriften.xml'
        Markdown       = 'byggesaksforskriften.md'
        Sha256         = '3D058DCD48C1D25FED4D78B938A1A7AA1C61D5122DA6EE89B5F5F5967DBA2D19'
        Hentet         = '2026-08-04'
        Bruk           = 'Regulerer saksbehandlingen i byggesaker, herunder hva som er søknadspliktig, unntak for mindre tiltak, nabovarsel og ansvarsrett.'
    }
}
