---
name: release-caffeinate
description: Prepare, dry-run, and trigger Caffeinate releases. Use when the user asks to release Caffeinate, bump its version, make a patch/minor/major release, run a release dry run, trigger release CI, or download a canary build.
---

# Release Caffeinate

Releases are tag-driven by CI: bump the version in `Resources/Info.plist`, commit `Release Caffeinate vX.Y.Z`, and push `main`. The `Release` workflow then signs, notarizes, writes release notes with Copilot, pushes the `vX.Y.Z` tag, and publishes the GitHub Release. A push publishes whenever the current version's tag is missing, so a first or retried release needs no bump. `RELEASING.md` covers modes and secrets.

## Workflow

1. Read `AGENTS.md` and `RELEASING.md`.
2. Run `git fetch origin main --tags` and `git status --short --branch`. Stop unless the tree is clean, on `main`, and level with `origin/main`.
3. Read the current version and build, and whether its tag exists:

   ```sh
   plutil -extract CFBundleShortVersionString raw Resources/Info.plist
   plutil -extract CFBundleVersion raw Resources/Info.plist
   git ls-remote --tags origin "refs/tags/v$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)"
   ```

4. **Current version untagged** (first or retried release): confirm with the user that this version should ship, then skip to step 7 and commit with `--allow-empty`.
5. **Otherwise bump.** Ask for `patch`, `minor`, or `major` when unspecified (`X.Y.(Z+1)`, `X.(Y+1).0`, `(X+1).0.0`), and increment the build number by 1:

   ```sh
   plutil -replace CFBundleShortVersionString -string X.Y.Z Resources/Info.plist
   plutil -replace CFBundleVersion -string N Resources/Info.plist
   ```

6. Build and confirm the bundle's metadata, then commit only `Resources/Info.plist`:

   ```sh
   ./scripts/build.sh --release
   /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' -c 'Print :CFBundleVersion' .build/app/release/Caffeinate.app/Contents/Info.plist
   ```

7. Commit with the subject `Release Caffeinate vX.Y.Z` and no other subject text (the notes step matches it exactly), plus the trailer your instructions require. Push `main`.
8. Watch the run and report its URL, the tag, and the release URL:

   ```sh
   gh run list --workflow Release --branch main --limit 3
   gh run watch <run-id> --exit-status
   gh release view vX.Y.Z --json url --jq .url
   ```

## Dry Runs and Canaries

- Dry run (signs, notarizes, uploads an artifact, publishes nothing): `gh workflow run Release --ref main`, then watch it as above.
- Every non-publishing push to `main` uploads a signed, unnotarized canary:

  ```sh
  gh run download <run-id> --repo afollestad/caffeinate-menubar -D ~/Downloads
  xattr -dr com.apple.quarantine ~/Downloads/Caffeinate-canary-*/Caffeinate.app
  ```

## Failures

- **Before `Create and push tag`:** nothing was published. Fix the cause, then `gh run rerun <run-id> --failed` or push again.
- **After `Create and push tag`:** the tag exists without a release. Ask the user before deleting the tag or creating the release by hand.
- **`Check secrets` or `Import signing certificate`:** point the user to `RELEASING.md` → Secrets; `./scripts/set-certificate-secrets.sh` resets the certificate secrets.

## Rules

- Never create or push release tags locally; CI owns them.
- Manual `workflow_dispatch` runs are dry runs only and never publish.
- Edit only the two version keys; never print, commit, or change secrets during a release.
- Stop if the target tag already exists, the version is not `X.Y.Z`, or the build number is not a larger integer.
