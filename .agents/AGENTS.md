## Repo-Local Workflows

These instructions cover agent workflows under `.agents/`.

- **Store skills under `.agents/skills/<name>/SKILL.md`** and expose them through the `.claude/skills` and `.codex/skills` symlinks to `.agents/skills`.
- **Keep skills concise.** Put only agent-facing steps in `SKILL.md`; human release docs live in `RELEASING.md`.
- **Use the release skill** for version bumps, release dry runs, and canary downloads: `.agents/skills/release-caffeinate/SKILL.md`.
- **Protect secrets.** Never commit signing certificates, App Store Connect keys, passwords, or base64 secret values.
