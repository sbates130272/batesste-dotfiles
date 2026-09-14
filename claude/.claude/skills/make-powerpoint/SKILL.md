---
name: make-powerpoint
description: >-
  Build a real .pptx conference or design-review deck from a repository, using a
  generated-from-source pipeline (outline.yaml -> python-pptx) with hand-authored
  SVG diagrams and charts driven by measured data. Handles corporate/conference
  templates, speaker notes, and a PowerPoint-comment review loop. Use when the
  user asks for slides, a deck, a talk, or a presentation about code in the
  current repo.
---

# make-powerpoint

Build a presentation about the current repository as a **generated artifact**, not a
hand-edited binary. Everything on a slide traces back to a text file under version
control, so a re-measure or a reword is a rebuild, not an afternoon in PowerPoint.

## Core principle

The `.pptx` is **build output**. Never edit it directly, never treat it as the source
of truth, and always add it to `.gitignore`. Content lives in `outline.yaml`; layout
and styling live in `build.py`; diagrams live in `svgen.py`; chart data lives in
`data/*.csv`. One command rebuilds the whole deck from those.

This matters more than it sounds. Decks about software rot the moment the software
changes. When the deck is generated, a stale number is a failing check rather than an
embarrassment on stage.

## Speaker identity

Default byline for the user, unless they say otherwise for a given deck:

| Field | Value |
| --- | --- |
| Name | Stephen Bates, PhD |
| Title | Fellow, AI Storage Architecture and Software |
| Affiliation | AMD |
| Email | `stephen.bates@amd.com` |

The post-nominal **PhD** goes after the name on title slides. Elsewhere — footers,
closing slides, running text — plain "Stephen Bates" is right; repeating it reads as
padding.

> AMD is the correct affiliation for work decks. Note that the user's git identity in
> some repos is `sbates@raithlin.com` (Raithlin Consulting, his consultancy); ask if the
> venue or repo suggests that byline instead.

Put name / title / affiliation in `meta:` in `outline.yaml` so the title slide and any
footer read from one place. Do not put the email on the title slide unless asked —
it belongs on the closing slide with the repo URL.

## Sidecar directory

Decks do **not** go in the source repo. They carry a venv, large PNGs, screenshots and
a multi-MB binary, and their review cycle has nothing to do with the code's. Create a
sibling directory:

```text
~/Projects/<repo-name>-<venue-slug>/
```

e.g. `~/Projects/rocm-ernic-sdc-2026/` alongside `~/Projects/rocm-ernic/`. Confirm the
location with the user before creating it. Layout:

```text
<repo>-<venue>/
  outline.yaml          # single source of truth: slides, bullets, speaker notes
  build.py              # outline.yaml + assets -> .pptx  (python-pptx)
  svgen.py              # hand-authored SVG diagrams
  charts.py             # data/*.csv -> SVG charts      (matplotlib)
  make.sh               # svgen -> charts -> rsvg-convert -> build.py
  assets/
    _style.py           # ONE palette + type scale, imported by svgen and charts
    *.svg               # diagrams and charts (source)
    *.png               # 3200px renders for embedding (gitignored)
  data/
    *.csv               # measured numbers, copied out of test/CI output
    RESULTS.md          # provenance: host, git SHA, config, date, command per CSV
  screenshots/          # terminal captures, dashboards, UI
  template/             # conference/corporate template .pptx (read-only, if any)
  reference/            # prior decks to mine (read, never copied wholesale)
  review/               # user's commented .pptx comes back here
  .venv/                # python-pptx, matplotlib
  .gitignore            # .venv/ *.pptx assets/*.png __pycache__/
  <name>.pptx           # generated
```

Setup:

```bash
python3 -m venv .venv && .venv/bin/pip install python-pptx matplotlib
# rsvg-convert comes from librsvg2-bin; check before relying on it
```

## outline.yaml

One document, a `meta:` block and a `slides:` list. Each slide names a layout
archetype and carries its content plus **speaker notes**:

```yaml
meta:
  title: "..."
  subtitle: "..."
  author: "Stephen Bates"
  affiliation: "AMD"
  event: "..."
  target_minutes: 45

slides:
  - layout: bullets
    title: "Agenda"
    bullets:
      - "top level"
      - level: 2
        text: "nested"
    notes: |
      The spoken script. Not an echo of the bullets.
```

