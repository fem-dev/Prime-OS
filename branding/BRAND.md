# Prime-OS visual identity — the Persepolis system

Prime-OS should feel like the **Achaemenid court at Persepolis**: monumental, ordered,
quietly wealthy. Stone, glazed brick, lapis and gold. Nothing that reads as a modern
state, a religion, or a political movement.

This is a *design* language. Every user-facing string stays in **English**;
ancient motifs are drawn, not written. No Persian script, no Arabic script, no
religious iconography, no flags of present-day states, no portraits of rulers.

## 1. The marks

| Motif | Where it is used | How to draw it |
| --- | --- | --- |
| **Winged Faravahar** | Project mark, wizard artwork, ISO splash | Already in `faravahar.png`; keep the outline visible at 0 % and fill with gold as work progresses |
| **Apādana columns** | README hero, wallpapers, section dividers | Fluted shafts with a double-bull capital, drawn flat: two mirrored volutes over a square abacus |
| **Tribute frieze** | Thin rules under headers, Waybar baseline | A row of equal-height rectangles with a 1 px gold top edge, 2 px gaps |
| **Lotus rosette** | Bullets, loading states | Twelve petals around a centre dot, single colour |
| **Persepolis stair profile** | Corner ornaments | Three stepped lines rising to the right, never more than three |

Geometry rules: verticals are true, circles are perfect, joints are square. If a
decoration cannot be drawn with lines and arcs, it does not belong here.

## 2. Palette (`branding/palette.json`)

| Token | Hex | Meaning |
| --- | --- | --- |
| Basalt | `#0B1020` | Window and terminal background |
| Lapis | `#14213D` | Panels, cards |
| Lapis panel | `#1B2A4A` | Raised surfaces, selected rows |
| Lapis lift | `#24406B` | Idle borders, dividers |
| Gold | `#D4A537` | Active borders, marks, headings |
| Gold bright | `#F0C75E` | Focus ring, the revealed part of a mark |
| Gold deep | `#8C6B1F` | Gold on ivory, pressed states |
| Terracotta | `#A6472F` | Errors, destructive actions |
| Ivory | `#EFE6D2` | Body text |
| Verdigris | `#3E7C6A` | Success, "verified" |

Colour is used like glazed brick: large calm fields of lapis and basalt, small
precise inserts of gold. Never a gradient, never a neon accent, never more than
one gold focus per screen.

## 3. Typography

- UI and body: **Noto Sans** (already in the image at `fonts`/`fonts-cjk`).
- Mono: **Noto Sans Mono** in terminals.
- Headings: same face, weight 600, `letter-spacing: 0.02em`, small caps only for
  the product name `PRIME-OS`.
- No display or calligraphic fonts: the identity is carried by proportion, not
  ornament.

## 4. Voice

Sober, factual, second person. State what a thing does and what it does not do.

| Say | Do not say |
| --- | --- |
| "This saves a preference profile; it does not install an OS." | "Experience the glory of the empire." |
| "Verified against the published SHA-256." | "100 % secure." |
| "Preview release." | "The ultimate gaming OS." |

Historical references are allowed in **names**, not in claims: a release can be
called `apadana`, a theme `frieze`, a component `gate`. Never promise that
software is ancient, royal, imperial, or divinely favoured.

## 5. Naming

- Product: `Prime-OS` (always with the hyphen).
- Live image: `Prime-OS Live`.
- Release tags: `os-preview`, then `apadana`, `tachar`, `hadish` for later
  milestones — lower case, one word.
- ISO label: `PRIME_OS`, application string `Prime-OS Live`.

## 6. Where the identity is applied

| File | What it carries |
| --- | --- |
| `branding/palette.json` | The tokens above, machine readable |
| `branding/hero.svg` | README banner: colonnade and winged disc |
| `profile/airootfs/usr/share/backgrounds/prime-os.png` | Live-session wallpaper |
| `profile/airootfs/etc/skel/.config/waybar/style.css` | Bar colours |
| `profile/airootfs/etc/prime-os/hyprland.conf` | Border and shadow colours |
| `profile/airootfs/etc/issue`, `etc/motd` | Text console banner |
| `loader.py` | Wizard window: basalt background, gold focus, Faravahar progress |

## 7. Things this identity is not

- Not a religion: the Faravahar is used as an ancient cultural mark, not a creed.
- Not a state: no flag, no anthem, no current-country symbolism, no leader imagery.
- Not a language: nothing is written in Persian or Arabic script; a Persian
  speaker gets the same English interface as everyone else.
- Not a costume: no fake cuneiform, no "ancient" textures, no parchment.

If a proposed change cannot be justified from this file, it is decoration, and
decoration is the first thing to cut.
