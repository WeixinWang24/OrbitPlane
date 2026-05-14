# OrbitPlane Design System

> **Mission control for AI agents.**
> The control plane where you watch your fleet of agents work, intervene in real time, replay sessions, and ship interventions back.

---

## 1. About OrbitPlane

OrbitPlane is the **operational substrate** for teams running squads of AI agents. It is *not* an agent framework — it is the room you stand in to watch them. Every agent shows up as a live tile on the deck, with its current task, recent thought trace, tool calls, and a kill switch. Operators can pause, prompt-inject, replay, fork, and graduate behaviors back into the agent's policy.

**Surfaces covered by this design system:**

| Surface              | Notes                                                                  |
| -------------------- | ---------------------------------------------------------------------- |
| `Mission Control`    | The flagship web dashboard. Agent grid, live activity feed, detail.    |
| `Field` (mobile)     | Pager-style mobile app for on-call interventions.                      |
| `Slide template`     | 16:9 dark deck for releases, postmortems, and roadmap reviews.         |
| `Codex` (tutorial)   | Interactive code tutorial + diff viewer for shipping agent policies.   |

### Source materials referenced

| Source                                | URL                                                              |
| ------------------------------------- | ---------------------------------------------------------------- |
| `WeixinWang24/OrbitPlane` (GitHub)    | https://github.com/WeixinWang24/OrbitPlane                       |
| Related: `Orbit2`                     | https://github.com/WeixinWang24/Orbit2                           |
| Related: `ORBIT`                      | https://github.com/WeixinWang24/ORBIT                            |

> ⚠ **Note for readers with repo access:** The `OrbitPlane` repo was empty at the time this system was built, so the visual direction here was synthesized from the product brief ("mission control for AI agents, cyberpunk neon hacker tone") rather than lifted from code. If you can open the repo and find divergent token names or component patterns, **prefer the code** and update this system. Sibling repos `Orbit2` and `ORBIT` (Oversight Runtime and Boundary for Intelligent Tools) suggest the same product family — explore them to deepen the vocabulary.

---

## 2. Visual Foundations

### Color philosophy — *dark field, neon signal*

OrbitPlane is **dark-first**. The default canvas is near-black with a cool tint (`#0A0D14`). Color is rationed — it is a **signal**, not a decoration. The palette splits into:

| Group       | Used for                                                                                  |
| ----------- | ----------------------------------------------------------------------------------------- |
| **Voids**   | Backgrounds. Five steps from `#05060A` → `#1C2230`. Most UI lives in two of them.         |
| **Lines**   | Hairlines, dividers, borders. `#1E2330` for default, `#2A3140` for emphasis.              |
| **Fg**      | Four steps of text contrast. Most labels live at `--op-fg-3` (`#5A6580`), mono uppercase. |
| **Cyan**    | `#00E5FF` — primary brand signal, focus, links, "orbit". Used very deliberately.          |
| **Lime**    | `#B8FF3C` — agents that are *alive and running*. Success.                                 |
| **Magenta** | `#FF2E8E` — danger, kill, interrupt, errored runs.                                        |
| **Amber**   | `#FFB627` — queued, paused, warn.                                                         |
| **Violet** | `#8B5CF6` — replay, archived, tertiary state.                                              |

Rules:
- **One neon per moment.** Never set two glowing colors next to each other competing for attention. Pick the most important state and let it sing.
- **Glow, don't gradient.** Color emphasis comes from neon outer-glow (`box-shadow: 0 0 24px var(--op-cyan-glow)`), not from filled buttons or background washes.
- **No big colored fills.** A neon-cyan button is a 1px cyan border with cyan text and a soft glow — not a solid cyan rectangle. Save fills for the absolute primary CTA in a screen.

### Typography — *two families, no apologies*

| Role                | Family             | Weights used  |
| ------------------- | ------------------ | ------------- |
| Display & body      | **Space Grotesk**  | 400 / 500 / 600 |
| Code, labels, tags, IDs, timestamps | **JetBrains Mono** | 400 / 500 / 700 |

- **Labels are mono and uppercase**, tracked `+0.16em`. Almost every section header in the UI is a tiny mono label (`AGENTS // 14 ACTIVE`).
- **Display copy is Space Grotesk**, tight tracking (`-0.02em`), generous size jumps. The system has `2xl → 6xl` headlines (24 → 88px); use the biggest comfortable size on hero moments.
- **IDs, timestamps, command paths, tags are all mono.** This is the most consistent rule in the system. If it isn't a sentence, it probably wants mono.
- **Italic mono** (rare) for replayed/synthetic content — it visually fingerprints "this is the agent narrating itself."

### Spacing & layout

- Base unit is **4px**. Scale: `2 4 8 12 16 20 24 32 40 56 80 120`.
- **Dense by default.** OrbitPlane is a console, not a marketing page. Use 12–20px gaps between elements, not 32+.
- **Grids over flow.** Hairline `1px` dividers (`--op-line`) separate every region. The home dashboard is a 12-col grid with 16px gutters.
- **Wide canvases** — desktop targets 1440 with 24px gutters, max-width 1920. Mobile is single-column 360px-wide.
- **Mono numerics for tables and timestamps**; never proportional numbers.

