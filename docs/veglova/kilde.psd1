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
        Tittel         = 'Lov om vegar (veglova)'
        Utgiver        = 'Lovdata'
        LovId          = '1963-06-21-23'
        Url            = 'https://lovdata.no/dokument/NL/lov/1963-06-21-23'
        Datasett       = 'gjeldende-lover'
        DatasettUrl    = 'https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2'
        DatasettSha256 = 'ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec'
        Kildefil       = 'nl-19630621-023.xml'
        Original       = 'veglova.xml'
        Markdown       = 'veglova.md'
        Sha256         = '70DF6EA99A6BC74F17046F0AAC92393B27C60E9A1DD6781B2F55F17A0504A71F'
        Hentet         = '2026-08-04'
        Bruk           = 'Regulerer offentlige og private veger, herunder vedlikeholdsplikt og kostnadsfordeling for privat veg.'
    }
}
