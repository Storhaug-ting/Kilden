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
    # Loven har ingen løpenummer – den er «lov 5. mai 1961 om grannegjerde» –
    # så LovId er på formen ÅÅÅÅ-MM-DD, og datasettets filnavn får 000 som
    # løpenummer. Samme mønster som servituttlova.
    Opphav   = @{
        Kilde          = 'lovdata-api'
        Tittel         = 'Lov om grannegjerde [grannegjerdelova]'
        Utgiver        = 'Lovdata'
        LovId          = '1961-05-05'
        Url            = 'https://lovdata.no/dokument/NL/lov/1961-05-05'
        Datasett       = 'gjeldende-lover'
        DatasettUrl    = 'https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2'
        DatasettSha256 = 'ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec'
        Kildefil       = 'nl-19610505-000.xml'
        Original       = 'grannegjerdelova.xml'
        Markdown       = 'grannegjerdelova.md'
        Sha256         = 'F7D7418F823EBC361C44ED019BFF0F04FE5FE36B82302299B2631D246500C1B3'
        Hentet         = '2026-08-05'
        Bruk           = 'Rett og plikt til å ha gjerde mellom naboeiendommer, og hvordan kostnadene ved gjerdet fordeles.'
    }
}