### Borders, corners & elevation

- **Corner radius: sharp.** Default is `0px`. Cards step up to `4px` (`--op-r-2`). Pills use `999px`. Anything > 4px feels wrong.
- **No drop shadows.** Depth comes from elevation steps (`--op-elev-1` → `--op-elev-3`) and **neon outer-glow** for emphasis. A "raised" card has a 1px brighter border, not a soft shadow.
- **Always 1px borders, hairline.** When something needs to feel taller, brighten the border (`--op-border-strong`) rather than thickening it.

### Backgrounds & texture

- **Subtle scanlines** layered globally at ~1.5% opacity. Optional but tasteful — disable on small text panes.
- **Dot grids and crosshair overlays** for any "map", "radar", or "field" view (`assets/orbit-map.svg`, `assets/radar.svg`).
- **Corner brackets** (`┌─┐ └─┘`) frame hero modules — they're drawn as 1px paths in the corners of the container, not as a full border.
- **No photography.** No stock. If imagery is needed, it is **vector** (orbits, radar, horizon line, wireframe).
- **No gradients in cards.** A single full-bleed radial glow is permitted in hero areas; that's it.

### Animation

- **Linear / cubic-bezier(0.2, 0.7, 0.1, 1).** Fast, mechanical, no bounces. 120–200ms for hovers, 300–500ms for state changes.
- **Cursor blink** — `▌` glyph blinking at 1Hz wherever there's an active input or a "live" indicator.
- **Pulse, don't fade.** Active status dots pulse (`opacity 0.5 → 1`) at ~1.2Hz. Never fade silently.
- **Scanline jitter** is optional on terminal panes — subtle, ≤2px translateY at 60Hz, on hover only.
- **No spring physics. No skeumorphic ease.** This is a deterministic console.

### Hover & press states

- **Hover:** elevate border one step (`--op-line` → `--op-line-2`) **and** lift bg one step (`--op-elev-2` → `--op-elev-3`). For neon elements, increase glow intensity.
- **Press:** translate Y `+1px`, reduce glow by 40%, no scale-down. Sharp.
- **Focus:** 1px outer ring in `--op-cyan`, with a 2px offset. Never the browser default.
- **Disabled:** drop foreground to `--op-fg-4`, kill all glow, hairline border at default `--op-line`.

### Transparency & blur

- **Blur** is used only on overlay modals & dropdown menus: `backdrop-filter: blur(20px) saturate(140%)` over a 50%-opacity bg. Nothing else.
- **Transparency** in fills should land in 4–12% range. Solid neon fills feel garish; tint a neon (`rgba(0,229,255,0.08)`) for subtle hover/selected.

### Imagery vibe

The brand isn't photographic. When something needs visual weight, reach for one of:
- A **radar sweep** (`assets/radar.svg`)
- An **orbit map** with concentric rings (`assets/orbit-map.svg`)
- The **horizon silhouette** with a giant magenta planet (`assets/horizon.svg`)
- A **wireframe agent avatar** (small mono initials in a beveled square — see UI kit)

Color in imagery: cool, neon, never warm or sepia. Black + cyan + lime + a single magenta accent is the canonical mix.

---

## 3. Content Fundamentals

### Voice

OrbitPlane writes like a **flight engineer**: short sentences, precise nouns, no flourish, no enthusiasm tax. Think mission-log radio chatter — confident, technical, occasionally dry.

**Person:**
- "You" is used to address the operator directly. ("You can interrupt this agent at any time.")
- The product never refers to itself as "we" or "OrbitPlane" in UI copy. Instead use third-person noun: ("the system has paused 3 agents").
- Agents are referred to **by their handle**, never anthropomorphized. ("`agt_8x4z` is waiting on tool `web.fetch`.") **Never** "Aria is thinking..." — that's competitor copy.

**Casing:**
- **Sentence case** for headings and body. Title Case nowhere.
- **MONO UPPERCASE** for section labels, status, and any tag. Tracked `+0.16em`.
- **Lowercase** for code-like identifiers (`agt_8x4z`, `run_42`, `tool.web.fetch`).

**Punctuation:**
- Drop terminal periods on UI strings, button labels, and labels. Keep them in paragraphs.
- Use `//` as the inline separator in headers (`AGENTS // 14 ACTIVE`).
- Use `→` for affordances ("Open run →"). Never `>`.
- Use `·` (interpunct) between metadata fragments: `agt_8x4z · v1.4 · 2m ago`.

**Numbers, time, status:**
- Counts always shown — never hidden. `[ 14 ]`, `1,402 runs`.
- Times are **relative + precise**: `2m ago` with `(14:02:11 UTC)` on hover.
- Status verbs are present-tense: `running`, `queued`, `paused`, `errored`, `done`, `killed`.

**Emoji:** **No.** Never used in product copy. Unicode symbols are fine and encouraged (`◉ ◌ ● ▲ ▌ → · //`).

**Examples (good vs bad):**

