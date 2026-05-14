# OrbitPlane

Apple-native mission control for AI agents.

## Current Direction

OrbitPlane is now an Apple-native control plane:

- macOS app first for dense runtime inspection, trace review, and operator intervention.
- iPadOS/iOS Field app for on-call triage and high-signal intervention.
- watchOS later for alert, acknowledge, pause/halt, and status glance.

The MVP avoids npm, Node, web bundlers, CDN scripts, WebView production shells, and third-party Swift packages by default.

## Workspace

Open:

```text
OrbitPlane.xcworkspace
```

Current workspace members:

- `Apps/OrbitPlaneMac/` - migrated macOS MVP.
- `Apps/OrbitPlaneField/` - migrated iOS/iPadOS MVP.
- `Packages/OrbitPlaneCore/` - local shared core package.
- `Packages/OrbitPlaneDesign/` - local SwiftUI design token package.
- `Design/OrbitPlaneDesignSystem/` - visual reference bundle.

## Security Baseline

- Secrets live in Keychain only.
- Logs, trace events, fixtures, and review artifacts must redact secrets by default.
- Do not add third-party packages or build scripts without an explicit decision.
- Keep local package boundaries small and auditable.
