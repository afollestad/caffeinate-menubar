## Scripts

These instructions cover developer scripts under `scripts/`.

- Start every entry-point script with `#!/bin/bash` and `set -euo pipefail`, source `scripts/lib/common.sh`, and keep it executable.
- Keep `.app` bundle layout knowledge in `scripts/build.sh`; other scripts locate the bundle through `app_path` in `scripts/lib/common.sh`.
