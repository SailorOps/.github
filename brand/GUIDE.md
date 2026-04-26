* **Label Taxonomy Table:** (The hex colors you'll use in GitHub settings).
### 2. Unified Label Taxonomy To keep your issue trackers looking clean, use these specific hex colors across all your repositories. This makes the "Still Systems" workshop feel visually anchored. | Label | Color | Description | | :--- | :--- | :--- | | **type:bug** | `#D73A4A` (Red) | Something isn't working. | | **type:feature** | `#A2EEEF` (Blue) | New functionality request. | | **good first issue** | `#7057FF` (Purple) | Great for new contributors. | | **priority:high** | `#B60205` (Dark Red) | Needs immediate attention. | | **status:blocked** | `#000000` (Black) | Waiting on external factors. | | **documentation** | `#0075CA` (Dark Blue) | Improvements to READMEs or docs. | 

*************************************************************

Standardize GitHub Actions (CI workflows, linting, tests, release automation) and expose their status via badges.
To achieve "Structural Clarity" in your GitHub Actions, you should treat your workflows like code: modular, reusable, and consistently named. Since you are building Python-based tools (`nexus-v`) and package buckets (`scoop-bucket`), your automation needs to handle both code quality and release distribution.

## 1. The Core Workflow Stack
For a Still Systems project, I recommend three standard workflow files located in `.github/workflows/`:

### `ci.yml` (Linting & Testing)
This is your "Stability" check. It should run on every Push and Pull Request.
* **Linting:** Use `ruff` (it’s the fastest Python linter/formatter, fitting your "Zero-Cost/High-Performance" preference).
* **Testing:** Use `pytest`.
* **Badge Link:** `https://github.com/stillsystems/REPO_NAME/actions/workflows/ci.yml/badge.svg`

### `release.yml` (Automation)
Triggered only when you create a new **Tag** or **GitHub Release**.
* **Tasks:** Build the package, upload binaries to the release, and (if applicable) update the `nexus-v` core.
* **Badge Link:** `https://img.shields.io/github/v/release/stillsystems/REPO_NAME?style=flat-square&color=111827`

### `stale.yml` (Maintenance)
A "Workshop Housekeeping" script that automatically labels or closes inactive issues to keep the repo from looking abandoned.

---

## 2. Standardized Badge Layout
Place these at the very top of your README, immediately under the one-line description. Use the **Flat Square** style and your brand's **Slate** color (`#111827`) for a unified look.

```markdown
[![CI](https://github.com/stillsystems/REPO_NAME/actions/workflows/ci.yml/badge.svg)](https://github.com/stillsystems/REPO_NAME/actions)
[![Release](https://img.shields.io/github/v/release/stillsystems/REPO_NAME?style=flat-square&color=111827)](https://github.com/stillsystems/REPO_NAME/releases)
[![License](https://img.shields.io/github/license/stillsystems/REPO_NAME?style=flat-square&color=111827)](LICENSE)
```

---

## 3. The "Still Systems" Action Template (Python)
Here is a standardized `ci.yml` you can drop into `nexus-v`. It uses `uv` for speed, aligning with your current local dev environment.

```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install uv
        run: curl -LsSf https://astral.sh/uv/install.sh | sh

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Lint and Format
        run: |
          uv run ruff check .
          uv run ruff format --check .

      - name: Run Tests
        run: uv run pytest
```

## 4. Implementation Steps
1.  **Create the files:** Add the `.yml` files to the `.github/workflows/` directory in each repository.
2.  **Update the README:** Paste the badge Markdown into the template we finalized.
3.  **Branch Protection:** In GitHub Settings, enable "Require status checks to pass before merging" for the `main` branch. This enforces your "Stability" trait.

By standardizing these Actions, you ensure that every tool in the Still Systems workshop is verified before it ever reaches a user. 

Should we draft the **Release Automation** workflow next to handle syncing your `nexus-v` updates to the **WinGet** and **Scoop** repositories?
*************************************************************
* **Milestone Naming:** (How you name your releases).
### 3. Predictable Milestones When planning updates for `nexus-v` or the package buckets, use a standard naming convention so your **Roadmap** is easy to follow: * **Versions:** `v1.0.0-stable`, `v1.1.0-beta` * **Time-based:** `2026-Q2-Roadmap`, `2026-Q3-Release`
*************************************************************
* **Voice/Tone Rules:** (Phase 3 traits).
1. The One-Line Pitch (The Elevator Pitch)
"Clean, documented, and stable open-source tools built for developers of all skill levels."

2. The Standard "About" Block
"Still Systems is a focused workshop dedicated to building foundational developer tools. We prioritize structural clarity, long-term stability, and beginner-friendly documentation over feature bloat and trend-chasing."

3. The "How to Contribute" Snippet
"We welcome contributors of all experience levels. To maintain the stability of this tool, please ensure all Pull Requests include updated documentation and follow the existing code patterns. See our Global Contributing Guidelines for more details."

4. The Support & Contact Block
"If you encounter a bug or have a feature request, please open an issue in this repository. For security-related concerns, please refer to our Security Policy."

5. The License & Attribution Block
"This project is licensed under the MIT License - see the LICENSE file for details. Built and maintained by Still Systems in Athens, Texas."