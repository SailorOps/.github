# SailorOps Contribution Rules

We value technical precision and operational clarity. Every contribution to a SailorOps project should feel intentional, minimal, and durable.

## ⚖️ General Principles

1. **Clarity Over Cleverness**: Code should be easy to audit. Avoid "magic" or overly complex abstractions that hide state.
2. **Minimal Dependencies**: Before adding a dependency, ask if it can be solved with the standard library. SailorOps tools aim for a small footprint.
3. **Predictability**: Tools should behave the same way in every environment. Avoid global state or implicit configuration.
4. **Binary Portability**: Prioritize architectures that support static linking and single-binary distribution.

## 🛠️ Code Standards

- **Language-Specific**:
  - **Go**: Follow standard `gofmt` and `go vet`. Use `%w` for error wrapping.
  - **TypeScript**: Use strict typing. Avoid `any` unless strictly necessary for external interfaces.
- **Documentation**: Every exported function must have a clear docstring. Every new feature must be documented in the README.
- **Testing**: We maintain high test coverage. New features must include unit tests. Fixes must include a regression test.

## 🤝 Process

1. **Issue First**: For anything larger than a typo, open an issue to discuss the design before writing code.
2. **Clean Commits**: Use descriptive commit messages. Atomic commits are preferred.
3. **Pull Requests**: Provide a clear description of the "Why" behind the change. Link the relevant issue.

---

⚓ **Build for the long haul. Ship with precision.**
