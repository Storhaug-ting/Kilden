# Lov om naturområder i Oslo og nærliggende kommuner (markaloven)

Vern av naturområder i Oslo og nærliggende kommuner (Marka), som kan begrense tiltak på og langs veg i det området loven gjelder.

## Opphav

| | |
|---|---|
| **Tittel** | Lov om naturområder i Oslo og nærliggende kommuner (markaloven) |
| **Utgiver** | Lovdata |
| **LovId** | `2009-06-05-35` |
| **Original på nett** | <https://lovdata.no/dokument/NL/lov/2009-06-05-35> |
| **Datasett** | `gjeldende-lover` (Lovdata sitt åpne API) |
| **Datasettets URL** | <https://api.lovdata.no/v1/publicData/get/gjeldende-lover.tar.bz2> |
| **Datasettets SHA256** | `ed8cf724f7e7e82406ac313c86161c1a2d941b66fa04cd64a95c44963d7506ec` |
| **Kildefil i datasettet** | `nl-20090605-035.xml` |
| **Hentet** | 04.08.2026 |
| **SHA256 (lokal snapshot)** | `3A2F9FCCFD1CF082FF86BD1FA1E2C3C6CF4759A913FBB6297AB0045497DC6C32` |

## Ikke en statisk original

De andre kildene i denne repoen er en fil utgiveren har publisert med en fast
sjekksum – den lastes ned og sammenlignes mot den samme filen hver gang.
Denne kilden er annerledes: Lovdata har ingen enkelt fil å laste ned. De
tilbyr i stedet et åpent API som samler **alle** gjeldende lover i ett
datasett (`gjeldende-lover`), og datasettet blir ajourført hver natt –
uavhengig av om loven selv er endret.

`markaloven.xml` i denne mappa er derfor ikke en fil Lovdata har publisert et
sted vi kan lenke til – det er en **snapshot**: den XML-en Lovdata sitt API
serverte for denne loven da datasettet ble hentet, kopiert inn lokalt slik at
den kan diffes mot en frisk henting. `kilde.psd1` sin `Sha256` er sjekksummen
til denne snapshoten, og `DatasettSha256` er sjekksummen til hele arkivet den
kom fra – begge er det vi kan bekrefte, ikke en sjekksum utgiveren selv har
publisert.

At en ny henting viser en annen snapshot betyr med andre ord ikke at noe er
«feil» – det betyr at Lovdata har ajourført loven siden forrige gang. Se
`Hentet`-datoen over for hvilken dag denne snapshoten stammer fra, og bruk
`scripts/Update-Lovtekst.ps1 markaloven -GodtaNyVersjon -Skriv` for å ta inn
en ny versjon når det skjer.

## Filene

| # | Fil | Hva det er |
|---|-----|-----------|
| 1 | Denne `README.md` | Opphavet: hvor innholdet kommer fra, og hvorfor det ikke er en statisk original. |
| 2 | [markaloven.xml](markaloven.xml) | Lokal snapshot av lovens XML fra Lovdata sitt datasett, slik den sto ved hentingen over. |
| 3 | [markaloven.md](markaloven.md) | Maskingenerert markdown av XML-en. Denne leses og diffes. |
| | [kilde.psd1](kilde.psd1) | Oppskriften: LovId, datasett, sjekksummer og hentedato. |

Markdown-filen **redigeres ikke for hånd**. Den regenereres med:

```powershell
./scripts/Update-Lovtekst.ps1 markaloven -Skriv
```

## Rettslig grunnlag for gjengivelse

Lover er ikke opphavsrettslig vernet, jf. åndsverklova § 14: «Lover,
forskrifter, rettsavgjerder og andre vedtak av offentleg myndigheit er ikkje
omfatta av opphavsretten.» Se også dette repoets [README](../../README.md#copyright).
Lovdata tilbyr i tillegg gjeldende regelverk gjennom sitt åpne API uten
bruksbegrensninger, mot at Lovdata krediteres som kilde – det gjør denne
`README.md` og frontmatter i `markaloven.md`.
