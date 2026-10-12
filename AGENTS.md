## Keep Guidance Slim

- **Default to not writing the bullet.** Add one only for what the code cannot show: cross-file couplings, deliberate absences, non-obvious constraints. Mechanism that only its own file needs belongs in a `///` doc comment there.
- One imperative rule per bullet, ~40 words max. Rationale is at most one clause naming the failure mode; no history, narratives, or rejected alternatives.
- Put each rule in the narrowest `AGENTS.md` that covers the affected files. One owner per rule: cross-reference instead of restating.
- Delete or update bullets made stale in the same change, and keep every path a bullet names resolvable from the repo root.
- Give a new scoped folder its own `AGENTS.md`, a sibling `ln -s AGENTS.md CLAUDE.md` (the symlink is what loads it), and, inside a SwiftPM target, an `exclude` entry in `Package.swift` for both files.

## Scoped Guidance

Read the nearest `AGENTS.md` before editing; `find . -name AGENTS.md -not -path './.build/*'` lists them all.

## Build And Test

- First-time setup: `./scripts/setup.sh`.
- Build: `./scripts/build.sh [--release]`. Run: `./scripts/run.sh`. Test: `./scripts/test.sh [filter]`.
- Run ordered workflows serially, never in parallel: build-then-run, build-then-test.
- Launch through `./scripts/run.sh`, not `swift run` or an Xcode scheme; only the assembled bundle has the assets and `LSUIElement`.

## Lint

- Lint: `./scripts/lint.sh` (pass `--fix` to autocorrect). The pre-commit hook runs it; `./scripts/setup.sh` installs the hook.
- New Swift follows `.swiftlint.yml` plus: no force unwraps outside tests, prefer `let`.

## Code Style

- Give a declaration a `///` doc comment only when its contract is not obvious from its signature; write the *why*, never restate the body.
- Add inline comments only where they explain non-obvious intent at a specific line.
- Put private types below public types.
