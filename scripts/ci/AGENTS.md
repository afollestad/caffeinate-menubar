## Release CI Scripts

These instructions cover the CI scripts under `scripts/ci/`; `RELEASING.md` documents the release process and secrets.

- **Keep YAML thin.** Put logic here and keep `.github/workflows/*.yml` as orchestration. Keep both workflows on the same runner label and `DEVELOPER_DIR`, so releases build on the validated toolchain.
- **Protect secrets.** Never print secret values, enable shell tracing, or write signing material outside `$RUNNER_TEMP`.
- **Fail before publishing.** Validate the version, tag, signature, notarization, and packages before creating the tag or GitHub Release; only push-triggered `release` runs may do either.
- **Let `detect-release-version.py` own the mode.** The workflow only compares its outputs and never recomputes them from `github.event_name`.
- **Ship dSYMs with every binary.** Release builds strip the app, so `create-dsym-zip.sh` matches dSYM UUIDs to every shipped slice before notarization.
- **Validate Copilot release notes structurally.** `generate-release-notes.sh` accepts only bold theme groups with linked italic children and one Full Changelog footer, and prints diagnostics on rejection.
- **Upload canaries from `stage-canary-app.sh`'s staging directory**, never the bundle path; `actions/upload-artifact` drops the root folder and flattens symlinks.
- Cover script behavior with `*_tests.py`, run by `python3 -m unittest discover -s scripts/ci -p '*_tests.py'`. Keep Python compatible with 3.9 via `from __future__ import annotations`.
