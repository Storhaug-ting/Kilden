# Security Policy

## Supported versions

This repository has no releases. `main` is the only supported state, and it is
what every consumer reads.

## Reporting a vulnerability

Report privately through
[GitHub's private vulnerability reporting](https://github.com/Storhaug-ting/Kilden/security/advisories/new).
Do not open a public issue for something that is not yet fixed.

Expect an acknowledgement within a week.

## What counts as a vulnerability here

The obvious surface is the tooling: `scripts/Update-Source.ps1` downloads files
over the network, and `scripts/Convert-PdfToMarkdown.py` parses untrusted PDFs.
Anything that turns either into arbitrary code execution, a path traversal, or a
write outside the repository is in scope.

The less obvious surface matters more. The point of this repository is that a
source can be trusted to match what its publisher put out, so anything that
breaks that guarantee silently is a vulnerability:

- a change that makes the checksum check pass on content that does not match;
- a change that makes the conversion non-deterministic, so the check cannot tell
  a tampered source from a re-render;
- a source whose recorded checksum or origin URL does not match the document it
  claims to reproduce.

A dead link or a wrong conversion is a bug, not a vulnerability. Open an issue.
