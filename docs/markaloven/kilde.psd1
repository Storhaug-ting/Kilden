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
        Tittel         = 'Lov om naturområder i Oslo og nærliggende kommuner (markaloven)'
        Utgiver        = 'Lovdata'
        LovId          = '2009-06-05-35'
        Url            = 'https://lovdata.no/dokument/NL/lov/2009-06-05-35'
        Datasett       = 'gjeldende-lover'
        DatasettUrl    = 'https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2'
        DatasettSha256 = 'ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec'
        Kildefil       = 'nl-20090605-035.xml'
        Original       = 'markaloven.xml'
        Markdown       = 'markaloven.md'
        Sha256         = '3A2F9FCCFD1CF082FF86BD1FA1E2C3C6CF4759A913FBB6297AB0045497DC6C32'
        Hentet         = '2026-08-04'
        Bruk           = 'Vern av naturområder i Oslo og nærliggende kommuner (Marka).'
    }
}