Keep the archetype set small — roughly:

| layout | use |
| --- | --- |
| `title` | opening slide |
| `section` | divider between sections |
| `bullets` | title + (nested) bullet list |
| `image` | title + full-width graphic + caption |
| `split` | bullets left, graphic right |
| `code` | monospace block |
| `stat` | up to 4 big numbers with captions |

More archetypes than that and the deck stops looking designed. `build.py` should
`assert` every slide has non-empty notes and fail the build otherwise — notes are the
script, and a deck without them cannot be rehearsed or handed to a co-presenter.

## Template handling

This is the part that goes wrong most often. Conferences and employers hand out a
`.pptx` template; the instinct is to redraw its look, which produces something that
*resembles* the brand and matches nothing. Don't.

**Build template-neutral first if no template is in hand.** Explicit geometry, neutral
palette, SVG diagrams. Restyling later is then a contained change to `build.py` plus
`assets/_style.py`, not a rewrite.

**When a template arrives**, put it in `template/` and treat it as read-only input.
Then:

1. **Inspect it before using it.** Enumerate slide layouts by name, the theme's color
   and font schemes, the master's `titleStyle`/`bodyStyle` sizes, and the slide
   dimensions. Layout names vary wildly between templates (`Title and Content`,
   `Title Only`, `Divider Slide`, …), so never hardcode without checking:

   ```python
   prs = Presentation("template/X.pptx")
   print(prs.slide_width, prs.slide_height)
   for i, l in enumerate(prs.slide_layouts):
       print(i, l.name, [(p.placeholder_format.idx, p.placeholder_format.type, p.name)
                         for p in l.placeholders])
   ```

2. **Load the template as the Presentation**, rather than starting from
   `Presentation()` and imitating it. That inherits the master, theme, fonts, footer,
   slide numbers and logo for free.

3. **Drop the template's example slides.** Templates ship placeholder slides; remove
   them all before adding yours:

   ```python
   R = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
   for sld in list(prs.slides._sldIdLst):
       prs.part.drop_rel(sld.get(R))
       prs.slides._sldIdLst.remove(sld)
   ```

4. **Use the template's real placeholders** for title and body wherever possible, so
   bullet glyphs, indents and fonts come from the master. Only set paragraph `level`;
   let the master supply the rest.

5. **For custom layouts** (images, split, code, stat), use a `Title Only` layout and
   place shapes with explicit geometry — but take the geometry **from the master's
   body placeholder** so custom slides align with placeholder-based ones:

   ```python
   body = next(p for p in layout.placeholders if p.placeholder_format.idx == 1)
   CONTENT_X, CONTENT_Y, CONTENT_W, CONTENT_H = body.left, body.top, body.width, body.height
   ```

6. **Delete placeholders you did not fill**, or "Click to edit Master text" prompt text
   renders on the exported slide:

   ```python
   for ph in list(slide.placeholders):
       if not ph.has_text_frame or not ph.text_frame.text.strip():
           ph._element.getparent().remove(ph._element)
   ```

7. **Drop your own chrome.** If the master already draws a footer, slide number or
   logo, remove the deck's custom versions — two footers is the classic tell.

8. **Sample the template's palette into `assets/_style.py`** so diagrams and charts
   land in-theme. Pull accent colors from the theme part, and brand colors from the
   logo image if the theme is thin.

**Deviating from a template.** Sometimes you must — templates are designed for sparse
slides and light rooms. Two legitimate reasons:

- *Contrast.* Check every text color against its background. The floor is **3:1 for
  large text, 4.5:1 for body** (WCAG AA); projected in a lit room, treat 3:1 as hard.
  Templates routinely style content titles in a pale accent that measures ~2:1.
- *Density.* Masters often set a 28 pt first bullet level, which overflows any slide
  with real content. Step sizes down by slide weight.

Both deviations must be **explicit, commented, and revertible** — a module-level flag
like `RECOLOUR_TITLES = True` with a comment stating the measured contrast ratio and
how to take the template exactly as shipped. Then tell the user what you changed and
why. Never silently override a brand.

Title and divider slides usually should **not** get these overrides: they're sparse and
often reversed-out, so the template's own styling is correct there.

## Diagrams and charts

