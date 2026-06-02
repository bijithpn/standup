# Persistence Boundary

Single source of truth for how BreakMate persists state, where ObjectBox
lives on disk, and how repositories are allowed to touch it. Anything that
mutates persistent state must go through one of the surfaces documented
here.

## Storage stack

| Layer | Backing | Owner | Purpose |
| --- | --- | --- | --- |
| `SimplePrefs` | `shared_preferences` plugin | `core/services/simple_prefs.dart` | KV mirror for fast read on cold start and ObjectBox-less environments |
| ObjectBox store | Native `data.mdb` | `core/services/storage_service.dart` | Boxes for entities + canonical KV store |
| `kvBox` | `Box<KeyValueRecord>` | `StorageService` | Durable, typed KV overlay over `SimplePrefs` |

Repositories are not allowed to call the ObjectBox builder, the
`SimplePrefs` plugin, or `rootBundle` directly. They go through
`StorageService` (KV and boxes) or one of the typed repository classes
below.

## ObjectBox store

- Active path: `<appSupport>/breakmate_db` (resolved via
  `path_provider`).
- Legacy path: `<docs>/breakmate_db` (older macOS app builds).
- If only the legacy path exists on init, `StorageService` renames it
  into place before opening.
- Lock/schema failures fall back to `<tempDir>/breakmate_fallback` with a
  `debugPrint` warning. If even that fails, `StorageService._failed` is
  set to `true`, all box getters throw, and `getIt` registration of
  dependent services is short-circuited.

Secondary isolates (`Isolate.current.debugName` contains `overlay` or
`companion`) cannot call `StorageService.store`. The getter throws
because the native library handle is not initialized in those isolates.

## Box inventory

| Box | Entity | `objectbox.g.dart` line | Notes |
| --- | --- | --- | --- |
| `settingsBox` | `SettingsSnapshot` | 1633 | 24 props, single row, mirrors settings repo |
| `dailyStatsBox` | `DailyStats` | 1549 | 6 props, one row per day |
| `globalStatsBox` | `GlobalStats` | 1582 | 5+ props, single row, streak + totals |
| `companionPreferencesBox` | `CompanionPreferences` | 1504 | 8 props, single row |
| `kvBox` | `KeyValueRecord` | 1610 | 4 props, typed KV mirror |
| (session state) | `SessionState` | 1908 | Wrapped by `SessionStateRepository`, single fixed id=1 |

The `SettingsSnapshot` row is the canonical object. `SettingsRepository`
mirrors it into `SimplePrefs` and `kvBox` for hot fields so the main UI
does not have to round-trip ObjectBox on every read.

## StorageService init

`StorageService.openStore` runs five stages:

1. Resolve `activeStoreDir` (`<appSupport>/breakmate_db` or legacy).
2. Open the native store via `openStore(directory: ...)`.
3. Classify failures: `isLockError` (matches `operation not permitted`,
   `lock`, `10199`, `10101`) or `isSchemaError` (matches `migration`,
   `schema`, `incompatible`, `corrupt`, `model`).
4. For lock errors, attempt cleanup of stale lock files and retry once.
5. If both fail, write the store to `<tempDir>/breakmate_fallback`,
   log a FATAL entry, and call `diagnoseAndLogFailure(activeStoreDir)`.

`StorageService` also exposes `diagnoseStorage(storeDir)` (writes a
`.write_test` file in the docs dir to confirm write permission) and
`getDatabaseSize()` (reads `data.mdb` length). These exist for the
in-app diagnostics page and for log capture; nothing else should call
them.

## KV mirror contract

`StorageService` exposes typed accessors for `int`, `bool`, `string`,
and `double`. Every `set*` call is **write-through**:

1. Forward to `SimplePrefs.set*` (cheap, in-memory + plugin).
2. Put a `KeyValueRecord` into `kvBox` with a `type` discriminator
   (`'int'`, `'bool'`, `'string'`, `'double'`). Doubles are stored as
   `.toString()` and parsed via `double.tryParse`.

Every `get*` call is **read-prefer-typed**:

1. If `kvBox == null`, fall back to `SimplePrefs.get*`.
2. Otherwise look up the record by `KeyValueRecord_.key`.
3. If the record exists **and** `kv.type` matches the expected
   discriminator, return the typed value (parsed for doubles).
4. Otherwise fall back to `SimplePrefs.get*`.

This contract is what lets the app keep working when ObjectBox fails to
open, and what lets the legacy `SimplePrefs` data flow into the typed
box on first run.

## Repository usage

| Repository | Owns | Source of truth |
| --- | --- | --- |
| `SettingsRepository` | `settingsBox` | Mirrors to `SimplePrefs` on every change |
| `TimerRepository` | `kvBox` | Saves under `timer_*` keys via `StorageService.setString`/`setInt` |
| `SessionStateRepository` | `Box<SessionState>` | Fixed id=1, keyed on `lastSessionDate` |
| `StatsService` | `dailyStatsBox` + `globalStatsBox` | Daily roll-up + lifetime totals |

Repositories must not:

- Open or close the ObjectBox store.
- Call `SimplePrefs` directly (use `StorageService`).
- Write to the filesystem outside `path_provider` directories.
- Cache state across isolates without going through `EventBus`.

## Migrations

There is no in-app migration framework yet. The legacy directory rename
in `StorageService` is the only migration. Adding a new entity property
is safe because ObjectBox does it for free; renaming or removing
properties requires a `settingsBox` reset path that does not exist
today. Before changing entity shapes, add a new `version` field and a
branch in the repository to upgrade from the previous shape.

## Known gaps

- No schema versioning beyond what ObjectBox tracks internally.
- No automated test coverage for `StorageService` (no `test/` folder).
- `diagnoseAndLogFailure` writes to `debugPrint` only; nothing pipes
  that into Sentry.
- The `kvBox` mirror doubles the write cost on every settings change.
  Acceptable today, but worth revisiting if settings churn rises.
- `SettingsSnapshot` has 24 typed properties and keeps growing. Consider
  splitting it into per-feature sub-snapshots so the main isolate does
  not have to deserialize all of them on every read.
