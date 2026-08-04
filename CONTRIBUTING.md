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

# Check that every relative link and heading anchor resolves
./scripts/Test-MarkdownLink.ps1

# Run the tests that hold the link check to what it claims
Invoke-Pester -Path ./tests
```

The script exits with an error if a local copy does not match its recorded checksum, or if
the markdown is not identical to what the conversion produces. The same checks run on every
pull request through [the workflow](.github/workflows/verify-sources.yml), which runs the
tests through [PSModule/Invoke-Pester](https://github.com/PSModule/Invoke-Pester).

Requirements: PowerShell 7, Python 3.9 or later, `pdfplumber`
(`python -m pip install pdfplumber`), and Pester 6 for the tests
(`Install-PSResource -Name Pester -Version 6.0.1`).

## Writing a test

Tests live in [`tests/`](tests/), one `*.Tests.ps1` file per script under test, and are
discovered from disk: a new file is run by the workflow the moment it lands.

Each test builds a throwaway repository in the temporary directory and runs the script under
test **in a separate process**, so what is asserted is the exit code and the output an
operator and a workflow see, and not internal state a caller could reach around.

Two rules are worth stating, because breaking either produces a suite that is green and says
nothing:

- **A check that checked nothing has failed.** Assert on the count, not only on the verdict.
  Every link resolving is trivially true when no link was found. The workflow applies the
  same rule to the suite itself: [`scripts/Assert-TestCount.ps1`](scripts/Assert-TestCount.ps1)
  reads how many tests ran and fails the job on zero — and on no answer at all, since a
  count that never arrived is not a count of zero.
- **Prove a new test can fail.** Break the behaviour it guards, watch it go red, read the
  message, then restore. A test that has never failed has not been tested.

See [Testing](https://msxorg.github.io/docs/Coding-Standards/Testing/) for the reasoning
behind both.
