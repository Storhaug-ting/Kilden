@{
    # ---------------------------------------------------------------------
    # Opphav – hvor innholdet kommer fra
    # ---------------------------------------------------------------------
    Opphav   = @{
        Tittel     = 'Veileder for bruksordning for veg'
        Utgiver    = 'Domstoladministrasjonen'
        Ansvarlig  = 'Arbeidsgruppe for «Bruksordning for veg»'
        Dato       = '21.08.2019'
        Endringer  = 'Januar 2022 (§ 5-2) og februar 2024 (§ 17 / § 13)'
        Landingsside = 'https://www.domstol.no/no/jordskifterettene/'
        Url        = 'https://www.domstol.no/globalassets/da/veiledere-og-rapporter/jordskifte/veileder---bruksordning-for-veg.pdf'
        Original   = 'veileder---bruksordning-for-veg.pdf'
        Markdown   = 'veileder-bruksordning-for-veg.md'
        Sha256     = '1E4BF103744D2EF7CDBD04274B8720AB032DCB6266530E1AABFF0D026494D2F4'
        Bytes      = 900530
        Sider      = 61
        Hentet     = '2026-08-02'
        Bruk       = 'Offentlig veileder fra Domstoladministrasjonen. Lagret lokalt for referanse og sporbarhet i jordskiftesaken.'
    }

    # ---------------------------------------------------------------------
    # Konverteringsregler – hvordan PDF-en gjøres om til markdown
    # ---------------------------------------------------------------------
    # Nøklene sendes videre til scripts/Convert-PdfToMarkdown.py.
    # `Font` og `Pattern` er regulære uttrykk; `Size` er skriftstørrelsen i
    # punkt. Se skriptets DEFAULT_PROFILE for hva hver nøkkel betyr.
    Profil   = @{
        skip_line_patterns = @(
            'Bruksordning for veg \| side \d+ av \d+'
            'Innhold'
        )
        headings           = @(
            @{ level = 1; font = 'TimesNewRomanPS-BoldMT'; size = 25.0 }
            @{ level = 2; font = 'TimesNewRomanPS(MT|-BoldMT)'; size = 14.0; pattern = '^\d+\.\s' }
            @{ level = 2; font = 'TimesNewRomanPS-BoldMT'; size = 12.0; pattern = '^Innledning$' }
            @{ level = 3; font = 'TimesNewRomanPS(MT|-BoldMT)'; size = 12.0; pattern = '^\d+\.\d+\s'; max_chars = 90 }
            @{ level = 4; font = 'TimesNewRomanPS(MT|-BoldMT)'; size = 12.0; pattern = '^\d+\.\d+\.\d+\s'; max_chars = 90 }
            @{ level = 3; font = 'TimesNewRomanPS-BoldMT'; size = 12.0; pattern = '^Vedlegg \d+' }
            @{ level = 5; font = 'TimesNewRomanPS-Bold(Italic)?MT'; size = 12.0; pattern = '^§ ?\d+\.\d+' }
            @{ level = 4; font = 'TimesNewRomanPS-Bold(Italic)?MT'; size = 12.0; pattern = '^§ ?\d+' }
            @{ level = 4; font = 'TimesNewRomanPS-BoldMT'; size = 22.0 }
            @{ level = 4; font = 'Cambria'; size = 12.0; skip_on_figure_page = $true }
            @{ level = 4; font = 'TimesNewRomanPS-BoldMT'; size = 12.0; require_all_bold = $true; not_pattern = '^(\[|.*:$)'; min_chars = 8; max_chars = 85 }
            @{ level = 4; font = 'TimesNewRomanPSMT'; size = 11.0; max_x0 = 90.0; max_chars = 60; body_size_delta_min = 0.7 }
        )
        paragraph_gap             = 16.5
        line_tolerance            = 2.5
        space_ratio               = 0.12
        bullet_indents            = @(106.3, 124.3, 89.0)
        bullet_indent_tolerance   = 4.0
        superscript_delta         = 3.0
        footnote_delta            = 1.5
        footnote_zone             = 0.62
        page_break_full_line_x1   = 470.0
        heading_wrap_x1           = 400.0
        figure_pages              = @(19)
        table_min_rows            = 2
        table_min_cols            = 2
    }

    # Minste andel av ordene i PDF-en som må finnes igjen i markdown-filen.
    MinsteDekning = 1.0
}
