#!/usr/bin/env python3
"""Deterministisk konvertering av en tekstbasert PDF til markdown.

Skriptet lager en *reverse engineered kilde*: en markdown-fil som kan leses og
diffes for å spore endringer i en original som ligger på nett. Konverteringen
er derfor **deterministisk** - samme PDF gir alltid nøyaktig samme markdown.

Metode
------
Teksten bygges opp fra tegnnivå (``page.chars``), ikke fra ``extract_text()``.
Det gir tre ting vi trenger:

* **Riktige ordgrenser.** Mellomrom settes inn ut fra faktisk avstand mellom
  tegn. Uten dette blir kapitéler (small caps) splittet i to «ord», f.eks.
  ``2. S AKSBEHANDLING``.
* **Original bokstavstørrelse.** Word tegner kapitéler med stor skriftstørrelse
  på tegn som opprinnelig var STORE, og en mindre størrelse på tegn som
  opprinnelig var små. Tegnstørrelsen lar oss dermed rekonstruere den
  opprinnelige skrivemåten («Noen aktuelle tema ved bruksordning for veg») i
  stedet for å gjette på en tittelform.
* **Utheving.** Fet og kursiv utledes av fontnavnet per tegn.

Overskriftsnivå, punktlister, fotnoter, tabeller og figurer utledes av font,
skriftstørrelse, x-posisjon og vektorgrafikk. Alle terskler ligger i en
JSON-profil (``--profile``) slik at hver kilde kan ha sine egne regler uten at
koden endres.

Krav: Python 3.9+ og ``pdfplumber`` (``python -m pip install pdfplumber``).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

try:
    import pdfplumber
except ImportError:  # pragma: no cover - miljøfeil, ikke logikkfeil
    sys.exit("pdfplumber mangler. Installer med:\n    python -m pip install pdfplumber")


# --------------------------------------------------------------------------
# Standardprofil
# --------------------------------------------------------------------------

DEFAULT_PROFILE: dict = {
    # Regex mot linjer som er topp-/bunntekst og skal fjernes.
    "skip_line_patterns": [],
    # Regex mot linjer i innholdsfortegnelsen (punktledere). Fjernes fordi vi
    # genererer en ny innholdsfortegnelse med fungerende ankere.
    "toc_line_pattern": r".*\.{5,}\s*\d+\s*$",
    # Overskriftsregler. Første treff vinner. `font` og `pattern` er regex.
    "headings": [],
    # Loddrett avstand (topp til topp) som markerer nytt avsnitt.
    "paragraph_gap": 16.5,
    # Toleranse for å samle tegn i samme linje.
    "line_tolerance": 2.5,
    # Avstand mellom to tegn, målt som andel av skriftstørrelsen, som skal
    # tolkes som mellomrom. Avstandene i en PDF er tydelig todelte: innenfor
    # et ord ligger de under 0,04, og et mellomrom ligger over 0,20. Terskelen
    # legges midt i tomrommet mellom de to gruppene.
    "space_ratio": 0.12,
    # x0 for punkter i punktlister (± toleranse).
    "bullet_indents": [],
    "bullet_indent_tolerance": 4.0,
    # Et tegn regnes som opphøyd fotnotehenvisning når det er så mange punkter
    # mindre enn linjens største skriftstørrelse.
    "superscript_delta": 3.0,
    # Linjer nederst på siden som er mindre enn brødteksten er fotnoter.
    "footnote_delta": 1.5,
    "footnote_zone": 0.62,
    # En linje som slutter kortere enn dette regnes som avsnittsslutt ved
    # sideskift.
    "page_break_full_line_x1": 470.0,
    # En overskriftslinje som slutter etter dette punktet er ombrukket, og
    # neste linje er fortsettelsen av samme overskrift.
    "heading_wrap_x1": 430.0,
    # Sider som skal gjengis som figur (flytskjema o.l.).
    "figure_pages": [],
    # Minste antall rader/kolonner for at en funnet tabell skal tas med.
    "table_min_rows": 2,
    "table_min_cols": 2,
}


# --------------------------------------------------------------------------
# Datamodell
# --------------------------------------------------------------------------


@dataclass
class Line:
    """En visuell tekstlinje på en side."""

    page: int
    top: float
    bottom: float
    x0: float
    x1: float
    text: str
    runs: list = field(default_factory=list)
    max_size: float = 0.0
    dominant_font: str = ""
    small_caps: bool = False
    all_bold: bool = False
    kind: str = "body"
    level: int = 0


@dataclass
class Block:
    """En markdown-blokk klar for utskrift."""

    kind: str
    text: str = ""
    level: int = 0
    rows: list = field(default_factory=list)
    items: list = field(default_factory=list)


# --------------------------------------------------------------------------
# Tegn -> linjer
# --------------------------------------------------------------------------


def _style_of(fontname: str) -> str:
    name = fontname.split("+")[-1].lower()
    bold = "bold" in name or "black" in name or "heavy" in name
    italic = "italic" in name or "oblique" in name
    if bold and italic:
        return "bolditalic"
    if bold:
        return "bold"
    if italic:
        return "italic"
    return "regular"


def _absorb_spaces(pieces):
    """Lar mellomrom arve stilen til nabotegnene.

    Uten dette blir «*ord* *ord*» av en kursiv setning, fordi mellomrommene
    settes inn som nøytrale segmenter mellom to kursive segmenter.
    """
    result = list(pieces)
    for index, (style, text) in enumerate(result):
        if style != "regular" or text.strip():
            continue
        before = result[index - 1][0] if index > 0 else None
        after = result[index + 1][0] if index + 1 < len(result) else None
        if before is not None and before == after and before != "regular":
            result[index] = (before, text)
    return result


def _merge_runs(runs):
    merged = []
    for style, text in runs:
        if merged and merged[-1][0] == style:
            merged[-1] = (style, merged[-1][1] + text)
        else:
            merged.append((style, text))
    return merged


def build_lines(page, page_number: int, profile: dict):
    """Grupperer tegnene på en side til linjer med stil-informasjon."""
    chars = [c for c in page.chars if (c.get("text") or "").strip()]
    if not chars:
        return []

    tolerance = profile["line_tolerance"]
    chars.sort(key=lambda c: (round(c["top"], 1), c["x0"]))

    rows = []
    for char in chars:
        if rows and abs(char["top"] - rows[-1][0]["top"]) <= tolerance:
            rows[-1].append(char)
        else:
            rows.append([char])

    lines = []
    for row in rows:
        row.sort(key=lambda c: c["x0"])
        max_size = max(c["size"] for c in row)
        sup_cutoff = max_size - profile["superscript_delta"]

        pieces = []
        previous = None
        small_caps = False
        for char in row:
            text = char["text"]
            if previous is not None:
                gap = char["x0"] - previous["x1"]
                if gap > profile["space_ratio"] * max(previous["size"], char["size"]):
                    pieces.append(("regular", " "))
            if char["size"] <= sup_cutoff and text.isdigit():
                pieces.append(("sup", text))
            else:
                # Kapitéler: tegn tegnet mindre enn linjens maksimum var
                # opprinnelig små bokstaver.
                if char["size"] < max_size - 0.6 and text.isupper():
                    text = text.lower()
                    small_caps = True
                pieces.append((_style_of(char["fontname"]), text))
            previous = char

        runs = _merge_runs(_absorb_spaces(pieces))
        text = "".join(t for _, t in runs).strip()
        if not text:
            continue

        fonts = {}
        for char in row:
            fonts[char["fontname"]] = fonts.get(char["fontname"], 0) + 1

        lines.append(
            Line(
                page=page_number,
                top=min(c["top"] for c in row),
                bottom=max(c["bottom"] for c in row),
                x0=min(c["x0"] for c in row),
                x1=max(c["x1"] for c in row),
                text=text,
                runs=runs,
                max_size=max_size,
                small_caps=small_caps,
                all_bold=all(
                    style in ("bold", "bolditalic") or not text.strip()
                    for style, text in runs
                ),
                dominant_font=max(fonts.items(), key=lambda kv: (kv[1], kv[0]))[0],
            )
        )

    lines.sort(key=lambda ln: (round(ln.top, 1), ln.x0))
    return lines


# --------------------------------------------------------------------------
# Tekstbehandling
# --------------------------------------------------------------------------

CHAR_REPLACEMENTS = {
    "\u00a0": " ",
    "\ufb00": "ff",
    "\ufb01": "fi",
    "\ufb02": "fl",
    "\ufb03": "ffi",
    "\ufb04": "ffl",
    "\u2212": "-",
}


def normalise(text: str) -> str:
    text = unicodedata.normalize("NFC", text)
    for src, dst in CHAR_REPLACEMENTS.items():
        text = text.replace(src, dst)
    text = re.sub(r"[ \t]{2,}", " ", text)
    return text.strip()


def runs_to_markdown(runs, emphasis: bool = True) -> str:
    """Gjør stil-segmenter om til markdown med *, ** og fotnotehenvisninger."""
    out = []
    for style, text in runs:
        if not text:
            continue
        if style == "sup":
            out.append(f"[^{text}]")
            continue
        if style == "regular" or not emphasis or not text.strip():
            out.append(text)
            continue
        lead = text[: len(text) - len(text.lstrip())]
        trail = text[len(text.rstrip()) :]
        marker = {"bold": "**", "italic": "*", "bolditalic": "***"}[style]
        out.append(f"{lead}{marker}{text.strip()}{marker}{trail}")
    joined = "".join(out)
    # Mellomrommet foran en opphøyd henvisning er en artefakt fra ombrekkingen.
    return re.sub(r"\s+(\[\^\d+\])", r"\1", joined)


def merge_emphasis(text: str) -> str:
    """Slår sammen uthevinger som ble delt av en linjeombrekking.

    En kursiv setning som går over to linjer blir til «... av* *vedtektene ...»
    når linjene skjøtes. Mønstrene krever mellomrom mellom markørene, slik at
    ekte `**fet**` ikke røres.
    """
    for marker in ("***", "**", "*"):
        escaped = re.escape(marker)
        text = re.sub(
            rf"(?<!\*){escaped}(\s+){escaped}(?!\*)",
            r"\1",
            text,
        )
    return text


def slugify(text: str) -> str:
    """Ankerslug på samme form som GitHub genererer."""
    text = unicodedata.normalize("NFC", text).strip().lower()
    text = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE)
    text = re.sub(r"\s+", "-", text.strip())
    return re.sub(r"-{2,}", "-", text).strip("-")


def words_of(text: str):
    """Ordstrøm brukt til å måle at all tekst i PDF-en kom med i markdown."""
    text = normalise(text)
    text = re.sub(r"[*_`>#|\\]", "", text)
    text = re.sub(r"\[\^\d+\]:?", " ", text)
    return re.findall(r"\w+", text, flags=re.UNICODE)


def coverage(expected, produced):
    """Andelen av PDF-ens ord som finnes igjen i markdown, og det som mangler."""
    from collections import Counter

    missing = Counter(expected) - Counter(produced)
    total = len(expected)
    lost = sum(missing.values())
    ratio = 1.0 if total == 0 else (total - lost) / total
    return ratio, missing


# --------------------------------------------------------------------------
# Klassifisering
# --------------------------------------------------------------------------


def classify(
    line: Line,
    profile: dict,
    body_size: float,
    page_height: float,
    is_figure_page: bool,
) -> None:
    font = line.dominant_font.split("+")[-1]

    for pattern in profile["skip_line_patterns"]:
        if re.fullmatch(pattern, line.text):
            line.kind = "skip"
            return

    if re.fullmatch(profile["toc_line_pattern"], line.text):
        line.kind = "skip"
        return

    for rule in profile["headings"]:
        if rule.get("skip_on_figure_page") and is_figure_page:
            continue
        if not re.fullmatch(rule["font"], font):
            continue
        if abs(line.max_size - rule["size"]) > 0.3:
            continue
        if rule.get("pattern") and not re.match(rule["pattern"], line.text):
            continue
        if rule.get("not_pattern") and re.match(rule["not_pattern"], line.text):
            continue
        if rule.get("require_small_caps") and not line.small_caps:
            continue
        if rule.get("require_all_bold") and not line.all_bold:
            continue
        if rule.get("min_x0") is not None and line.x0 < rule["min_x0"]:
            continue
        if rule.get("max_x0") is not None and line.x0 > rule["max_x0"]:
            continue
        if rule.get("max_chars") is not None and len(line.text) > rule["max_chars"]:
            continue
        if rule.get("min_chars") is not None and len(line.text) < rule["min_chars"]:
            continue
        # Enkelte overskrifter skiller seg fra brødteksten bare ved å være
        # mindre enn den. Da må regelen måles mot sidens brødtekststørrelse.
        if rule.get("body_size_delta_min") is not None:
            if body_size - line.max_size < rule["body_size_delta_min"]:
                continue
        line.kind = "heading"
        line.level = rule["level"]
        return

    if (
        line.top >= profile["footnote_zone"] * page_height
        and (
            line.max_size <= body_size - profile["footnote_delta"]
            # Fotnoteteksten kan ha samme størrelse som brødteksten, f.eks.
            # når den bare er en lenke. Da er det det opphøyde nummeret
            # først på linja som avslører den.
            or (line.runs and line.runs[0][0] == "sup")
        )
    ):
        line.kind = "footnote"
        return

    for indent in profile["bullet_indents"]:
        if abs(line.x0 - indent) <= profile["bullet_indent_tolerance"] and re.match(
            r"^[-\u2212\u2013\u2022]\s*\S", line.text
        ):
            line.kind = "bullet"
            return

    line.kind = "body"


# --------------------------------------------------------------------------
# Tabeller og figurer
# --------------------------------------------------------------------------


def usable_tables(page, profile: dict):
    """Finner tabeller som er verdt å gjengi som markdown-tabell."""
    found = []
    for table in page.find_tables():
        rows = table.extract()
        rows = [
            [normalise(cell.replace("\n", " ")) if cell else "" for cell in row]
            for row in rows
        ]
        rows = [row for row in rows if any(cell for cell in row)]
        if len(rows) < profile["table_min_rows"]:
            continue
        width = max(len(row) for row in rows)
        if width < profile["table_min_cols"]:
            continue
        # Fjern kolonner som er tomme i hele tabellen (sammenslåtte celler).
        keep = [
            index
            for index in range(width)
            if any(index < len(row) and row[index] for row in rows)
        ]
        if len(keep) < profile["table_min_cols"]:
            continue
        rows = [[row[i] if i < len(row) else "" for i in keep] for row in rows]
        found.append((table.bbox, rows))
    return found


def render_table(rows) -> str:
    width = max(len(row) for row in rows)
    rows = [row + [""] * (width - len(row)) for row in rows]
    header, body = rows[0], rows[1:]
    if not any(header):
        header = [f"Kolonne {i + 1}" for i in range(width)]
        body = rows
    out = ["| " + " | ".join(c.replace("|", "\\|") for c in header) + " |"]
    out.append("|" + "|".join(["---"] * width) + "|")
    for row in body:
        out.append("| " + " | ".join(c.replace("|", "\\|") for c in row) + " |")
    return "\n".join(out)


# --------------------------------------------------------------------------
# Dokumentbygging
# --------------------------------------------------------------------------


def extract_blocks(pdf, profile: dict):
    blocks = []
    footnotes = {}
    expected_words = []

    state = {
        "paragraph": [],
        "bullet": [],
        "previous": None,
        "footnote": None,
        "heading_line": None,
        "figure_items": {},
    }

    def flush_paragraph():
        if state["paragraph"]:
            text = normalise(
                merge_emphasis(
                    " ".join(runs_to_markdown(ln.runs) for ln in state["paragraph"])
                )
            )
            if text:
                blocks.append(Block("paragraph", text))
            state["paragraph"] = []

    def flush_bullet():
        if state["bullet"]:
            text = normalise(
                merge_emphasis(
                    " ".join(runs_to_markdown(ln.runs) for ln in state["bullet"])
                )
            )
            text = re.sub(r"^\*?[-\u2212\u2013\u2022]\s*", "", text)
            if text:
                if blocks and blocks[-1].kind == "list":
                    blocks[-1].items.append(text)
                else:
                    blocks.append(Block("list", items=[text]))
            state["bullet"] = []

    def flush_all():
        flush_bullet()
        flush_paragraph()

    for page_number, page in enumerate(pdf.pages, 1):
        tables = usable_tables(page, profile)
        table_boxes = [bbox for bbox, _ in tables]
        emitted_tables = set()

        lines = build_lines(page, page_number, profile)
        candidates = [ln for ln in lines if ln.max_size >= 9.5]
        body_size = 12.0
        if candidates:
            body_size = max(
                {round(ln.max_size, 1) for ln in candidates},
                key=lambda size: sum(
                    1 for ln in candidates if abs(ln.max_size - size) < 0.3
                ),
            )

        is_figure_page = page_number in profile["figure_pages"]
        figure_boxes = []
        if is_figure_page:
            # Minste boks først, slik at en linje havner i den innerste boksen
            # den passer i.
            figure_boxes = sorted(
                page.rects,
                key=lambda r: (r["x1"] - r["x0"]) * (r["bottom"] - r["top"]),
            )
        state["figure_items"] = {}

        for line in lines:
            inside = None
            for index, bbox in enumerate(table_boxes):
                if (
                    line.x0 >= bbox[0] - 2
                    and line.top >= bbox[1] - 2
                    and line.bottom <= bbox[3] + 2
                    and line.x1 <= bbox[2] + 2
                ):
                    inside = index
                    break
            if inside is not None:
                if inside not in emitted_tables:
                    flush_all()
                    state["previous"] = None
                    blocks.append(Block("table", rows=tables[inside][1]))
                    emitted_tables.add(inside)
                expected_words.extend(words_of(runs_to_markdown(line.runs)))
                continue

            classify(line, profile, body_size, page.height, is_figure_page)

            if line.kind != "skip":
                expected_words.extend(words_of(runs_to_markdown(line.runs)))

            # Word bryter lange overskrifter over flere linjer. Fortsettelsen
            # har samme font og størrelse, står rett under, og forrige linje
            # gikk helt ut i høyremargen.
            last = state["heading_line"]
            if (
                last is not None
                and blocks
                and blocks[-1].kind == "heading"
                and line.dominant_font == last.dominant_font
                and abs(line.max_size - last.max_size) <= 0.3
                and line.page == last.page
                and 0 < line.top - last.top <= profile["paragraph_gap"]
                and (
                    last.x1 >= profile["heading_wrap_x1"] or line.text[:1].islower()
                )
            ):
                blocks[-1].text = normalise(
                    blocks[-1].text + " " + runs_to_markdown(line.runs, emphasis=False)
                )
                state["heading_line"] = line
                continue

            if line.kind == "skip":
                continue

            if line.kind == "footnote":
                flush_all()
                state["previous"] = None
                rendered = runs_to_markdown(line.runs)
                match = re.match(r"^\[\^(\d+)\]\s*(.*)$", rendered)
                if match:
                    state["footnote"] = match.group(1)
                    footnotes[match.group(1)] = normalise(match.group(2))
                elif state["footnote"]:
                    key = state["footnote"]
                    footnotes[key] = normalise(footnotes[key] + " " + rendered)
                continue

            if line.kind == "heading":
                flush_all()
                state["previous"] = None
                blocks.append(
                    Block(
                        "heading",
                        # Overskrifter er allerede uthevet; inline fet/kursiv
                        # fra PDF-en ville bare blitt støy i markdown.
                        normalise(runs_to_markdown(line.runs, emphasis=False)),
                        line.level,
                    )
                )
                state["heading_line"] = line
                continue

            state["heading_line"] = None

            if is_figure_page:
                flush_all()
                state["previous"] = None
                if not blocks or blocks[-1].kind != "figure":
                    blocks.append(Block("figure", level=page_number))
                # Tekst i et flytskjema ligger i bokser. Linjer i samme boks
                # hører sammen og skal skjøtes til én etikett.
                box = None
                for index, rect in enumerate(figure_boxes):
                    if (
                        line.x0 >= rect["x0"] - 2
                        and line.x1 <= rect["x1"] + 2
                        and line.top >= rect["top"] - 2
                        and line.bottom <= rect["bottom"] + 2
                    ):
                        box = index
                        break
                if box is not None and box in state["figure_items"]:
                    index = state["figure_items"][box]
                    blocks[-1].items[index] += " " + normalise(line.text)
                else:
                    if box is not None:
                        state["figure_items"][box] = len(blocks[-1].items)
                    blocks[-1].items.append(normalise(line.text))
                continue

            if line.kind == "bullet":
                flush_all()
                state["bullet"] = [line]
                state["previous"] = line
                continue

            previous = state["previous"]
            starts_new = previous is None
            if previous is not None:
                if line.page != previous.page:
                    starts_new = previous.x1 < profile["page_break_full_line_x1"]
                else:
                    starts_new = (line.top - previous.top) > profile["paragraph_gap"]

            if state["bullet"]:
                # Innrykket fortsettelse hører til punktet.
                if line.x0 >= state["bullet"][0].x0 and not starts_new:
                    state["bullet"].append(line)
                    state["previous"] = line
                    continue
                flush_bullet()

            if starts_new:
                flush_paragraph()
            state["paragraph"].append(line)
            state["previous"] = line

        # Fotnoter tilhører siden de står på.
        state["footnote"] = None

    flush_all()
    return blocks, footnotes, expected_words


def build_toc(blocks):
    seen = {}
    lines = []
    for block in blocks:
        if block.kind != "heading" or block.level < 2:
            continue
        text = re.sub(r"[*_`]", "", block.text)
        slug = slugify(text)
        seen[slug] = seen.get(slug, 0) + 1
        if seen[slug] > 1:
            slug = f"{slug}-{seen[slug] - 1}"
        lines.append(f"{'  ' * (block.level - 2)}- [{text}](#{slug})")
    return lines


def render(blocks, footnotes, header) -> str:
    out = list(header)

    toc = build_toc(blocks)
    if toc:
        out.append("## Innhold")
        out.append("")
        out.extend(toc)
        out.append("")

    for block in blocks:
        if block.kind == "heading":
            out.append("#" * max(block.level, 1) + " " + block.text)
            out.append("")
        elif block.kind == "paragraph":
            out.append(block.text)
            out.append("")
        elif block.kind == "list":
            out.extend(f"- {item}" for item in block.items)
            out.append("")
        elif block.kind == "table":
            out.append(render_table(block.rows))
            out.append("")
        elif block.kind == "figure":
            out.append(f"> **Figur (side {block.level} i PDF-en).**")
            out.append("> Elementene i figuren, i leserekkefølge:")
            out.append(">")
            out.extend(f"> - {item}" for item in block.items)
            out.append("")

    text = "\n".join(out)

    if footnotes:
        text = text.rstrip() + "\n\n## Fotnoter\n\n"
        text += "\n".join(f"[^{key}]: {footnotes[key]}" for key in sorted(footnotes, key=int))

    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.rstrip() + "\n"


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Konverterer en tekstbasert PDF til deterministisk markdown."
    )
    parser.add_argument("pdf", type=Path, help="Sti til PDF-en som skal konverteres.")
    parser.add_argument("output", type=Path, help="Sti til markdown-filen som skrives.")
    parser.add_argument(
        "--profile", type=Path, help="JSON-profil med konverteringsregler for kilden."
    )
    parser.add_argument(
        "--header",
        type=Path,
        help="Markdown-fil som limes inn øverst (tittel og kildehenvisning).",
    )
    parser.add_argument(
        "--min-coverage",
        type=float,
        default=0.0,
        help=(
            "Minste andel av ordene i PDF-en som må finnes igjen i markdown. "
            "Skriptet avslutter med feil hvis andelen er lavere."
        ),
    )
    args = parser.parse_args(argv)

    profile = dict(DEFAULT_PROFILE)
    if args.profile:
        profile.update(json.loads(args.profile.read_text(encoding="utf-8")))

    header = []
    if args.header:
        header = args.header.read_text(encoding="utf-8").rstrip().split("\n") + [""]

    with pdfplumber.open(args.pdf) as pdf:
        blocks, footnotes, expected = extract_blocks(pdf, profile)

    markdown = render(blocks, footnotes, header)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(markdown, encoding="utf-8", newline="\n")

    ratio, missing = coverage(expected, words_of(markdown))
    print(
        f"Skrev {args.output} ("
        f"{sum(1 for b in blocks if b.kind == 'heading')} overskrifter, "
        f"{sum(1 for b in blocks if b.kind == 'paragraph')} avsnitt, "
        f"{sum(1 for b in blocks if b.kind == 'list')} lister, "
        f"{sum(1 for b in blocks if b.kind == 'table')} tabeller, "
        f"{len(footnotes)} fotnoter)"
    )
    print(f"Tekstdekning mot PDF: {ratio:.4%}")
    if ratio < args.min_coverage:
        for word, count in missing.most_common(20):
            print(f"  mangler {count}x {word!r}", file=sys.stderr)
        print(
            f"Tekstdekningen {ratio:.4%} er lavere enn kravet {args.min_coverage:.4%}.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
