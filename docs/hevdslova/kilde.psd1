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
    Opphav   = @{
        Kilde          = 'lovdata-api'
        Tittel         = 'Lov om hevd [hevdslova]'
        Utgiver        = 'Lovdata'
        LovId          = '1966-12-09-1'
        Url            = 'https://lovdata.no/dokument/NL/lov/1966-12-09-1'
        Datasett       = 'gjeldende-lover'
        DatasettUrl    = 'https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2'
        DatasettSha256 = 'ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec'
        Kildefil       = 'nl-19661209-001.xml'
        Original       = 'hevdslova.xml'
        Markdown       = 'hevdslova.md'
        Sha256         = 'E2CC6B793C2E422685F9A4F3E86ECF14CF6E7E37739B8B3CC4D3FEC3247C9C32'
        Hentet         = '2026-08-04'
        Bruk           = 'Regler for hevd av rettar, herunder brukshevd av vegrett.'
    }
}
