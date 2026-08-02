# Kilder

Denne mappa er stedet for **eksternt materiale vi ikke eier selv**: veiledere,
lovtekster, standardvedtekter, artikler og annet vi bygger argumenter på.
Poenget er å kunne svare på tre spørsmål når som helst, uten å måtte lete på
nett igjen:

1. Hvor kommer dette fra?
2. Hvordan så det ut da vi hentet det?
3. Har det endret seg siden?

Se [index.md](index.md) for hva som ligger her.

## Slik er en kilde bygd opp

Hver kilde får sin egen mappe med et kortnavn i små bokstaver, og består av
**tre sett filer**:

| # | Fil | Hva det er |
|---|-----|-----------|
| 1 | `README.md` | **Opphavet.** Hvem har utgitt det, når, med lenke til originalen på nett, sjekksum og dato for når vi hentet det. |
| 2 | Originalfilen (`*.pdf`, `*.html`, …) | **Den lokale kopien**, byte for byte lik det som lå på nett den dagen den ble hentet. Filnavnet er det samme som i URL-en. |
| 3 | Markdown-filen (`*.md`) | **Den reverse-engineerte kilden.** En maskingenerert tekstversjon av originalen som kan leses i repoet, lenkes til med anker, og – viktigst – *diffes* når originalen endrer seg. |

I tillegg ligger `kilde.psd1` i mappa. Den er oppskriften: URL, forventet
sjekksum og reglene som styrer konverteringen. Den er det eneste stedet disse
opplysningene står, slik at README og markdown-filen ikke kan komme i utakt
med virkeligheten.

```text
sources/
├── README.md                      ← denne filen
├── index.md                       ← oversikt over alle kilder
├── scripts/
│   ├── Update-Source.ps1          ← henter, kontrollerer, konverterer
│   └── Convert-PdfToMarkdown.py   ← selve PDF-til-markdown-konverteringen
└── <kortnavn>/
    ├── README.md                  ← 1. opphav
    ├── <original>.pdf             ← 2. lokal kopi
    ├── <kortnavn>.md              ← 3. reverse-engineered kilde
    └── kilde.psd1                 ← oppskrift (URL, sjekksum, regler)
```

## Regler

- **Markdown-filen redigeres aldri for hånd.** Den er generert. Skal noe
  endres, endres konverteringsreglene i `kilde.psd1` og filen regenereres.
- **Originalen endres aldri.** Publiserer utgiveren en ny utgave, tar vi den
  inn som en ny versjon – da viser git-historikken nøyaktig hva som ble endret,
  både i PDF-en og i teksten.
- **Kilder er referanser, ikke vedtak.** Ingenting her er bindende for
  veiforeningen eller jordskiftesaken. Det er våre egne dokumenter som gjelder.
- **Opphavsrett respekteres.** Materiale som ikke kan videredistribueres,
  merkes med det i kildens `README.md`, og ligger her kun til intern bruk.
- **[index.md](index.md) oppdateres hver gang en kilde legges til, endres
  eller fjernes.**

## Bruk

Verktøykjeden ligger i [`scripts/`](scripts/) og deles av alle kilder.

```powershell
# Kontroller alle kilder mot nett og mot innsjekket markdown (endrer ingenting)
./sources/scripts/Update-Source.ps1

# Regenerer markdown for én kilde
./sources/scripts/Update-Source.ps1 veileder-bruksordning-for-veg -Skriv

# Ta inn en ny utgave som utgiveren har publisert
./sources/scripts/Update-Source.ps1 veileder-bruksordning-for-veg -GodtaNyVersjon -Skriv

# Kontroller uten nett
./sources/scripts/Update-Source.ps1 -Frakoblet
```

Skriptet avslutter med feil hvis den lokale kopien ikke stemmer med registrert
sjekksum, eller hvis markdown-filen ikke er identisk med det konverteringen
produserer. Det gjør det trygt å kjøre som en kontroll.

Krav: PowerShell 7, Python 3.9+ og `pdfplumber`
(`python -m pip install pdfplumber`).

## Legge til en ny kilde

1. Lag mappa `sources/<kortnavn>/`.
2. Legg inn `kilde.psd1` med `Opphav` (tittel, utgiver, URL, filnavn, sjekksum,
   hentet-dato) og `Profil` (konverteringsregler).
3. Kjør `./sources/scripts/Update-Source.ps1 <kortnavn> -GodtaNyVersjon -Skriv`.
   Da lastes originalen ned, sjekksummen registreres og markdown genereres.
4. Skriv `README.md` i mappa som forklarer hva kilden er og hvorfor vi har den.
5. **Legg kilden inn i [index.md](index.md).**

Konverteringsprofilen bestemmes av hvordan originalen ser ut. Reglene og hva
de betyr er dokumentert i `DEFAULT_PROFILE` øverst i
[`scripts/Convert-PdfToMarkdown.py`](scripts/Convert-PdfToMarkdown.py).

## Hvorfor markdown og ikke bare PDF-en?

En PDF kan ikke diffes. Når Domstoladministrasjonen endrer én setning i en
veileder på 61 sider, viser git bare at en binærfil er byttet ut. Markdown-
versjonen gjør endringen synlig linje for linje, og lar oss lenke direkte til
et kapittel eller en paragraf fra våre egne dokumenter.

Konverteringen er **deterministisk** – samme original gir alltid nøyaktig
samme markdown – og kontrolleres ord for ord mot PDF-en, slik at gjengivelsen
er etterprøvbart fullstendig.
