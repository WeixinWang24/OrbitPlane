---
name: orbitplane-design
description: Use this skill to generate well-branded interfaces and assets for OrbitPlane. OrbitPlane is Apple-native first: macOS/iPadOS/iOS/watchOS SwiftUI apps with zero third-party dependencies for the MVP, using this bundle as the visual reference and token source. The original web UI kits remain design references, not the production technology stack.
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files.

## Current product direction

OrbitPlane is an Apple-native control plane for AI agents.

- Primary MVP: macOS SwiftUI app.
- Secondary surface: iPadOS/iOS Field app.
- Later surface: watchOS alert/ack/halt companion.
- Web UI kits in this folder are high-fidelity visual references only.
- Production MVP should avoid npm, Node, web bundlers, CDN scripts, and third-party Swift packages.
- Shared contracts should be JSON-compatible Swift models in a local `OrbitPlaneCore` package.

The design system folder contains:
- `README.md` — high-level brand, visual foundations, voice, iconography, file index
- `colors_and_type.css` — CSS variables and semantic type classes you can drop into any HTML file
- `assets/` — logos and decorative SVGs (orbit-map, radar, horizon, dot-grid)
- `preview/` — single-purpose specimen cards documenting tokens and components
- `ui_kits/<product>/` — React (JSX) component libraries + a live `index.html` demo for each surface
- `slides/` — 16:9 deck slide templates

**If creating visual artifacts** (slides, mocks, throwaway prototypes, etc):
- Copy assets out of `assets/` into your output
- Link `colors_and_type.css` for tokens, or inline the variables you need
- Lift JSX components from `ui_kits/<surface>/` rather than rebuilding from scratch
- Stay dark-first, mono-label-heavy, sharp corners, and rationed neon. Never lean on emoji.

**If working on production SwiftUI code:**
- Treat `colors_and_type.css` as the visual token source, then port tokens into SwiftUI types such as `OPColor`, `OPFont`, `OPSpacing`, and `OPRadius`.
- Read `README.md`'s "Content Fundamentals" before writing any UI copy — OrbitPlane has strict voice rules (no enthusiasm tax, no emoji, mono labels, `//` separators).
- Re-implement the patterns shown in `ui_kits/<surface>` as native SwiftUI, not WebView or embedded React.
- Keep macOS control-plane UI dense and inspection-oriented.
- Keep iOS/iPadOS Field UI focused on triage, pause/halt/intervene, and high-signal trace review.
- Keep watchOS limited to alert, ack, pause/halt, and status glance.
- Prefer Apple SDKs only: SwiftUI, Foundation, Security/Keychain, CryptoKit, AuthenticationServices, LocalAuthentication, URLSession, and Observation.

**If the user invokes this skill without other guidance,** ask them what they want to build or design, ask 4–8 targeted questions (surface, audience, key states, novel vs. by-the-book), then act as an expert OrbitPlane designer who outputs HTML artifacts or production code depending on the need.

**Hard rules — do not violate without explicit user override:**
- No emoji in product copy. Unicode glyphs (`● ◌ ▲ ▌ →`) are fine.
- No npm, Node, CDN scripts, WebView production shell, or third-party Swift package for the MVP unless explicitly approved.
- No build phase scripts that run external tools.
- No third-party analytics, crash reporting, telemetry, or package-manager install hooks.
- Secrets live in Keychain only; never in `UserDefaults`, logs, trace events, screenshots, fixtures, or repo files.
- No drop shadows. Depth comes from elevation steps + neon outer-glow only.
- No corner radii > 4px (except pills at 999px).
- Headings are sentence case. Labels are MONO UPPERCASE tracked `+0.16em`.
- No big neon fills. Neon is a 1px border + glow + matching text color.
- Tone: flight engineer. Short, technical, no marketing fluff. Never anthropomorphize agents.
