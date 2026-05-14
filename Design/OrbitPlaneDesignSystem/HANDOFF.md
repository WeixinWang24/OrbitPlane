# Handoff: OrbitPlane Design System → `WeixinWang24/OrbitPlane`

This bundle is a complete, self-contained **design system** for OrbitPlane (mission control for AI agents) — tokens, assets, preview cards, three UI kits, and a slide template. Your job is to **push it to the empty GitHub repo** so the design becomes part of the OrbitPlane codebase.

---

## What this is

- **Not production code.** Everything in this folder is a **design reference**: HTML prototypes, JSX recreations of components, vector assets, and CSS tokens. They show *what OrbitPlane should look and feel like* — sharp, dark, cyberpunk neon, mission-control aesthetic.
- **The CSS tokens (`colors_and_type.css`) are the canonical contract** — once OrbitPlane has a real frontend, port these to whatever framework gets chosen (Tailwind config, design tokens JSON, CSS variables in a Next.js app, etc.).
- **`SKILL.md`** at the root makes this folder importable as an Agent Skill — once it's in the repo, anyone running Claude Code can reference it as `orbitplane-design` for any future OrbitPlane work.

## Fidelity

**High-fidelity** for the visual system (colors, type, spacing, components shown in the UI kits are pixel-tuned). **Mock-fidelity** for product behavior: the UI kits demonstrate look and key interactions but don't wire up to real APIs.

---

## Steps for Claude Code

### 1. Clone the empty repo

```bash
git clone https://github.com/WeixinWang24/OrbitPlane.git
cd OrbitPlane
```

### 2. Drop in the contents of this bundle

Place every file from this zip into the repo root, preserving the folder structure:

```
.
├── README.md                  # Brand overview, voice, visual foundations, iconography
├── SKILL.md                   # Agent Skill entry point — keep at root
├── HANDOFF.md                 # ← this file (you can delete after pushing)
├── colors_and_type.css        # All foundation tokens (the contract)
├── assets/                    # Logos and decorative SVGs
├── preview/                   # Single-purpose specimen cards (Design System tab)
├── ui_kits/
│   ├── README.md
│   ├── mission_control/       # Desktop web dashboard (JSX + index.html)
│   ├── field/                 # Mobile pager-style iOS app (JSX + index.html)
│   └── codex/                 # Tutorial + diff viewer (JSX + index.html)
└── slides/                    # 16:9 deck templates
```

### 3. Commit and push

```bash
git add .
git commit -m "Add OrbitPlane design system

- Brand README with voice, visual foundations, iconography
- colors_and_type.css design tokens (Space Grotesk + JetBrains Mono)
- Hex HUD logo with violet primary, lime/magenta accents
- Three UI kits: Mission Control (web), Field (mobile), Codex (tutorial + diff)
- Six-slide 16:9 deck template
- 16 specimen preview cards
- SKILL.md so the system is invokable as an Agent Skill"
git push origin main
```

### 4. Verify

After pushing, open `https://github.com/WeixinWang24/OrbitPlane` and confirm:
- README.md renders on the repo home with the cyberpunk mission-control description
- `ui_kits/mission_control/index.html` exists with a working component tree
- `colors_and_type.css` is at the root
- `SKILL.md` is at the root (so Claude Code can pick the skill up on next clone)

---

## Notes for the implementer

- **Fonts** are loaded from Google Fonts at runtime — fine for prototyping, but if you build a production frontend, self-host Space Grotesk and JetBrains Mono in `public/fonts/`.
- **Icons** are Lucide via CDN. Same advice — install `lucide-react` (or whatever idiomatic for the chosen framework) and import locally for production.
- **React + Babel via CDN** is used in the UI kits so the HTML files run with no build step. When you port to a real codebase, lift the components into proper modules and drop the `<script type="text/babel">` wrappers.
- **No drop shadows. No big neon fills. Sharp corners (0–4px, pills excepted).** These are non-negotiable design rules — see `README.md › Visual Foundations` and `SKILL.md › Hard rules`.

## Voice rules — for any future copy

OrbitPlane writes like a flight engineer. No emoji. No marketing fluff. Mono uppercase labels. `//` separators. See `README.md › Content Fundamentals` for examples.

---

## Caveats from the design phase

- The `OrbitPlane` repo was empty when this system was built. Visual direction was synthesized from the product brief (*"control plane for AI agents, cyberpunk neon hacker tone"*). If product reality diverges from this aesthetic, rebase the system on real screenshots/Figma and update `README.md`.
- Sibling repos `WeixinWang24/Orbit2` and `WeixinWang24/ORBIT` (Oversight Runtime and Boundary for Intelligent Tools) may inform the same product family — worth a look before locking the system in.
