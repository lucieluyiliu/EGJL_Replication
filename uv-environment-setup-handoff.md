# Python Environment Tooling: Setup Handoff

This file summarizes a decision made in a planning conversation about package and
environment management on a new MacBook (Apple Silicon, M5). The driving use case is
a **Management Science replication package** containing both Python and substantial R
code, with WRDS (subscription) data.

The reader of this file (a local Claude with access to the repository) is expected to
perform the **uv / Python** setup, using the actual package list available in the repo.
The R side (renv) and the non-tooling parts of the replication package are out of scope
for this task and are noted only for context.

---

## Decisions

- **Python package/environment manager: `uv`.** Replaces Anaconda.
- **R package manager: `renv`.** Handled separately by the user; not part of this task.
- **Anaconda: retire.** Keep installed and idle during transition, remove once nothing
  depends on it. Do **not** replace with Miniforge unless a non-PyPI system-binary need
  appears (see "Edge case" below).
- **Structure: one tool per language** (uv for Python, renv for R). No unifying tool
  (pixi was considered and rejected; it would mean changing the R workflow for no
  compliance benefit).

---

## One decision the executing agent must resolve from the repo

The repository's location determines two settings. Check where the repo lives:

1. **Repo lives inside a Dropbox-synced folder** (the user's typical coauthored workflow):
   - The `.venv` MUST be kept out of Dropbox. Set a project-environment override so the
     environment lands on local disk:
     ```bash
     export UV_PROJECT_ENVIRONMENT="$HOME/uv-envs/${PWD##*/}"   # add to ~/.zshrc
     ```
   - Initialize the project WITHOUT git (`uv init --vcs none ...`), because a git repo
     inside a Dropbox-synced folder risks `.git` corruption. (The user is aware of and
     accepts the git+Dropbox tradeoff for her own backup reasons; do not add a nested
     git repo on her behalf inside the shared folder.)
   - PyCharm will not auto-detect a relocated env. Point its interpreter manually at
     `~/uv-envs/<project-name>/bin/python`.

2. **Repo lives outside Dropbox** (local disk, with git remotes for backup):
   - Do NOT set `UV_PROJECT_ENVIRONMENT`. Let the `.venv` live in the project root
     (default). PyCharm's uv integration auto-detects it cleanly.

If unsure which case applies, ask the user before proceeding.

---

## uv setup steps (Python side)

```bash
# 1. Install uv (no admin rights needed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 2. (Only if repo is inside Dropbox) relocate environments to local disk:
#    add to ~/.zshrc, then restart the shell
#    export UV_PROJECT_ENVIRONMENT="$HOME/uv-envs/${PWD##*/}"

# 3. From the repo root, create the project scaffold if not already present.
#    Use --vcs none if inside a Dropbox-shared folder.
uv init --vcs none .          # or: uv init . if outside Dropbox and git is wanted

# 4. Pin the Python version (record in .python-version; ships with the package)
uv python pin 3.12            # adjust to the version the repo actually targets

# 5. Add the packages the repo uses. USE THE ACTUAL LIST FROM THE REPOSITORY.
#    Prefer adding top-level packages the code imports and letting uv resolve the rest,
#    rather than importing a full transitive freeze.
uv add <package1> <package2> ...

# 6. Run code inside the env WITHOUT activating, via:
uv run python <script>.py
uv run jupyter lab

# 7. On any other machine, rebuild the env from the committed lockfile:
uv sync
```

### If migrating from an existing conda env
Export the current package list as a reference, then add the real top-level packages:
```bash
conda activate <envname>
pip list --format=freeze > /tmp/conda-pkgs.txt   # reference list; avoids broken @ file:// refs
conda deactivate
```
Review `/tmp/conda-pkgs.txt`, then `uv add` the genuine top-level dependencies.

---

## Replication-package outputs (the immediate use case)

The Management Science checklist (item 8) requires the README to report languages and
package versions; item 17 requires the code to run on a different computer. For the
Python side:

```bash
# Generate a fully pinned, pip-installable requirements file for the package.
# Tool-agnostic: a replicator with plain pip can use it, no uv required on their end.
uv export --format requirements-txt --no-hashes --no-emit-project > requirements.txt
```

Include in the replication package:
- `requirements.txt` (the export above) AND/OR `pyproject.toml` + `uv.lock`
- The Python version (from `.python-version` or stated in the README)

Do **NOT** include in the package:
- The `.venv` directory or any installed packages. It contains compiled,
  Apple-Silicon-specific binaries that will not run on a replicator's machine. The
  environment must be rebuilt from the spec, not shipped.

---

## Constraints and facts to rely on

- **No binary duplication across projects.** uv stores each package version once in a
  global cache (`~/Library/Caches/uv` on macOS) and links it into each project's `.venv`.
  On APFS this uses copy-on-write clones. Multiple projects sharing the same package do
  not duplicate the bytes on disk. (Note: `du` over-reports per-folder size because it
  counts shared files at face value; trust actual free space.)
- **The cache and any relocated `.venv` must be on the same physical volume** for the
  linking to work. Both on the internal disk is correct. Do not split environments onto
  an external drive while the cache stays internal, or uv falls back to full copies.
- `uv run` replaces conda's activate step in project mode. There is no global named-env
  registry; environments are folder-local by default.

---

## Edge case to check (then stop and report if found)

uv only installs from PyPI. Scan the repo's dependencies for any package that is NOT
available on PyPI or requires non-Python system binaries (e.g., GDAL, certain GPU/CUDA
toolkits, geospatial stacks). The described stack (wrds, pandas, duckdb, sqlalchemy,
pyarrow, numpy, scipy, statsmodels, matplotlib) is all pure-PyPI and fine. If a
non-PyPI system-binary dependency turns up, do NOT force it through uv; flag it to the
user, as that specific case is where `pixi` (not Anaconda) would be the right tool.

---

## Out of scope for this task (context only)

- R environment: user will set up `renv` (`renv::init()` -> `renv.lock`, restored with
  `renv::restore()`). The package will carry `renv.lock` alongside the Python spec.
- WRDS data: documented under checklist item 3b (commercial/subscription), with obtain
  instructions under item 23. Not redistributed.
- Master script, log files, relative paths, synthetic sample data: handled separately.
