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
        Tittel         = 'Lov om planlegging og byggesaksbehandling (plan- og bygningsloven)'
        Utgiver        = 'Lovdata'
        LovId          = '2008-06-27-71'
        Url            = 'https://lovdata.no/dokument/NL/lov/2008-06-27-71'
        Datasett       = 'gjeldende-lover'
        DatasettUrl    = 'https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2'
        DatasettSha256 = 'ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec'
        Kildefil       = 'nl-20080627-071.xml'
        Original       = 'plan-og-bygningsloven.xml'
        Markdown       = 'plan-og-bygningsloven.md'
        Sha256         = '8002F824B37912432E7F2BFD9937CF4AD6FDC8F4A32D46477CDA1B50A2B4CB61'
        Hentet         = '2026-08-05'
        Bruk           = 'Rammene for arealplanlegging og byggesaksbehandling, herunder hva som er søknadspliktig tiltak, avstandskrav og kommunens rolle som plan- og bygningsmyndighet.'
    }
}
