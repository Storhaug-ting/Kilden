# Forskrift om byggesak (byggesaksforskriften)

Forskriften regulerer saksbehandlingen i byggesaker: hva som er søknadspliktig, hvilke mindre tiltak som er unntatt, nabovarsel, ansvarsrett og kommunens tilsyn.

## Opphav

| | |
|---|---|
| **Tittel** | Forskrift om byggesak (byggesaksforskriften) |
| **Utgiver** | Lovdata |
| **LovId** | `2010-03-26-488` |
| **Original på nett** | <https://lovdata.no/dokument/SF/forskrift/2010-03-26-488> |
| **Datasett** | `gjeldende-sentrale-forskrifter` (Lovdata sitt åpne API) |
| **Datasettets URL** | <https://api.lovdata.no/v1/publicData/get/gjeldende-sentrale-forskrifter.tar.bz2> |
| **Datasettets SHA256** | `733f07c9840604c54f9a4d9d8f966e8e43a2ecb6e833a52f65246b9d7f56d859` |
| **Kildefil i datasettet** | `sf-20100326-0488.xml` |
| **Hentet** | 04.08.2026 |
| **SHA256 (lokal snapshot)** | `3D058DCD48C1D25FED4D78B938A1A7AA1C61D5122DA6EE89B5F5F5967DBA2D19` |

## En forskrift, ikke en lov

De andre Lovdata-kildene i denne repoen er lover, og de kommer fra datasettet
`gjeldende-lover`. Byggesaksforskriften er en forskrift, og forskrifter ligger i
et eget datasett – `gjeldende-sentrale-forskrifter` – med sitt eget filnavnmønster
(`sf-` i stedet for `nl-`, og fire siffer i løpenummeret).

Markupen inni XML-en er den samme, så konverteringen til markdown er delt med
lovene. Det er bare hvilket datasett kilden hentes fra som skiller dem, og det
står i `Opphav.Datasett` i `kilde.psd1`.

## Ikke en statisk original

De statiske kildene i denne repoen er en fil utgiveren har publisert med en fast
sjekksum – den lastes ned og sammenlignes mot den samme filen hver gang. Denne
kilden er annerledes: Lovdata har ingen enkelt fil å laste ned. De tilbyr i
stedet et åpent API som samler **alle** gjeldende sentrale forskrifter i ett
datasett, og datasettet blir ajourført hver natt – uavhengig av om forskriften
selv er endret.

`byggesaksforskriften.xml` i denne mappa er derfor ikke en fil Lovdata har
publisert et sted vi kan lenke til – det er en **snapshot**: den XML-en Lovdata
sitt API serverte for denne forskriften da datasettet ble hentet, kopiert inn
lokalt slik at den kan diffes mot en frisk henting. `kilde.psd1` sin `Sha256` er
sjekksummen til denne snapshoten, og `DatasettSha256` er sjekksummen til hele
arkivet den kom fra – begge er det vi kan bekrefte, ikke en sjekksum utgiveren
selv har publisert.

At en ny henting viser en annen snapshot betyr med andre ord ikke at noe er
«feil» – det betyr at Lovdata har ajourført forskriften siden forrige gang. Se
`Hentet`-datoen over for hvilken dag denne snapshoten stammer fra, og bruk
`scripts/Update-Lovtekst.ps1 byggesaksforskriften -GodtaNyVersjon -Skriv` for å
ta inn en ny versjon når det skjer.

## Filene

| # | Fil | Hva det er |
|---|-----|-----------|
| 1 | Denne `README.md` | Opphavet: hvor innholdet kommer fra, og hvorfor det ikke er en statisk original. |
| 2 | [byggesaksforskriften.xml](byggesaksforskriften.xml) | Lokal snapshot av forskriftens XML fra Lovdata sitt datasett, slik den sto ved hentingen over. |
| 3 | [byggesaksforskriften.md](byggesaksforskriften.md) | Maskingenerert markdown av XML-en. Denne leses og diffes. |
| | [kilde.psd1](kilde.psd1) | Oppskriften: LovId, datasett, sjekksummer og hentedato. |

Markdown-filen **redigeres ikke for hånd**. Den regenereres med:

```powershell
./scripts/Update-Lovtekst.ps1 byggesaksforskriften -Skriv
```

## Rettslig grunnlag for gjengivelse

Forskrifter er ikke opphavsrettslig vernet, jf. åndsverklova § 14: «Lover,
forskrifter, rettsavgjerder og andre vedtak av offentleg myndigheit er ikkje
omfatta av opphavsretten.» Se også dette repoets [README](../../README.md#copyright).
Lovdata tilbyr i tillegg gjeldende regelverk gjennom sitt åpne API uten
bruksbegrensninger, mot at Lovdata krediteres som kilde – det gjør denne
`README.md` og frontmatter i `byggesaksforskriften.md`.
