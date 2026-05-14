---
name: orbitplane-codex-teacher
description: Use when Codex is developing code for OrbitPlane and should emit structured teaching, diff, terminal, and review events to OrbitPlane while tailoring explanations to the user's learning level.
---

# OrbitPlane Codex Teacher

Use this skill when working on OrbitPlane code and the user wants Codex's development process shown as interactive teaching or code review in OrbitPlane.

## Output Rule

Emit structured events through the local emitter:

```bash
python3 /Volumes/2TB/Dev/modules/MCP/OrbitPlaneTeaching/emitter/orbitplane_emit_event.py --event-file <event.json>
```

For multiple events, pass a JSON array file or newline-delimited JSON.

Default event stream:

`/Volumes/2TB/Dev/OrbitPlane/.orbitplane/codex-events/<sessionId>.jsonl`

## Teaching Policy

Create teaching notes that match the user's apparent level:

- assume the user is technically strong and wants architecture-level reasoning
- explain why a change was made, not only what changed
- connect implementation choices to security, maintainability, and Apple-native constraints
- keep notes concise enough to display in a side panel
- include one or two concrete learning objectives when a concept is reusable

## Event Timing

Emit events at these moments:

- before a meaningful implementation phase: `TUTORIAL_STEP_CHANGED`
- after a meaningful source change or generated diff: `DIFF_UPDATED`
- after running build, tests, or validation commands: `TERMINAL_OUTPUT`
- when a development decision is worth teaching: `TEACHING_NOTE_CREATED`
- when reviewing risks or quality issues: `REVIEW_FINDING_CREATED`
- when marking progress through planned work: `CHECKLIST_UPDATED`

Do not emit for every tiny edit. Prefer events that help reconstruct the development story.

## Security Rules

- Do not emit raw secrets, tokens, private keys, cookies, `.env` contents, or credential file contents.
- Do not include whole files when a diff hunk or summary is enough.
- Do not emit arbitrary command output if it contains environment dumps or paths to credential material.
- Treat OrbitPlane as a display and replay surface, not a command target.

If unsure whether a value is sensitive, redact it before emission.

## Contract Reference

Use the `OPCodexEventEnvelope` contract from:

`/Volumes/2TB/Dev/OrbitPlane/Packages/OrbitPlaneCore/Sources/OrbitPlaneCore/CodexTeachingContract.swift`

Architecture note:

`/Volumes/2TB/Dev/vio_vault/08_Agent_Workspace/OrbitPlane_dev/20_Architecture/06_Codex_MCP_Skill_Teaching_Output_Architecture.md`
