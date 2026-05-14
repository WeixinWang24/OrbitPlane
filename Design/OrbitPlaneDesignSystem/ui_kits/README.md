# OrbitPlane · UI Kits

Three product surfaces, each a working high-fidelity recreation of how OrbitPlane should look and feel. Lift components freely.

| Kit                             | What it covers                                                                   |
| ------------------------------- | -------------------------------------------------------------------------------- |
| **`mission_control/`** (web)    | Flagship desktop dashboard. Top nav, sidebar, agent deck grid, activity feed, agent detail w/ trace, controls, cost/tools sidebar. |
| **`field/`** (mobile)           | iOS pager-style app. Three core screens: fleet glance, agent triage, intervene composer. |
| **`codex/`** (interactive web)  | Tutorial walker + diff viewer + sandbox terminal. Steps, files, replay against any past run. |

Open `<kit>/index.html` to view each interactively.

## Convention
- All kits import `../../colors_and_type.css` for tokens.
- All kits load Lucide via CDN for icons.
- All kits load React 18.3.1 + Babel standalone pinned versions.
- Component files are JSX, loaded with `<script type="text/babel">`. Components export themselves onto `window` so cross-file references work without bundling.
- Body has `class="op-body"` and a global scanline overlay.

## Notes / limits
- These are **visual recreations**. State is local; controls are non-functional. Don't ship as production code — re-implement in your real framework using the tokens.
- Some elements (sandbox terminal output, trace steps) are static fixtures. Replace with live data.
