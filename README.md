# Kilden

**Codified representations of external sources.**

This repository holds material **we do not own** — guides, statutes, standard
documents, and other things someone else has published, that we build arguments
on. The point is to be able to answer three questions at any time, without
having to search the web again:

1. Where does this come from?
2. What did it look like when we retrieved it?
3. Has it changed since?

See [docs/index.md](docs/index.md) for what lives here.

## What belongs here — and what doesn't

| | |
|---|---|
| **Belongs here** | External material published by others: guides, statutes, regulations, standard documents, official reports. |
| **Doesn't belong here** | Anything that is our own or tied to a single case: bylaws, membership lists, meeting minutes, case documents, correspondence, calculations. That lives in the project repository it concerns. |

The split is not a formality. A source has to be verifiable against the
publisher's original. Mixing in our own documents removes that possibility.

## Why a separate repo

The sources used to live in a `sources/` folder in the project repo. That
required a separate check to enforce that one change never touched both
source content and project content at once. As its own repo, it follows
naturally: a change to a source *is* its own pull request, in its own repo,
with its own history.

Project repos read from here and never write to it.

## How a source is built

All source material lives under [`docs/`](docs/). Each source gets its own
folder there with a lowercase short name, and consists of **three sets of
files**:

| # | File | What it is |
|---|-----|-----------|
| 1 | `README.md` | **The provenance.** Who published it, when, with a link to the original online, checksum, and the date we retrieved it. |
| 2 | The original file (`*.pdf`, `*.html`, …) | **The local copy**, byte for byte identical to what was online the day it was retrieved. The file name matches the one in the URL. |
| 3 | The markdown file (`*.md`) | **The reverse-engineered source.** A machine-generated text version of the original that can be read here, linked to with anchors, and — most importantly — *diffed* when the original changes. |

The folder also holds `kilde.psd1`. That is the recipe: URL, expected
checksum, and the rules that drive the conversion. It is the only place
these facts are recorded, so the README and the markdown file cannot drift
out of sync with reality.

```text
.
├── README.md                      ← this file
├── scripts/
│   ├── Update-Source.ps1          ← fetches, verifies, converts
│   ├── Convert-PdfToMarkdown.py   ← the actual PDF-to-markdown conversion
│   ├── Test-MarkdownLink.ps1      ← checks links and anchors
│   └── Assert-TestCount.ps1       ← fails the test job when nothing was tested
├── tests/
│   ├── Test-MarkdownLink.Tests.ps1  ← holds the link check to what it claims
│   └── Assert-TestCount.Tests.ps1   ← holds that guard to what it claims
└── docs/
    ├── index.md                   ← overview of all sources
    └── <short-name>/
        ├── README.md              ← 1. provenance
        ├── <original>.pdf         ← 2. local copy
        ├── <short-name>.md        ← 3. reverse-engineered source
        └── kilde.psd1             ← recipe (URL, checksum, rules)
```

## Copyright

The repo is public. Only material that may lawfully be reproduced goes in.

Norwegian law makes the most important sources free: under
[åndsverklova § 14](https://lovdata.no/lov/2018-06-15-40/§14), statutes,
regulations, and court decisions carry no copyright, and the same holds for
"proposals, reports, and other statements concerning the exercise of public
authority" issued or published by public bodies.

**Material from private actors — trade associations, publishers,
consultants — is not taken in here**, unless the license expressly permits
redistribution. If a project needs such material, it stays in that project's
own private repository.

Each source's `README.md` states the publisher and the basis on which it may
live here. Rights to the content belong to the publisher. What is ours is the
conversion and the setup around it.

## Usage

The tooling lives in [`scripts/`](scripts/) and is shared by all sources.

```powershell
# Verify every source against the web and against the checked-in markdown (changes nothing)
./scripts/Update-Source.ps1

# Regenerate the markdown for one source
./scripts/Update-Source.ps1 veileder-bruksordning-for-veg -Skriv

# Take in a new edition the publisher has released
./scripts/Update-Source.ps1 veileder-bruksordning-for-veg -GodtaNyVersjon -Skriv

# Verify without network access
./scripts/Update-Source.ps1 -Frakoblet
```

The script exits with an error if the local copy does not match its recorded
checksum, or if the markdown file is not identical to what the conversion
produces. That makes it safe to run as a check.

It says nothing, however, about whether the links inside the markdown file
work. That is a separate check:

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

All three checks run on every pull request; see
[the workflow](.github/workflows/verify-sources.yml).

Requirements: PowerShell 7, Python 3.9+, and `pdfplumber`
(`python -m pip install pdfplumber`), and Pester 6 for the tests.

## Why markdown, and not just the original?

A PDF cannot be diffed. When Domstoladministrasjonen changes one sentence in
a 61-page guide, git shows only that a binary file was swapped out. The
markdown version makes the change visible line by line, and lets us link
directly to a chapter or a paragraph from our own documents.

The conversion is **deterministic** — the same original always produces
exactly the same markdown — and is checked word for word against the
original, so the reproduction is verifiably complete.
