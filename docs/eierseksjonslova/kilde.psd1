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
        Tittel         = 'Lov om eierseksjoner (eierseksjonsloven)'
        Utgiver        = 'Lovdata'
        LovId          = '2017-06-16-65'
        Url            = 'https://lovdata.no/dokument/NL/lov/2017-06-16-65'
        Datasett       = 'gjeldende-lover'
        DatasettUrl    = 'https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2'
        DatasettSha256 = 'ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec'
        Kildefil       = 'nl-20170616-065.xml'
        Original       = 'eierseksjonslova.xml'
        Markdown       = 'eierseksjonslova.md'
        Sha256         = '5E9A9CA5C65D6C4D6CEC9211E84F5DDE92CEAE1FF264946DC71236E05D4427EF'
        Hentet         = '2026-08-04'
        Bruk           = 'Organisering av eierseksjonssameier: sameiets organer og kostnadsfordeling.'
    }
}
