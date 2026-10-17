# Caffeinate

<p>
  <a href="https://github.com/afollestad/caffeinate-menubar/releases/latest/download/Caffeinate.app.zip">
    <img src=".github/download-macos.svg?v=240x42" alt="Download Caffeinate for macOS (latest release)" width="240" height="42">
  </a>
</p>

A macOS menu bar app that keeps your Mac awake, equivalent to `caffeinate -dims`. Click the coffee cup to open a Liquid Glass popover with a **Stay awake** toggle and a duration slider: **Indefinite** at the far left, then 5-minute steps up to 12 hours. The cup fills with color while your Mac is being kept awake.

While on, it holds the same IOKit power assertions as `caffeinate -dims`:

| Flag | Assertion |
| --- | --- |
| `-d` | `PreventUserIdleDisplaySleep` |
| `-i` | `PreventUserIdleSystemSleep` |
| `-m` | `PreventDiskIdle` |
| `-s` | `PreventSystemSleep` (AC power only) |

## Requirements

- macOS 26 or later
- Xcode 26 or later
- Homebrew (for SwiftLint and xcsift)

## Development

```sh
./scripts/setup.sh    # install tools and the pre-commit hook
./scripts/build.sh    # build .build/app/debug/Caffeinate.app (--release for an optimized build)
./scripts/run.sh      # build, then (re)launch the app
./scripts/test.sh     # run unit tests (optionally pass a filter)
./scripts/lint.sh     # run SwiftLint (--fix to autocorrect)
```

This is a SwiftPM package; `scripts/build.sh` assembles the `.app` bundle and compiles its assets with `actool`.

## Install

Download `Caffeinate.app.zip` from the latest [GitHub Release](https://github.com/afollestad/caffeinate-menubar/releases/latest), unzip it, and move `Caffeinate.app` to `/Applications`. To build it yourself:

```sh
./scripts/build.sh --release
cp -R .build/app/release/Caffeinate.app /Applications/
```

Turn on **Launch at login** from the installed copy so the login item points at `/Applications`.

See `RELEASING.md` for how releases are built and published.
