# Mission Control — desktop web UI

Flagship deck for operators. Two main states:

1. **Deck view** — grid of agent cards + live activity feed (right rail)
2. **Agent detail** — click any card; trace timeline, tool/cost sidebar, intervene / pause / halt / fork / replay / graduate controls

## Files
- `index.html` — entry point, mounts the app
- `styles.css` — kit-local styles (imports `colors_and_type.css`)
- `primitives.jsx` — `Pill`, `Tag`, `Kbd`, `Label`, `Button`, `Caret`, `Icon`, `SEED_*`
- `Chrome.jsx` — `TopBar`, `Sidebar`, `BottomBar`
- `AgentDeck.jsx` — `AgentCard`, `AgentGrid`, `ActivityFeed`
- `AgentDetail.jsx` — `AgentDetail` (hero + trace + side panel)
