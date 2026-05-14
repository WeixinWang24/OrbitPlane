# Field — mobile pager-style UI

Three core mobile screens, each rendered in an iOS 26 device frame, shown side-by-side for easy comparison.

## Screens
1. **Fleet** — paged agents at the top, live agents below, bottom tab bar
2. **Agent triage** — single agent detail with intervene/pause/halt action stack
3. **Intervene** — composer with quick-reply chips and a live console-style input

## Files
- `index.html` — entry
- `ios-frame.jsx` — `IOSDevice`, `IOSStatusBar`, `IOSKeyboard` (starter component)
- `Screens.jsx` — `FleetHome`, `FieldAgentDetail`, `FieldIntervene` + atoms
