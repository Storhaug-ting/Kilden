#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Validate that every relative Markdown link and heading anchor in this repository resolves.

.DESCRIPTION
    Walks the Markdown files in the repository and checks every link that points
    somewhere inside it:

    - A relative file target must exist on disk.
    - A heading anchor ('file.md#section', or a same-page '#section') must match a
      heading in the target file.

    This is the second of two checks, and it answers a different question than
    'Update-Source.ps1'. That one measures whether the text of a source matches
    the original word for word; it says nothing about whether the links in that
    text lead anywhere. A generated table of contents can be a perfect
    reproduction and still point at nothing.

    Anchors are computed the way GitHub computes them: the heading text is
    lowercased, everything that is not a letter, mark, digit, or connector is
    removed, spaces become hyphens, and a repeated anchor gets a '-1', '-2'
    suffix. Deliberately not reused from 'Convert-PdfToMarkdown.py', which has a
    slug function of its own - a check built on the same function it is meant to
    verify only confirms itself.

    External links, absolute paths, links inside fenced code blocks, and links
    inside inline code spans are ignored on purpose.

    It also exits 1 when it found no Markdown files at all. Every link resolving
    is trivially true when there are no links, so an empty run is a failure
    rather than a pass - a wrong root or an over-broad filter cannot make this
    check quietly green. A '-Path' that names something which is not a file
    fails the same way, naming what it could not find.

    The script changes nothing. It exits 0 when every link resolves, and exits 1
    listing each broken link otherwise, so it can gate a pull request.

.EXAMPLE
    ./scripts/Test-MarkdownLink.ps1
    Validates every Markdown file in the repository.

.EXAMPLE
    ./scripts/Test-MarkdownLink.ps1 -Path docs/index.md
    Validates a single file.
#>
[CmdletBinding()]
param(
    # Markdown files to validate. Defaults to every Markdown file in the repository.
    [Parameter()]
    [string[]] $Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot

function ConvertTo-GitHubSlug {
    <#
        .SYNOPSIS
        Convert heading text to the anchor GitHub gives it.

        .DESCRIPTION
        Mirror github-slugger, the library GitHub uses: lowercase the text, drop
        every character that is not a letter, mark, decimal or letter number, or
        connector punctuation - keeping hyphens and spaces - then turn spaces
        into hyphens.

        The character class is .NET's Unicode categories rather than the
        generated table github-slugger ships. The two were compared across every
        code point and agree exactly over Basic Latin, Latin-1, Latin Extended-A
        and B, Greek, Cyrillic, General Punctuation, currency, letterlike and
        number forms, and the emoji planes. They disagree on 52 code points in
        the arrows and symbols blocks and 3 in CJK, where the two Unicode
        versions classify a character differently.

        .EXAMPLE
        ConvertTo-GitHubSlug -Text 'Bruksordning for veg - § 3-8'
        Returns 'bruksordning-for-veg----3-8'.

        .OUTPUTS
        [string]
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The rendered heading text to convert.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text
    )
    return ($Text.ToLowerInvariant() -replace '[^\p{L}\p{M}\p{Nd}\p{Nl}\p{Pc}\- ]', '') -replace ' ', '-'
}

function Get-RenderedHeadingText {
    <#
        .SYNOPSIS
        Get the text a heading renders to, before it is turned into an anchor.

        .DESCRIPTION
        GitHub builds the anchor from the rendered heading, so the Markdown that
        only affects presentation is resolved first: a link keeps its text and
        loses its target, inline code keeps its content and loses its backticks,
        HTML tags and emphasis markers are dropped, and a trailing closing '#'
        run is removed.

        .EXAMPLE
        Get-RenderedHeadingText -Heading 'See the [guide](x.md) for `npm ci`'
        Returns 'See the guide for npm ci'.

        .OUTPUTS
        [string]
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The raw heading text, without its leading '#' characters.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Heading
    )
    $text = $Heading -replace '!?\[([^\]]*)\]\([^)]*\)', '$1'
    $text = $text -replace '<[^>]*>', ''
    $text = $text -replace '[`*_~]', ''
    return ($text -replace '\s+#+\s*$', '').Trim()
}

