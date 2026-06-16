# BreakMate Unified Engineering Rulebook & AI Audit Report

## Phase 1 — AI Configuration Inventory

**Core Instructions & Context**

* `GEMINI.md`
* `CLAUDE.MD`
* `BREAKMATE_ROADMAP.md`
* `README.md`

**Agent & Tool Rules**

* `.gemini/settings.json`
* `.claude/settings.json`
* `.agents/rules/graphify.md`
* `.agents/workflows/graphify.md`
* `.kiro/steering/graphify.md`

**Architecture & Guidelines**

* `docs/architecture.md`
* `docs/dev-checks.md`
* `docs/NATIVE_BRIDGES.md`
* `docs/performance-baseline.md`
* `docs/PERSISTENCE_BOUNDARY.md`
* `docs/release_guide.md`

---

## Phase 2 — Rule Extraction Report

**Architecture Rules**

* Feature-first architecture using decoupled isolates.
* Repositories must abstract persistence logic.
* Maintain clear boundaries between `lib/core`, `lib/features/`, and `lib/shared/`.

**Performance Rules**

* Use `FlutterEngineGroup` for spawning secondary windows on macOS. Never use a raw `FlutterEngine`.
* Avoid `BackdropFilter` for full-screen animations.
* Pre-cache all companion animations and tray icons.

**State Management & Storage Rules**

* Use Provider for local UI state.
* Use EventBus for app-wide events and inter-engine sync.
* Storage operations must go through `StorageService`. Repositories cannot call ObjectBox directly.
* Secondary isolates cannot call `StorageService.store`.

**Testing & Release Rules**

* Complete `flutter analyze` with 0 warnings.
* All unit and widget tests must pass before merging.
* Keep the app bundle under 150 MB and assets under 20 MB.

---

## Phase 3 — Rule Conflict Report

| Source Files | Conflict | Resolution |
|---|---|---|
| `BREAKMATE_ROADMAP.md` vs `test/` | Roadmap test counts were previously misaligned with the 19 active test files present. | Fixed. Roadmap test counts updated to reflect active tests. |
| `docs/native-channels.md` vs `docs/NATIVE_BRIDGES.md` | Duplicate tracking of method channels. `NATIVE_BRIDGES` is marked authoritative. | Fixed. Deprecated and deleted `native-channels.md` to prevent desync. |
| `docs/performance-baseline.md` | Mandates baseline capturing but mostly contains "Pending profile run" values. | Enforce that any PR modifying UI components runs profiles to fill out the baseline. |

---

## Phase 4 — Rule Compliance Report

**Rule Violations Detected in Current Codebase:**

* **Architecture (FlutterEngine):** `macos/Runner/CompanionWindowManager.swift` and `macos/Runner/PiPWindowManager.swift` instantiate raw `FlutterEngine` instead of utilizing `FlutterEngineGroup` (noted as not supported in current SDK version but still against ideal rule).
* **Widget Design (Size Limits):** `standalone_break_overlay.dart` (1012 lines) still violates the <300 lines rule and should be decomposed.
* **Testing:** Critical core modules (`TimerEngine`, `TimerOrchestrator`) lack test coverage. Existing tests primarily cover the companion feature.

*(Note: Generic `Exception` instances have been completely resolved and replaced with domain-specific exceptions).*

---

## Phase 5 & 6 — Unified AI Development Standard & Future Coding Rules

# Architecture

* Maintain feature-first architecture (`lib/features/`).
* Respect layer boundaries (`core/`, `features/`, `shared/`).
* Prevent circular dependencies.
* Keep dependency direction inward towards the domain.
* Use strongly typed models.

# Folder Structure

* `core/`: Platform integrations, foundational services, utilities.
* `features/`: Business behavior, domain models, feature-specific UI.
* `shared/`: Visual primitives, reusable widgets, theme colors.

# Dependency Injection

* Register all dependencies only in `dependency_injection.dart`.
* No runtime business logic inside DI.
* No event wiring inside DI.

# State Management

* Use Provider for local UI state.
* Use EventBus for cross-isolate and global app state synchronization.

# UI & Widget Design

* Avoid `BackdropFilter` for full-screen animations. Prefer gradient-based simulations.
* Pre-cache overlay assets.
* **Size Constraint:** No widget should exceed 300 lines without justification. Large widgets must be decomposed.
* Do not mix business logic and rendering.

# Navigation

* Keep routing and navigation contained within `app_navigation_service.dart` or feature-specific routers.

# Services

* Must be interface-driven where appropriate.
* Avoid UI dependencies in services.
* Remain platform-agnostic.

# Repositories

* Must act as the sole source of truth for persistence.
* Repositories must not open/close ObjectBox or use `SimplePrefs` directly (route through `StorageService`).

# IPC

* No raw `Map<String, dynamic>` payloads.
* No dynamic casting.
* Use strongly typed Freezed models.
* Validate all incoming payloads.

# Native Integrations

* Use `FlutterEngineGroup` (`engineGroup.makeEngine`) for all secondary macOS windows.
* All permission flows require: Initial request, Denied state, Permanently denied state, Recovery path. No permission workflow is complete without all four.

# Error Handling

* Never throw generic `Exception`.
* Use `AppException` implementations.
* Route failures through `ErrorHandler`.
* Log recoverable and unrecoverable failures distinctively.

# Logging & Security

* Never store secrets in source code.
* Never log sensitive information.
* Do not trust external IPC payloads without validation.

# Testing

* Required before merge: Unit tests for business logic, Widget tests for critical UI, Native fallback tests, State transition tests.
* Critical modules must maintain: `TimerEngine` coverage, `TimerOrchestrator` coverage, IPC coverage.

# Performance

* Avoid unbounded rebuilds and heavy work in `build()` methods.
* Minimize rebuild scope.
* Use `const` constructors wherever possible.
* Cache assets appropriately.

# Documentation & Code Reviews

* Follow the DEV-CHECKS process.
* Provide release notes and performance measurements on impact PRs.

---

## Phase 7 — Comment Standardization

Future comments must explain:

* Intent
* Business rules
* Platform behavior
* Architectural decisions

**Do not explain obvious code.**

* Forbidden: `// Update state`, `// Create controller`
* Preferred: `// Synchronize timer state across overlay windows to prevent countdown drift during IPC reconnects.`

**Rules:**

* No emojis.
* No AI-generated wording.
* No marketing language.
* No tutorial-style comments.
* No autogenerated headers.

---

## Phase 8 — Architecture Score Simulator

**Current Score Estimate: 75/100**

* *Deductions:* Missing critical tests (-10), Raw engine instantiations (-5), God widgets over 1000 lines (-10).

**Expected Score After Remediation (Quick Wins): 85/100**

* *Actions:* Break down the largest god widget (`standalone_break_overlay.dart`), and refactor `FlutterEngine` to `FlutterEngineGroup` in macOS native code if the SDK permits.

**Expected Score After Full Compliance: 95/100**

* *Actions:* Full test coverage for `TimerEngine` and `TimerOrchestrator`, strongly typed IPC implemented, all comments standardized, and 100% adherence to the new rulebook.

---

### Final Note

This rulebook acts as the absolute source of truth for all AI-assisted generation in BreakMate. All future code modifications must pass through these constraints before execution.
