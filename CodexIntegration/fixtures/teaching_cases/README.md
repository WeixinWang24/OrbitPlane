# Teaching Case Contract Fixtures

These fixtures define the Plane-side contract for long-lived Codex teaching cases.

## Files

- `python_variables_beginner.html`: human-readable teaching artifact. It contains the same machine-readable metadata in `script#orbitplane-teaching-case`.
- `python_variables_beginner.case.json`: pure JSON form of the embedded teaching case metadata.
- `python_variables_beginner.artifact_link_event.json`: sample `ARTIFACT_LINKED` event envelope that points Plane to the HTML artifact.

## Reader Rules

Plane should:

- treat HTML as display content only;
- extract metadata from `script[type="application/json"]#orbitplane-teaching-case`;
- validate `schemaVersion == "orbitplane.teaching.case.v1"`;
- project `steps`, `conceptIds`, and `anchors` into native UI state;
- constrain linked artifact paths to approved local directories before loading.
