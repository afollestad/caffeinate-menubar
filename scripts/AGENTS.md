## Scripts

These instructions cover developer scripts under `scripts/`; `scripts/ci/AGENTS.md` covers CI scripts.

- Start every shell entry point with `#!/bin/bash` and `set -euo pipefail`, and keep it executable. Developer scripts source `scripts/lib/common.sh`.
- Keep `.app` bundle layout knowledge in `scripts/build.sh`; other scripts locate the bundle through `app_path` in `scripts/lib/common.sh`.
