<!--
Sync Impact Report
- Version change: [INITIAL] → 1.0.0
- List of modified principles:
  - [ALL TEMPLATE PLACEHOLDERS] → Concrete Principles (Code Quality, Testing, UX, Performance, Simplicity)
- Added sections:
  - Technical Governance
  - Quality Gates
- Removed sections:
  - None
- Templates requiring updates:
  - ✅ updated: .specify/memory/constitution.md
  - ⚠ pending: .specify/templates/plan-template.md (already aligned)
  - ⚠ pending: .specify/templates/spec-template.md (already aligned)
  - ⚠ pending: .specify/templates/tasks-template.md (already aligned)
- Follow-up TODOs:
  - None
-->

# recetarios-mama Constitution

## Core Principles

### I. Code Quality First
Code must be readable, maintainable, and adhere to idiomatic patterns of the chosen language. Avoid over-engineering; keep abstractions focused on solving current problems. Consistency with existing codebases and project conventions is mandatory.

### II. Testing Excellence
Comprehensive test coverage is non-negotiable. Every feature must include unit tests for core logic and integration tests for critical paths. Tests should be automated, fast, and repeatable. Prefer Test-Driven Development (TDD) when feasible to ensure requirements are met and prevent regressions.

### III. User Experience (UX) Consistency
User interfaces and interactions must be consistent across the entire application. Follow established design systems and interaction patterns. Visual polish and intuitive navigation are as important as functional correctness to ensure a seamless experience for the user.

### IV. Performance & Efficiency
Applications must be responsive and optimized for resource efficiency. Establish clear performance benchmarks (e.g., load times, memory usage) and ensure they are met. Monitor and address performance bottlenecks proactively during the development lifecycle.

### V. Simplicity (YAGNI)
Implement only what is necessary for the current requirements. The "You Ain't Gonna Need It" (YAGNI) principle should guide architectural decisions to avoid premature optimization and unnecessary complexity.

### VI. Language Standards
All project documentation, including specifications, implementation plans, task lists, and source code comments, MUST be written in English. This ensures consistency and accessibility for technical contributors. The application's user interface (UI) and user-facing messages MUST be presented in Spanish as per the project requirements.

## Technical Governance

**Decision Framework**: Technical choices (libraries, frameworks, architecture) must be justified against the core principles. Avoid "bleeding-edge" or niche solutions unless they provide a significant, documented advantage.

**Implementation Standards**: Use stable, well-supported technologies. Every implementation must undergo a peer review process to ensure adherence to these principles and project standards.

## Quality Gates

**Automated Checks**: CI/CD pipelines must include linting, static analysis, and full test suite execution. No code shall be merged without passing all automated quality gates.

**Performance & Accessibility**: Regular performance audits and accessibility checks (WCAG 2.1+) must be conducted to ensure the application remains within defined limits and accessible to all users.

## Governance

This constitution is the primary reference for all technical decisions. Amendments require a clear rationale, a migration plan for existing code, and consensus from the lead maintainers. Technical debt must be tracked and addressed periodically. Use the Project Plan and Tasks templates to ensure consistency in implementation and verification.

**Version**: 1.0.0 | **Ratified**: 2026-06-02 | **Last Amended**: 2026-06-02
