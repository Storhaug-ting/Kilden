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
        Tittel         = 'Lov om friluftslivet (friluftsloven)'
        Utgiver        = 'Lovdata'
        LovId          = '1957-06-28-16'
        Url            = 'https://lovdata.no/dokument/NL/lov/1957-06-28-16'
        Datasett       = 'gjeldende-lover'
        DatasettUrl    = 'https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2'
        DatasettSha256 = 'ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec'
        Kildefil       = 'nl-19570628-016.xml'
        Original       = 'friluftsloven.xml'
        Markdown       = 'friluftsloven.md'
        Sha256         = '8E637735DB93A37A8E81217D60BC97E3280EC03C440465F907CAFDB281895769'
        Hentet         = '2026-08-04'
        Bruk           = 'Allmennhetens ferdselsrett i utmark.'
    }
}
