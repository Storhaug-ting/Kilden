# Agents

The starting point for any agent working in this repository. Read this before changing anything.

## First — bootstrap the workspace

The workspace is a git-isolated clone of the central repositories under `~/.msx`. Set it up (idempotent — clones what is missing, attempts to fast-forward the rest):

```powershell
$docs = Join-Path $HOME '.msx/docs'
if ((Test-Path $docs) -and -not (Test-Path (Join-Path $docs '.git'))) {
    throw "$docs exists but is not a git repository. Remove it and re-run."
}
if (-not (Test-Path (Join-Path $docs '.git'))) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $docs) | Out-Null
    git clone https://github.com/MSXOrg/docs.git $docs
    if ($LASTEXITCODE -ne 0) {
        throw "git clone of MSXOrg/docs failed (exit $LASTEXITCODE). Check network access and github.com credentials, then re-run."
    }
}
pwsh (Join-Path $docs 'bootstrap/Initialize-MsxWorkspace.ps1')
```

This produces:

- `~/.msx/docs` — how work is done: ways of working, coding standards, and agent roles. The same content published at <https://msxorg.github.io/docs/>.
- `~/.msx/memory` — what has been learned before: durable notes and prior session context.

## Then — read before acting

1. Read the relevant pages under `~/.msx/docs` for the task at hand.
2. Read `~/.msx/memory` for prior decisions, pitfalls, and context.
3. Read [README.md](README.md) for what this repository holds and the rules that govern a source.

## This repository has two languages

Kilden reproduces documents published by others, in Norwegian, and wraps them in tooling that belongs to a wider ecosystem. The split is per artifact, not per repository.

| | |
|---|---|
| **The publisher's language** | The codified sources only: the original file and the markdown generated from it. They reproduce someone else's document and are never translated, corrected, or reworded. |
| **English** | Everything else. Code, file names, parameter and switch names, comments, log and error output, commit messages, branch names, issue and pull request text, workflow and job and step names, and every document in this repository, including this one. |

A Norwegian audience does not make the automation Norwegian. `-Frakoblet` and `-Offline` are the same switch, and a repository that names it twice cannot share a standard, a linter, or a script with any other repository in the ecosystem.

See [Natural Language](https://msxorg.github.io/docs/Coding-Standards/Natural-Language/) for the general rule.
