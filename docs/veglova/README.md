# Lov om vegar (veglova)

Loven regulerer offentlige og private veger, herunder plikten til å holde privat veg ved like og hvordan kostnadene fordeles mellom brukerne (§§ 53–56).

## Opphav

| | |
|---|---|
| **Tittel** | Lov om vegar (veglova) |
| **Utgiver** | Lovdata |
| **LovId** | `1963-06-21-23` |
| **Original på nett** | <https://lovdata.no/dokument/NL/lov/1963-06-21-23> |
| **Datasett** | `gjeldende-lover` (Lovdata sitt åpne API) |
| **Datasettets URL** | <https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2> |
| **Datasettets SHA256** | `ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec` |
| **Kildefil i datasettet** | `nl-19630621-023.xml` |
| **Hentet** | 04.08.2026 |
| **SHA256 (lokal snapshot)** | `70DF6EA99A6BC74F17046F0AAC92393B27C60E9A1DD6781B2F55F17A0504A71F` |

## Ikke en statisk original

De andre kildene i denne repoen er en fil utgiveren har publisert med en fast
sjekksum – den lastes ned og sammenlignes mot den samme filen hver gang.
Denne kilden er annerledes: Lovdata har ingen enkelt fil å laste ned. De
tilbyr i stedet et åpent API som samler **alle** gjeldende lover i ett
datasett (`gjeldende-lover`), og datasettet blir ajourført hver natt –
uavhengig av om loven selv er endret.

`veglova.xml` i denne mappa er derfor ikke en fil Lovdata har publisert et
sted vi kan lenke til – det er en **snapshot**: den XML-en Lovdata sitt API
serverte for denne loven da datasettet ble hentet, kopiert inn lokalt slik at
den kan diffes mot en frisk henting. `kilde.psd1` sin `Sha256` er sjekksummen
til denne snapshoten, og `DatasettSha256` er sjekksummen til hele arkivet den
kom fra – begge er det vi kan bekrefte, ikke en sjekksum utgiveren selv har
publisert.

At en ny henting viser en annen snapshot betyr med andre ord ikke at noe er
«feil» – det betyr at Lovdata har ajourført loven siden forrige gang. Se
`Hentet`-datoen over for hvilken dag denne snapshoten stammer fra, og bruk
`scripts/Update-Lovtekst.ps1 veglova -GodtaNyVersjon -Skriv` for å ta inn
en ny versjon når det skjer.

## Filene

| # | Fil | Hva det er |
|---|-----|-----------|
| 1 | Denne `README.md` | Opphavet: hvor innholdet kommer fra, og hvorfor det ikke er en statisk original. |
| 2 | [veglova.xml](veglova.xml) | Lokal snapshot av lovens XML fra Lovdata sitt datasett, slik den sto ved hentingen over. |
| 3 | [veglova.md](veglova.md) | Maskingenerert markdown av XML-en. Denne leses og diffes. |
| | [kilde.psd1](kilde.psd1) | Oppskriften: LovId, datasett, sjekksummer og hentedato. |

Markdown-filen **redigeres ikke for hånd**. Den regenereres med:

```powershell
./scripts/Update-Lovtekst.ps1 veglova -Skriv
```

## Rettslig grunnlag for gjengivelse

Lover er ikke opphavsrettslig vernet, jf. åndsverklova § 14: «Lover,
forskrifter, rettsavgjerder og andre vedtak av offentleg myndigheit er ikkje
omfatta av opphavsretten.» Se også dette repoets [README](../../README.md#opphavsrett).
Lovdata tilbyr i tillegg gjeldende regelverk gjennom sitt åpne API uten
bruksbegrensninger, mot at Lovdata krediteres som kilde – det gjør denne
`README.md` og frontmatter i `veglova.md`.