function Get-HeadingAnchor {
    <#
        .SYNOPSIS
        Get the anchors a Markdown file exposes.

        .DESCRIPTION
        Return every anchor in the file: one per heading, plus any explicit id on
        a raw HTML element, which GitHub honours as an anchor of its own. A
        repeated heading gets the '-1', '-2' suffix github-slugger appends, and
        the suffixed form is claimed too, so a heading that collides with an
        already generated suffix still gets a unique anchor. Fenced code blocks
        are skipped.

        .EXAMPLE
        Get-HeadingAnchor -LiteralPath ./docs/index.md
        Returns the anchors index.md exposes.

        .OUTPUTS
        [System.Collections.Generic.HashSet[string]]
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.HashSet[string]])]
    param(
        # Path to the Markdown file to scan.
        [Parameter(Mandatory)]
        [string] $LiteralPath
    )
    $anchors = [System.Collections.Generic.HashSet[string]]::new()
    $occurrences = @{}
    $fence = $null
    foreach ($line in [System.IO.File]::ReadAllLines($LiteralPath)) {
        if ($line -match '^\s{0,3}(`{3,}|~{3,})') {
            if ($null -eq $fence) { $fence = $matches[1] }
            elseif ($line -match "^\s{0,3}$([regex]::Escape($fence[0])){$($fence.Length),}\s*$") { $fence = $null }
            continue
        }
        if ($fence) { continue }
        foreach ($id in [regex]::Matches($line, '<[a-z][^>]*\sid\s*=\s*"([^"]+)"')) {
            $null = $anchors.Add($id.Groups[1].Value)
        }
        if ($line -notmatch '^\s{0,3}#{1,6}(\s+.*)?$') { continue }
        $slug = ConvertTo-GitHubSlug (Get-RenderedHeadingText ($line -replace '^\s{0,3}#{1,6}\s*', ''))
        $unique = $slug
        while ($occurrences.ContainsKey($unique)) {
            $occurrences[$slug]++
            $unique = "$slug-$($occurrences[$slug])"
        }
        $occurrences[$unique] = 0
        $null = $anchors.Add($unique)
    }
    return $anchors
}

$anchorCache = @{}
function Get-CachedAnchor {
    <#
        .SYNOPSIS
        Get a file's anchors, parsing each file only once.

        .DESCRIPTION
        Memoise Get-HeadingAnchor so a file linked from many places is scanned a
        single time.

        .EXAMPLE
        Get-CachedAnchor -LiteralPath ./docs/index.md
        Returns index.md's anchors, reading the file only on the first call.

        .OUTPUTS
        [System.Collections.Generic.HashSet[string]]
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.HashSet[string]])]
    param(
        # Path to the Markdown file whose anchors are wanted.
        [Parameter(Mandatory)]
        [string] $LiteralPath
    )
    if (-not $anchorCache.ContainsKey($LiteralPath)) {
        $anchorCache[$LiteralPath] = Get-HeadingAnchor -LiteralPath $LiteralPath
    }
    return $anchorCache[$LiteralPath]
}

function Get-LinkTargetIssue {
    <#
        .SYNOPSIS
        Get the problem with a single link target, if any.

        .DESCRIPTION
        Validate one link target. External schemes, protocol-relative and
        absolute paths, and empty targets are ignored; a relative path must exist
        on disk; and a '#fragment' must match an anchor - case-sensitively, as
        GitHub matches them - in the target file or, when the target is the page
        itself, on that page.

        .EXAMPLE
        Get-LinkTargetIssue -Target 'index.md#sources' -SourceFile $file -Display 'README.md' -LineNumber 12
        Returns a message when index.md or its '#sources' anchor is missing, otherwise nothing.

        .OUTPUTS
        [string]
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The raw link target: a destination and an optional '#fragment'.
        [Parameter(Mandatory)]
        [string] $Target,

        # The Markdown file the link appears in, used to resolve relative paths.
        [Parameter(Mandatory)]
        [System.IO.FileInfo] $SourceFile,

        # The file's repository-relative path, for the reported message.
        [Parameter(Mandatory)]
        [string] $Display,

        # The 1-based line number the link is on, for the reported message.
        [Parameter(Mandatory)]
        [int] $LineNumber
    )
    $target = ($Target.Trim() -replace '\s+("[^"]*"|''[^'']*''|\([^)]*\))$', '') -replace '^<', '' -replace '>$', ''
    if (-not $target) { return }
    if ($target -match '^([a-z][a-z0-9+.-]*:|//)') { return }

    $path, $fragment = $target -split '#', 2
    $path = [uri]::UnescapeDataString($path)
    $fragment = if ($fragment) { [uri]::UnescapeDataString($fragment) } else { '' }

    if (-not $path) {
        if ($fragment -and $fragment -cnotin (Get-CachedAnchor -LiteralPath $SourceFile.FullName)) {
            return "${Display}:${LineNumber}: '#$fragment' - no heading on this page produces that anchor"
        }
        return
    }
    if ($path.StartsWith('/')) { return }

    $resolved = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($SourceFile.DirectoryName, $path))
    if (-not ([System.IO.File]::Exists($resolved) -or [System.IO.Directory]::Exists($resolved))) {
        return "${Display}:${LineNumber}: '$target' - the target does not exist"
    }
    if (-not $fragment) { return }
    if (-not $resolved.EndsWith('.md', [System.StringComparison]::OrdinalIgnoreCase)) {
        return "${Display}:${LineNumber}: '$target' - an anchor into a file that is not Markdown"
    }
    if ($fragment -cnotin (Get-CachedAnchor -LiteralPath $resolved)) {
        return "${Display}:${LineNumber}: '$target' - no heading in the target file produces that anchor"
    }
}

