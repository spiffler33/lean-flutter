# Prompt Templates

## Bug Fix Template
Fix [specific bug] in Lean.

Current behavior: [what happens]
Expected behavior: [what should happen]

Constraints:
- Don't modify unrelated features
- Keep implementation under [X] lines
- Test using LEAN_TESTS.md checklist

Verify ALL tests still pass before claiming complete.

## Feature Addition Template
Add [feature] to Lean.

Requirements: [specific details]
Must NOT break: See LEAN_CONTEXT.md core features
Max lines to add: 50

Include rollback instructions if feature needs removal.
