# Veileder for bruksordning for veg

Domstoladministrasjonens veileder for jordskifterettenes behandling av
bruksordning på privat veg. Den inneholder blant annet
**eksempelvedtektene for veglag** som jordskifterettene bruker når de stifter
eller endrer et veglag – både en omfattende versjon for større lag (kap. 3.1)
og en enklere versjon for mindre lag (kap. 3.2).

Dette er den tyngste kilden vi har for vedtektsarbeidet i Stunnerveien
veiforening, og den jordskifteretten selv viser til.

## Opphav

| | |
|---|---|
| **Tittel** | Veileder for bruksordning for veg |
| **Utgiver** | Domstoladministrasjonen |
| **Utarbeidet av** | Arbeidsgruppe for «Bruksordning for veg» |
| **Dato** | 21.08.2019 |
| **Senere endringer** | Januar 2022 (omfattende vedtekter § 5-2) og februar 2024 (§ 17 for større lag / § 13 for mindre lag) |
| **Omfang** | 61 sider |
| **Original på nett** | <https://www.domstol.no/globalassets/da/veiledere-og-rapporter/jordskifte/veileder---bruksordning-for-veg.pdf> |
| **Landingsside** | <https://www.domstol.no/no/jordskifterettene/> |
| **Hentet** | 02.08.2026 |
| **SHA256** | `1E4BF103744D2EF7CDBD04274B8720AB032DCB6266530E1AABFF0D026494D2F4` |
| **Størrelse** | 900 530 byte |

Veilederen er en offentlig publikasjon fra Domstoladministrasjonen. Den er
lagret lokalt for referanse og sporbarhet i jordskiftesaken.

Domstoladministrasjonen tilbyr også eksempelvedtektene i **redigeringsformat**
som egne filer på landingssiden over. De er ikke tatt inn her – trengs et
redigerbart utgangspunkt, hentes de derfra.

## Filene

| # | Fil | Hva det er |
|---|-----|-----------|
| 1 | Denne `README.md` | Opphavet: hvor innholdet kommer fra, med lenke til originalen på nett. |
| 2 | [veileder---bruksordning-for-veg.pdf](veileder---bruksordning-for-veg.pdf) | Lokal kopi av originalen, byte-identisk med filen på domstol.no. |
| 3 | [veileder-bruksordning-for-veg.md](veileder-bruksordning-for-veg.md) | Maskingenerert markdown av PDF-en. Denne leses og diffes. |
| | [kilde.psd1](kilde.psd1) | Oppskriften: URL, forventet sjekksum og konverteringsreglene. |

Markdown-filen **redigeres ikke for hånd**. Den regenereres med:

```powershell
./sources/scripts/Update-Source.ps1 veileder-bruksordning-for-veg -Skriv
```

## Hvordan gjengivelsen er laget

PDF-en er tekstbasert, og teksten bygges opp fra tegnnivå. Det er nødvendig
fordi veilederen bruker **kapitéler** i alle overskrifter: Word tegner dem med
stor skriftstørrelse på bokstaver som opprinnelig var STORE og en mindre
størrelse på dem som var små. Tegnstørrelsen lar oss derfor gjenskape den
opprinnelige skrivemåten («Noen aktuelle tema ved bruksordning for veg») i
stedet for å gjette på en tittelform.

Dette er endret i forhold til PDF-en, og bare dette:

- **Løpende bunntekst** («Bruksordning for veg | side N av 61») er fjernet.
- **Innholdsfortegnelsen** er generert på nytt med fungerende ankerlenker, i
  stedet for PDF-ens punktledere og sidetall.
- **Fotnoter** er samlet nederst som markdown-fotnoter, med henvisninger
  (`[^n]`) der de opphøyde tallene står i teksten.
- **Flytskjemaet** på side 19 er gjengitt som en punktliste over boksene i
  figuren, i leserekkefølge.
- **Overskrifter** har ikke med fet/kursiv fra PDF-en, siden en overskrift
  allerede er uthevet.

Alt annet – avsnitt, punktlister, kursiv, fet skrift, tabeller, paragraftekst –
følger originalen. Konverteringen kontrolleres ord for ord: hvert eneste ord i
PDF-en må finnes igjen i markdown-filen, ellers feiler
`Update-Source.ps1`. Nåværende dekning er **100 %**.

Kapittelstrukturen i markdown-filen er sammenlignet med PDF-ens egen
innholdsfortegnelse og stemmer overens, med undertitler (§-ene og punktene
3.1/4.1.1 og lignende) i tillegg.

## Merknad om kap. 3.2 § 11

Overskriften står som `§ 11 KOSTNADER` uten punktum i markdown-filen. Det er
riktig gjengitt – punktumet mangler i originalen.
