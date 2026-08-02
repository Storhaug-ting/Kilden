# Contributing

Every change lands through a pull request — nothing goes directly to `main`. See the
[Contribution Workflow](https://msxorg.github.io/docs/Ways-of-Working/Contribution-Workflow/)
for the process, and the [Ways of Working](https://msxorg.github.io/docs/Ways-of-Working/)
for the conventions every pull request follows: issue format, PR format, branching, and
review etiquette.

See the [README](README.md) for what this repository holds and how a source is built.

## Which language to write in

A source reproduces a document someone else published, so it keeps that publisher's
language and wording. Everything built around it is English: code, file names, parameter
names, comments, log and error output, commit messages, issue and pull request text,
workflow and job names, and every document in this repository, including this one.

The split is per artifact, not per repository. See
[Natural Language](https://msxorg.github.io/docs/Coding-Standards/Natural-Language/).

## Rules a change has to hold to

- **Changes are additive.** A source is added, or an existing one is updated because the
  publisher released a new edition. A law or a guide is never corrected to fit an argument.
- **The generated markdown is never edited by hand.** It is produced by the conversion. To
  change what it says, change the conversion rules in `kilde.psd1` and regenerate it.
- **The original is never modified.** A new edition from the publisher comes in as a new
  version, so git history shows exactly what changed, in the original and in the text.
- **Sources are references, not decisions.** Nothing here binds anyone. The projects' own
  documents govern.
- **One source per pull request.** A change to a source is its own pull request, with its
  own history.
- **`docs/index.md` is updated whenever a source is added, changed, or removed.**

## Before adding a source

Only material that may lawfully be reproduced goes in, because the repository is public.
Read [Opphavsrett](README.md#opphavsrett) in the README first — it states which sources are
free under Norwegian law and which are kept out.

## Adding a source

1. Confirm the material may lawfully be reproduced here.
2. Create the folder `docs/<short-name>/`.
3. Add `kilde.psd1` with `Opphav` (title, publisher, URL, file name, checksum, retrieval
   date) and `Profil` (conversion rules).
4. Run `./scripts/Update-Source.ps1 <short-name> -GodtaNyVersjon -Skriv`. This downloads the
   original, records its checksum, and generates the markdown.
5. Write `README.md` in the folder: what the source is, who published it, and the grounds on
   which it can be kept here.
6. Add the source to [docs/index.md](docs/index.md).

The conversion profile depends on what the original looks like. The rules and their meaning
are documented in `DEFAULT_PROFILE` at the top of
[`scripts/Convert-PdfToMarkdown.py`](scripts/Convert-PdfToMarkdown.py).

## Checking a change

```powershell
# Verify every source against the web and against the checked-in markdown (changes nothing)
./scripts/Update-Source.ps1

# Verify without network access
./scripts/Update-Source.ps1 -Frakoblet
```

The script exits with an error if a local copy does not match its recorded checksum, or if
the markdown is not identical to what the conversion produces. The same checks run on every
pull request through [the workflow](.github/workflows/verify-sources.yml).

Requirements: PowerShell 7, Python 3.9 or later, and `pdfplumber`
(`python -m pip install pdfplumber`).
