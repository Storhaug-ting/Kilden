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
        Tittel         = 'Lov um særlege råderettar over framand eigedom [servituttlova]'
        Utgiver        = 'Lovdata'
        LovId          = '1968-11-29'
        Url            = 'https://lovdata.no/dokument/NL/lov/1968-11-29'
        Datasett       = 'gjeldende-lover'
        DatasettUrl    = 'https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2'
        DatasettSha256 = 'ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec'
        Kildefil       = 'nl-19681129-000.xml'
        Original       = 'servituttlova.xml'
        Markdown       = 'servituttlova.md'
        Sha256         = '3FBE3973E79A224FCCE8A3059A573306BF2D8C4FD4F0F5B4BF0505E2E128D26A'
        Hentet         = '2026-08-04'
        Bruk           = 'Regler for servitutter (bruksrettar) over fremmed eiendom, herunder vegrett.'
    }
}