**Diagrams**: hand-author SVG from a Python generator (`svgen.py`), not by hand-writing
XML and not with a diagramming tool. One shared vocabulary in `assets/_style.py` —
palette, type scale, box geometry — keeps fifteen diagrams looking like one set.
Native canvas ~1600x900; render to PNG at 3200px wide with `rsvg-convert` for
embedding.

Minimum legibility: after scaling into its slide box, no diagram label may be under
about **14 pt effective**. Compute this, don't eyeball it:
`render_width / native_width * font_size`, against the box the image occupies.

**Charts**: generated by `charts.py` from `data/*.csv` only. Never hand-type a number
into a chart or a bullet. If a CSV is missing, skip the chart with a warning rather than
fabricating the series. Transparent background (`facecolor: "none"`) so charts sit on
the template's slide background.

Pick series colors that survive color blindness — two brand oranges will not. If the
brand palette can't supply three distinguishable series, borrow a third and say so in a
comment.

## Data provenance

If the deck makes performance or scale claims, every number gets a CSV in `data/` and
every CSV gets an entry in `data/RESULTS.md` recording host, git SHA, branch, build
config, date, and the exact command. Before the deck ships, walk every numeric claim on
every slide back to a file. This routinely catches a claim that drifted from its data —
the check is not ceremony.

State honestly what the numbers are and are not (emulated vs hardware, which code path,
which device mode). Never plot two different configurations on one axis.

## Verification

No renderer is usually available on a dev host, so verify structurally and numerically:

- **Overflow**: for every text shape, estimate rendered height (line count x font size x
  ~1.2 leading, plus wrapping at the shape width) and compare against shape height.
  Report any shape that exceeds it. This is the single highest-value check.
- **Prompt text**: assert no slide contains "Click to edit".
- **Notes**: assert every slide has them.
- **Layout distribution**: print the count per layout name; an unexpected layout means a
  slide fell through to a default.
- **Diagram legibility**: the effective-point-size computation above.
- **Spellcheck** the outline against the repo's `.wordlist.txt` if it has one.
  `aspell` needs a `personal_ws-1.1 en N` header on the wordlist and rejects
  non-alphabetic entries — **do not discard its stderr**, or a tool error reads as a
  clean pass.
- **Pacing**: slides x ~75 s against `target_minutes`; report the gap.

Then tell the user plainly that it has not been checked visually, and to open it.

## Review loop: PowerPoint comments

The user reviews in PowerPoint and returns a commented copy. Ask them to save it to
`review/` under a different filename — `make.sh` overwrites the build output.

Comments are readable straight from the OPC package without any library:

```bash
unzip -o review/deck-reviewed.pptx -d /tmp/rev
ls /tmp/rev/ppt/comments/        # modernComment_*.xml (365) or comment*.xml (legacy)
cat /tmp/rev/ppt/authors.xml     # or ppt/commentAuthors.xml for legacy
```

Each comment carries its slide (and often its anchor shape), so map comment -> slide
number -> the corresponding entry in `outline.yaml`. Comments on speaker notes live in
the notes-slide part and count too.

**Act on comments by editing `outline.yaml` or `build.py`, then rebuilding.** Direct
edits the user made to slide text live only in their copy and are destroyed by the next
build — tell them this up front, and ask for changes as comments. If they've edited
text anyway, diff the slide text against the outline to recover the edits before
rebuilding.

## Mining a prior deck

Prior decks go in `reference/`: read, not copied. Unzip and read slide XML and notes
directly — no dependency needed — then use python-pptx to extract embedded images worth
reusing. Use it to recover material that exists nowhere in the source tree (motivation,
customer framing, roadmap dates) and to catch missing topics.

Check anything reused against the current tree: a slide written for a deprecated code
path must not silently carry into a deck arguing for the new one. **Flag anything
internal or confidential** if the venue is public.

## Working style

- Confirm scope early with the user: venue, duration, audience, and whether the deck
  lives outside the repo. Don't guess on duration — it sets the slide budget.
- Propose cuts when over time; **do not apply them unilaterally.** What to drop from a
  talk is the speaker's call.
- Leave explicit placeholder slides for content only the user can supply, and list them
  as open items rather than inventing content.
- Report what was verified and what was not. "Builds clean" is not "looks right".