| ✗ Wrong (generic SaaS)                       | ✓ Right (OrbitPlane)                            |
| --------------------------------------------- | ------------------------------------------------ |
| `We've stopped your 3 agents! 🎉`             | `3 agents halted. Reason: operator interrupt.`   |
| `Get started with your first agent`           | `Deploy agt_001. Takes ~12s.`                    |
| `Oops! Something went wrong.`                 | `Run failed at step 14/20 — tool timeout (30s).` |
| `Welcome back, Sarah! Ready to launch?`       | `Welcome back. 2 agents paused since you left.`  |
| `Click here to view details`                  | `Open run →`                                     |
| `Awesome! Your agent is now active.`          | `agt_8x4z online · v1.4 · 14:02:11Z`             |

**Vocabulary the brand uses (memorize these):**

| Term              | Meaning                                                          |
| ----------------- | ---------------------------------------------------------------- |
| **fleet**         | The collection of all your agents.                               |
| **deck**          | The dashboard. ("Pin to the deck.")                              |
| **mission**       | A long-running multi-step task assigned to an agent.             |
| **run**           | One execution of a mission, including its trace.                 |
| **trace**         | The recorded reasoning + tool-call log of a run.                 |
| **intervene**     | The operator stepping into a live agent's loop.                  |
| **graduate**      | Promoting a one-off intervention to permanent policy.            |
| **uplink**        | The connection between OrbitPlane and the agent runtime.         |
| **field**         | The mobile app. ("Page me in the field.")                        |

---

## 4. Iconography

OrbitPlane uses **Lucide** (https://lucide.dev/) as its line-icon set. 1.5px stroke, 24px box, square caps. Sharp and technical. Loaded from CDN — no SVGs to copy.

**Substitution note ⚠** — Lucide was selected as the closest CDN match to the brand's stroke style (since the OrbitPlane repo had no icons of its own). If the codebase ships its own icon set later, **swap Lucide out** and update this section.

### Usage rules
- **1.5px stroke** at all sizes. Don't fill Lucide icons.
- Icons inherit `currentColor`. Default tint is `--op-fg-2`; on focus / selected they get the active neon.
- **Always paired with a label in mono uppercase.** Icon-only buttons are reserved for compact toolbars; even then, include a tooltip.
- **20px is the standard size** in UI chrome. 16px in dense tables. 32px+ only in hero/empty-state moments.

### ASCII & Unicode glyphs (used as iconography)

OrbitPlane leans heavily on **type-as-icon**:

| Glyph    | Use                                       |
| -------- | ----------------------------------------- |
| `●`      | Active dot                                |
| `◉`      | Selected / locked                         |
| `◌`      | Idle / pending                            |
| `▲`      | Alert                                     |
| `▌`      | Cursor / live indicator (blinks)           |
| `→ ← ↑ ↓`| Direction / affordance arrows             |
| `//`     | Header separator                          |
| `·`      | Metadata separator                        |
| `┌─┐`    | Corner brackets framing hero blocks       |
| `[ ]`    | Bracketing tags / IDs                     |

These are real UI elements — set in `JetBrains Mono`, tinted with brand color. Never replaced with SVG.

### Logo lockups (in `assets/`)

- `logo.svg` — horizontal wordmark + glyph (320×64)
- `logo-mark.svg` — square mark, 48×48 (use in app chrome, favicons)
- `logo-lockup-stacked.svg` — stacked, with subtitle, for hero / cover slides

---

## 5. Index of this design system

```
.
├── README.md                  ← you are here
├── SKILL.md                   ← agent-skill entry point
├── colors_and_type.css        ← all foundation tokens
├── assets/
│   ├── logo.svg
│   ├── logo-mark.svg
│   ├── logo-lockup-stacked.svg
│   ├── orbit-map.svg          ← decorative orbit field
│   ├── radar.svg              ← decorative radar sweep
│   ├── horizon.svg            ← horizon silhouette w/ planet
│   └── dot-grid.svg           ← tileable dot grid
├── preview/                   ← Design System tab cards
│   ├── type-display.html
│   ├── type-mono.html
│   ├── type-scale.html
│   ├── colors-voids.html
│   ├── colors-neon.html
│   ├── colors-semantic.html
│   ├── spacing-radii.html
│   ├── spacing-elevation.html
│   ├── components-buttons.html
│   ├── components-status.html
│   ├── components-fields.html
│   ├── components-cards.html
│   ├── components-tags-kbd.html
│   ├── brand-logos.html
│   ├── brand-illustrations.html
│   └── brand-asciikit.html
├── ui_kits/
│   ├── mission_control/       ← desktop web dashboard
│   ├── field/                 ← mobile pager-style app
│   └── codex/                 ← interactive code tutorial / diff
├── slides/                    ← 16:9 deck templates
└── ...
```

---

## 6. Quick start

```html
<link rel="stylesheet" href="colors_and_type.css">
<script src="https://unpkg.com/lucide@latest"></script>
<body class="op-body">
  <h1 class="op-h2">Mission Control</h1>
  <span class="op-label">agents // 14 active</span>
</body>
<script>lucide.createIcons();</script>
```

That's the floor. Everything else lives in the UI kits.