# Inline links '[text](target)' and reference-style definitions '[label]: target'.
# The inline target may carry a title ("...", '...', or (...)); the nested-paren
# alternative keeps a parenthesised path such as 'Fullmakt (utkast).md' whole. A
# label starting with '^' is a footnote definition, whose text is prose, not a
# link target.
$inlineLinkPattern = '\[[^\]]*\]\(([^()]*(?:\([^()]*\)[^()]*)*)\)'
$referenceDefinitionPattern = '^\s{0,3}\[(?!\^)[^\]]+\]:\s+(<[^>]+>|\S+)'

# A typo in '-Path' is the same failure as an over-broad filter: the check ends
# up looking at less than it was asked to. Report it the way a broken link is
# reported, rather than letting Get-Item throw a stack trace at the operator.
if ($Path) {
    $missing = @($Path | Where-Object { -not [System.IO.File]::Exists([System.IO.Path]::Combine($Root, $_)) })
    if ($missing.Count -gt 0) {
        Write-Output "$($missing.Count) of the $($Path.Count) path(s) given with -Path do not name a file under ${Root}:"
        $missing | Sort-Object | ForEach-Object { Write-Output "  - $_" }
        Write-Output 'Nothing was validated.'
        exit 1
    }
}

$files = @(if ($Path) {
        $Path | ForEach-Object { Get-Item -LiteralPath ([System.IO.Path]::Combine($Root, $_)) }
    } else {
        # The exclusion is tested against the path below the root, not the full
        # path: a clone can itself sit under a dotted directory, and matching on
        # the full path would then exclude every file in the repository and
        # report a vacuous pass.
        Get-ChildItem -LiteralPath $Root -Recurse -File -Filter *.md |
            Where-Object { $_.FullName.Substring($Root.Length) -notmatch '[\\/]\.[^\\/]+[\\/]' } |
            Sort-Object FullName
    })

$broken = [System.Collections.Generic.List[string]]::new()
$checked = 0

foreach ($file in $files) {
    $display = $file.FullName.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = [System.IO.File]::ReadAllLines($file.FullName)
    $fence = $null
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if ($line -match '^\s{0,3}(`{3,}|~{3,})') {
            if ($null -eq $fence) { $fence = $matches[1] }
            elseif ($line -match "^\s{0,3}$([regex]::Escape($fence[0])){$($fence.Length),}\s*$") { $fence = $null }
            continue
        }
        if ($fence) { continue }

        # Inline code spans hold examples, not links that have to resolve.
        $scrubbed = $line -replace '`[^`]*`', ''
        $lineNumber = $index + 1
        $targets = @([regex]::Matches($scrubbed, $inlineLinkPattern) | ForEach-Object { $_.Groups[1].Value })
        if ($scrubbed -match $referenceDefinitionPattern) { $targets += $matches[1] }

        foreach ($target in $targets) {
            $checked++
            $issue = Get-LinkTargetIssue -Target $target -SourceFile $file -Display $display -LineNumber $lineNumber
            if ($issue) { $broken.Add($issue) }
        }
    }
}

$summary = "$checked link(s) checked in $($files.Count) file(s)."
if ($files.Count -eq 0) {
    Write-Output "No markdown files were found under $Root - nothing was validated."
    Write-Output 'A check that checked nothing is a failure, not a pass.'
    exit 1
}
if ($broken.Count -eq 0) {
    Write-Output "$summary Every one of them resolves."
    exit 0
}
Write-Output "$summary $($broken.Count) do not resolve:"
$broken | Sort-Object | ForEach-Object { Write-Output "  - $_" }
exit 1
