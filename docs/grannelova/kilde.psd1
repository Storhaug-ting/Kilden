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
        Tittel         = 'Lov om rettshøve mellom grannar (grannelova)'
        Utgiver        = 'Lovdata'
        LovId          = '1961-06-16-15'
        Url            = 'https://lovdata.no/dokument/NL/lov/1961-06-16-15'
        Datasett       = 'gjeldende-lover'
        DatasettUrl    = 'https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2'
        DatasettSha256 = 'ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec'
        Kildefil       = 'nl-19610616-015.xml'
        Original       = 'grannelova.xml'
        Markdown       = 'grannelova.md'
        Sha256         = '6DA513F10224BF26353EB6D8AA73252963CB231347B073B78A2241DC3444A3E1'
        Hentet         = '2026-08-05'
        Bruk           = 'Hva en nabo må tåle og ikke tåle av tiltak på naboeiendommen, herunder tålegrensen i § 2 og varslingsplikten før bygging.'
    }
}
