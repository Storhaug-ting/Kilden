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
        Tittel         = 'Lov om fastsetjing og endring av eigedoms- og rettshøve på fast eigedom m.m. (jordskiftelova)'
        Utgiver        = 'Lovdata'
        LovId          = '2013-06-21-100'
        Url            = 'https://lovdata.no/dokument/NL/lov/2013-06-21-100'
        Datasett       = 'gjeldende-lover'
        DatasettUrl    = 'https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2'
        DatasettSha256 = 'ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec'
        Kildefil       = 'nl-20130621-100.xml'
        Original       = 'jordskiftelova.xml'
        Markdown       = 'jordskiftelova.md'
        Sha256         = '65DC0F94816A184C2C438717FC120BA26DFA51F899B12E3E35A88617A063B5FF'
        Hentet         = '2026-08-04'
        Bruk           = 'Prosessloven for jordskifterettene: saksbehandling, bruksordning og skjønn.'
    }
}
