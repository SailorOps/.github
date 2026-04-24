# SailorOps TUI & CLI Design Language

This document defines the visual and interactive standards for all SailorOps terminal interfaces.

## ⚓ The Anchor Style

1. **Hierarchy**: Use bold headers and indentations to create clear scanning paths.
2. **Icons**: Use the SailorOps icon set (⚓, 🛡️, 📦, 🧭, ✓, ✗, ⚠) consistently across all tools.
3. **Color Semantic**:
   - `Cyan`: Information & Primary Branding
   - `Green`: Success
   - `Yellow`: Warnings & Attention
   - `Red`: Critical Errors
   - `Gray`: Secondary/Metadata info

## 🛠️ Interaction Rules

1. **Non-Destructive**: Destructive actions must require explicit confirmation (`--force` or interactive prompt).
2. **Quiet by Default**: Tools should only print essential information unless `--verbose` is used.
3. **Progress Tracking**: Long-running tasks must show a spinner or progress bar to avoid the "frozen terminal" feeling.

## 📦 Consistency Checklist
- [ ] Uses SailorOps color palette?
- [ ] Includes the ⚓ symbol in the help/header?
- [ ] Respects terminal width (max 80 chars recommended)?

---

⚓ **SailorOps** — Tools engineered for real-world conditions.
