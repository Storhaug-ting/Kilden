# Lov om eierseksjoner (eierseksjonsloven)

Organisering av eierseksjonssameier: sameiets organer og kostnadsfordeling — en sammenlignbar organisasjonsmodell til veglag.

## Opphav

| | |
|---|---|
| **Tittel** | Lov om eierseksjoner (eierseksjonsloven) |
| **Utgiver** | Lovdata |
| **LovId** | `2017-06-16-65` |
| **Original på nett** | <https://lovdata.no/dokument/NL/lov/2017-06-16-65> |
| **Datasett** | `gjeldende-lover` (Lovdata sitt åpne API) |
| **Datasettets URL** | <https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2> |
| **Datasettets SHA256** | `ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec` |
| **Kildefil i datasettet** | `nl-20170616-065.xml` |
| **Hentet** | 04.08.2026 |
| **SHA256 (lokal snapshot)** | `5E9A9CA5C65D6C4D6CEC9211E84F5DDE92CEAE1FF264946DC71236E05D4427EF` |

## Ikke en statisk original

De andre kildene i denne repoen er en fil utgiveren har publisert med en fast
sjekksum – den lastes ned og sammenlignes mot den samme filen hver gang.
Denne kilden er annerledes: Lovdata har ingen enkelt fil å laste ned. De
tilbyr i stedet et åpent API som samler **alle** gjeldende lover i ett
datasett (`gjeldende-lover`), og datasettet blir ajourført hver natt –
uavhengig av om loven selv er endret.

`eierseksjonslova.xml` i denne mappa er derfor ikke en fil Lovdata har publisert et
sted vi kan lenke til – det er en **snapshot**: den XML-en Lovdata sitt API
serverte for denne loven da datasettet ble hentet, kopiert inn lokalt slik at
den kan diffes mot en frisk henting. `kilde.psd1` sin `Sha256` er sjekksummen
til denne snapshoten, og `DatasettSha256` er sjekksummen til hele arkivet den
kom fra – begge er det vi kan bekrefte, ikke en sjekksum utgiveren selv har
publisert.

At en ny henting viser en annen snapshot betyr med andre ord ikke at noe er
«feil» – det betyr at Lovdata har ajourført loven siden forrige gang. Se
`Hentet`-datoen over for hvilken dag denne snapshoten stammer fra, og bruk
`scripts/Update-Lovtekst.ps1 eierseksjonslova -GodtaNyVersjon -Skriv` for å ta inn
en ny versjon når det skjer.

## Filene

| # | Fil | Hva det er |
|---|-----|-----------|
| 1 | Denne `README.md` | Opphavet: hvor innholdet kommer fra, og hvorfor det ikke er en statisk original. |
| 2 | [eierseksjonslova.xml](eierseksjonslova.xml) | Lokal snapshot av lovens XML fra Lovdata sitt datasett, slik den sto ved hentingen over. |
| 3 | [eierseksjonslova.md](eierseksjonslova.md) | Maskingenerert markdown av XML-en. Denne leses og diffes. |
| | [kilde.psd1](kilde.psd1) | Oppskriften: LovId, datasett, sjekksummer og hentedato. |

Markdown-filen **redigeres ikke for hånd**. Den regenereres med:

```powershell
./scripts/Update-Lovtekst.ps1 eierseksjonslova -Skriv
```

## Rettslig grunnlag for gjengivelse

Lover er ikke opphavsrettslig vernet, jf. åndsverklova § 14: «Lover,
forskrifter, rettsavgjerder og andre vedtak av offentleg myndigheit er ikkje
omfatta av opphavsretten.» Se også dette repoets [README](../../README.md#copyright).
Lovdata tilbyr i tillegg gjeldende regelverk gjennom sitt åpne API uten
bruksbegrensninger, mot at Lovdata krediteres som kilde – det gjør denne
`README.md` og frontmatter i `eierseksjonslova.md`.
