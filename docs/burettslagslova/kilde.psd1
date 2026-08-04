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
        Tittel         = 'Lov om burettslag (burettslagslova)'
        Utgiver        = 'Lovdata'
        LovId          = '2003-06-06-39'
        Url            = 'https://lovdata.no/dokument/NL/lov/2003-06-06-39'
        Datasett       = 'gjeldende-lover'
        DatasettUrl    = 'https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2'
        DatasettSha256 = 'ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec'
        Kildefil       = 'nl-20030606-039.xml'
        Original       = 'burettslagslova.xml'
        Markdown       = 'burettslagslova.md'
        Sha256         = 'B36FF234DED0867B002BC2B0112437018BCDD2667A40EFC06E6984A7DFDF0EC2'
        Hentet         = '2026-08-04'
        Bruk           = 'Organisering av burettslag: vedtekter, årsmøte og felleskostnader.'
    }
}
