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
        Tittel         = 'Lov om sameige [sameigelova]'
        Utgiver        = 'Lovdata'
        LovId          = '1965-06-18-6'
        Url            = 'https://lovdata.no/dokument/NL/lov/1965-06-18-6'
        Datasett       = 'gjeldende-lover'
        DatasettUrl    = 'https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2'
        DatasettSha256 = 'ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec'
        Kildefil       = 'nl-19650618-006.xml'
        Original       = 'sameigelova.xml'
        Markdown       = 'sameigelova.md'
        Sha256         = '34A0C3B7046368ECC8CE953EFC6931C1FDEB506F0591F078B4AB9F3317610628'
        Hentet         = '2026-08-04'
        Bruk           = 'Regler for sameige: bruk, kostnadsdeling og vedtak ved flertall.'
    }
}
