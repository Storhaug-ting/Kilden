# Kilden

**Kodifiserte representasjoner av eksterne kilder.**

Dette repoet inneholder materiale vi **ikke eier selv** – veiledere, lovtekster,
standarddokumenter og annet som andre har utgitt, og som vi bygger argumenter på.
Poenget er å kunne svare på tre spørsmål når som helst, uten å måtte lete på nett
igjen:

1. Hvor kommer dette fra?
2. Hvordan så det ut da vi hentet det?
3. Har det endret seg siden?

Se [docs/index.md](docs/index.md) for hva som ligger her.

## Hva som hører hjemme her – og hva som ikke gjør det

| | |
|---|---|
| **Hører hjemme her** | Eksternt materiale utgitt av andre: veiledere, lovtekster, forskrifter, standarddokumenter, offentlige utredninger. |
| **Hører ikke hjemme her** | Alt som er vårt eget eller knyttet til én enkelt sak: vedtekter, medlemslister, møtereferater, saksdokumenter, korrespondanse, beregninger. Det ligger i prosjektrepoet det gjelder. |

Skillet er ikke en formalitet. En kilde skal kunne etterprøves mot originalen hos
utgiveren. Blandes våre egne dokumenter inn, forsvinner den muligheten.

## Hvorfor et eget repo

Kildene lå tidligere i en `sources/`-mappe i prosjektrepoet. Da måtte det
håndheves med en egen kontroll at én og samme endring ikke rørte kildeinnhold og
prosjektinnhold på én gang. Som eget repo følger det av seg selv: en endring i en
kilde *er* en egen pull request, i et eget repo, med egen historikk.

Prosjektrepoene leser herfra og skriver aldri hit.

## Slik er en kilde bygd opp

Alt kildemateriale ligger under [`docs/`](docs/). Hver kilde får sin egen mappe
der med et kortnavn i små bokstaver, og består av **tre sett filer**:

| # | Fil | Hva det er |
|---|-----|-----------|
| 1 | `README.md` | **Opphavet.** Hvem har utgitt det, når, med lenke til originalen på nett, sjekksum og dato for når vi hentet det. |
| 2 | Originalfilen (`*.pdf`, `*.html`, …) | **Den lokale kopien**, byte for byte lik det som lå på nett den dagen den ble hentet. Filnavnet er det samme som i URL-en. |
| 3 | Markdown-filen (`*.md`) | **Den reverse-engineerte kilden.** En maskingenerert tekstversjon av originalen som kan leses her, lenkes til med anker, og – viktigst – *diffes* når originalen endrer seg. |

I tillegg ligger `kilde.psd1` i mappa. Den er oppskriften: URL, forventet
sjekksum og reglene som styrer konverteringen. Den er det eneste stedet disse
opplysningene står, slik at README og markdown-filen ikke kan komme i utakt
med virkeligheten.

```text
.
├── README.md                      ← denne filen
├── scripts/
│   ├── Update-Source.ps1          ← henter, kontrollerer, konverterer
│   ├── Convert-PdfToMarkdown.py   ← selve PDF-til-markdown-konverteringen
│   └── Test-MarkdownLink.ps1      ← kontrollerer lenker og ankere
├── tests/
│   └── Test-MarkdownLink.Tests.ps1  ← holds the link check to what it claims
└── docs/
    ├── index.md                   ← oversikt over alle kilder
    └── <kortnavn>/
        ├── README.md              ← 1. opphav
        ├── <original>.pdf         ← 2. lokal kopi
        ├── <kortnavn>.md          ← 3. reverse-engineered kilde
        └── kilde.psd1             ← oppskrift (URL, sjekksum, regler)
```

## Opphavsrett

Repoet er offentlig. Derfor tas bare materiale inn som lovlig kan gjengis.

Norsk rett gjør de viktigste kildene frie: etter
[åndsverklova § 14](https://lovdata.no/lov/2018-06-15-40/§14) er lover,
forskrifter og rettsavgjørelser uten vern, og det samme gjelder «forslag,
utredninger og andre uttalelser som gjelder offentleg myndigheitsutøving» avgitt
eller utgitt av det offentlige.

**Materiale fra private aktører – bransjeforeninger, forlag, konsulenter – tas
ikke inn her**, med mindre lisensen uttrykkelig tillater videredistribusjon.
Trenger et prosjekt slikt materiale, blir det liggende i det private
prosjektrepoet til intern bruk.

Hver kildes `README.md` oppgir utgiver og hjemmelen for at den kan ligge her.
Rettighetene til innholdet tilhører utgiveren. Det som er vårt, er konverteringen
og oppsettet rundt.

## Bruk

Verktøykjeden ligger i [`scripts/`](scripts/) og deles av alle kilder.

```powershell
# Kontroller alle kilder mot nett og mot innsjekket markdown (endrer ingenting)
./scripts/Update-Source.ps1

# Regenerer markdown for én kilde
./scripts/Update-Source.ps1 veileder-bruksordning-for-veg -Skriv

# Ta inn en ny utgave som utgiveren har publisert
./scripts/Update-Source.ps1 veileder-bruksordning-for-veg -GodtaNyVersjon -Skriv

# Kontroller uten nett
./scripts/Update-Source.ps1 -Frakoblet
```

Skriptet avslutter med feil hvis den lokale kopien ikke stemmer med registrert
sjekksum, eller hvis markdown-filen ikke er identisk med det konverteringen
produserer. Det gjør det trygt å kjøre som en kontroll.

Det sier derimot ingenting om at lenkene i markdown-filen virker. Det er en egen
kontroll:

```powershell
./scripts/Test-MarkdownLink.ps1
```

It walks every markdown file, checks that relative links hit a file that exists,
and that every anchor matches a heading. Anchors are computed the way GitHub
computes them, deliberately not with the slug function inside the conversion — a
check built on the same function it verifies only confirms itself.

That check has tests of its own, because a check reporting success over nothing
looks exactly like one that worked:

```powershell
Invoke-Pester -Path ./tests
```

All three checks run on every pull request, see
[arbeidsflyten](.github/workflows/verify-sources.yml).

Krav: PowerShell 7, Python 3.9+ og `pdfplumber`
(`python -m pip install pdfplumber`), and Pester 6 for the tests.

## Hvorfor markdown og ikke bare originalen?

En PDF kan ikke diffes. Når Domstoladministrasjonen endrer én setning i en
veileder på 61 sider, viser git bare at en binærfil er byttet ut. Markdown-
versjonen gjør endringen synlig linje for linje, og lar oss lenke direkte til
et kapittel eller en paragraf fra våre egne dokumenter.

Konverteringen er **deterministisk** – samme original gir alltid nøyaktig
samme markdown – og kontrolleres ord for ord mot originalen, slik at
gjengivelsen er etterprøvbart fullstendig.
