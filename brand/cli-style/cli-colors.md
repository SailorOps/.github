# SailorOps CLI Color Semantics

To maintain a consistent experience across all SailorOps binaries, every tool must use the following color palette for standard output and TUI elements.

## 🎨 Standard States

| State | Color Name | Hex | ANSI (16-color) | Usage |
|:---|:---|:---|:---|:---|
| **Primary** | Ops Blue | `#4CC3FF` | `\033[34m` (Blue) | Default accents, highlight text, info icons |
| **Success** | Signal Green | `#00C47A` | `\033[32m` (Green) | Completed tasks, checkmarks, valid states |
| **Warning** | Warning Amber | `#FFB84D` | `\033[33m` (Yellow) | Non-critical issues, cautionary advice |
| **Error** | Alert Red | `#FF4D4D` | `\033[31m` (Red) | Failures, critical errors, "X" icons |
| **Muted** | Steel Silver | `#D7E2F0` | `\033[90m` (Gray) | Secondary info, timestamps, paths |

## 🛠️ Implementation Guidelines

1. **Icons**: Use standard icons paired with the appropriate color:
   - `ℹ` (Blue) for Info
   - `✔` (Green) for Success
   - `⚠` (Yellow) for Warning
   - `✖` (Red) for Error
2. **Contrast**: Always ensure text is readable against a dark navy or graphite background (the SailorOps default).
3. **No-Color Support**: All SailorOps tools must respect the `NO_COLOR` environment variable and strip ANSI codes if present.
