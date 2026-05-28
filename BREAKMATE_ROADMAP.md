# BreakMate Improvement Roadmap

## 📊 Project Analysis & Strategic Direction

BreakMate is currently a high-performance, multi-isolate Flutter application. To transition from a "utility reminder" to a "premium wellness companion," we need to focus on three pillars: **Energy Efficiency**, **Cross-Platform Parity**, and **Engagement Depth**.

### 🔍 Key Optimization Opportunities

1. **GPU Energy Throttling:** Desktop companions often drain laptop batteries. We should implement a "Low Power Mode" that throttles the Flame engine FPS when the companion is hidden behind other windows or when the system is on battery.
2. **IPC Robustness:** The Current `IpcBridge` is functional but lacks strong typing. Moving to a more formal message-passing interface will prevent runtime errors during cross-isolate state sync.
3. **Asset Strategy:** Dynamic font loading and SVG-based icons would reduce the binary footprint and memory usage on high-DPI displays.

---

## 📋 Task Board

### 🟢 Doing Right Now

- [ ] **Phase 3.6:** **Contextual Wellness Engine**: Use rule-based logic to provide "Smart Tips" based on the user's active application (e.g., suggest wrist stretches if typing for 1 hour straight).

### 🟡 Pending (To Do)

#### Phase 4: Future Ecosystem Features

- [ ] **Phase 4.3:** **Award System**: Implement a Gamified Unlocks system (e.g., earn new pet breeds or props after completing X strict breaks).
- [ ] **Phase 4.4:** **Auto-Status Sync**: Automatically update Slack/Microsoft Teams status to "Away (On Break)" when a break starts.
- [ ] **Phase 4.5:** **BreakMate Mobile Remote**: Build a basic Flutter mobile companion to track breaks while away from the computer.
- [ ] **Phase 4.6:** **Team Wellness Leagues**: Shared leaderboards for office teams to encourage group break habits.

---

### 🔵 Completed

- [x] **Phase 3.5:** **Interactive Break Activities**: Added guided breathing (4-7-8 technique) and eye sync (20-20-20 rule) mini-activities to the full-screen break overlay via new `ActivitiesBreakTemplate`. Available as 'Activity Studio' in the Break Template settings.

- [x] **Phase 2.3:** Implement **Automated Integration Tests** for cross-isolate IPC events (ensuring Break -> Companion sync never breaks).

- [x] **Phase 2.2:** Unified Native Interface: Create a common abstraction layer for `MacOSBridge` and `WindowsBridge` to ensure feature parity across platforms.

- [x] **Phase 1.7:** Implement **Isolate Pooling** for heavy analytical calculations to keep the Main isolate frame-budget clean.

- [x] **Phase 1.6:** Optimize `Satoshi` font loading using `google_fonts` dynamic fetching or subsetting to reduce initial app download size.

- [x] **Phase 1.5:** Implement **Adaptive FPS Throttling** in `CompanionGame` to reduce GPU usage when the window is inactive or the system is on battery.
- [x] **Phase 4.2:** Add System Media Control (auto-pause Spotify/Apple Music when a break starts).
- [x] **Phase 4.1:** Build a Productivity vs. Wellness weekly dashboard.
- [x] **Phase 3.4:** Map micro-breaks (posture/eye blink tracking) to Companion animations (stretching/blinking) instead of OS popups.
- [x] **Phase 3.3:** Add visual "On-Air/DND" indicator to the Companion and Tray Icon when `MeetingDetectedEvent` fires.
- [x] **Phase 3.2:** Integrate gentle audio fade-in (`lofi_1.mp3`) during the `PreBreakWarningOverlay` transition.
- [x] **Phase 3.1:** Implement "Pet Fatigue" in `PetBehaviorBrain` (shift probability to sleeping animations if `totalWorkToday` > 3-4 hours).
- [x] **Phase 2.1:** Refactor the 900+ line `TimerEngine` into smaller, focused classes (`TimerState`, `TimerRepository`, and `TimerContextManager`).
- [x] **Phase 1.4:** Move OS-level polling (`ActivityMonitor`, `SmartDetectionService`) to a background Dart Isolate to prevent UI micro-stutters.
- [x] **Phase 1.3:** Implement aggressive asset eviction (`Flame.images.clear()`) when a user switches pet themes.
- [x] **Phase 1.2:** Apply `RepaintBoundary` to `countdown_timer.dart` and any fast-ticking UI elements to prevent FlameGame canvas re-renders.
- [x] **Phase 1.1 (Performance):** Fix IPC Tick Debouncing in `TimerEngine` and Overlays.
- [x] Initial Architectural Analysis & Roadmap Generation
