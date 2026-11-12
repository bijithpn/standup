import Foundation

// Debug-only: lets `flutter run` from VS Code / a terminal trigger macOS
// privacy prompts (Calendar, ...).
//
// macOS attributes privacy requests to the "responsible process" — the program
// that launched the app. Under `flutter run` that is VS Code or the terminal,
// which has no Calendar entitlement, so macOS silently refuses to prompt.
// We re-spawn ourselves with responsibility disclaimed so BreakMate is its own
// responsible process. The original process stays alive as a thin relay (so
// `flutter run` keeps its handle) and the child inherits stdout/stderr.
// Release builds are launched by Finder/launchd and never go through this.

#if DEBUG

@_silgen_name("responsibility_spawnattrs_setdisclaim")
private func responsibility_spawnattrs_setdisclaim(
  _ attr: UnsafeMutablePointer<posix_spawnattr_t?>, _ disclaim: Int32
) -> Int32

private var disclaimedChild: pid_t = 0

enum DebugDisclaim {
  private static let marker = "BREAKMATE_DISCLAIMED"

  /// Returns normally when this process should run the app. Otherwise it
  /// spawns the disclaimed copy, relays until it exits, and never returns.
  static func relaunchIfNeeded() {
    let env = ProcessInfo.processInfo.environment
    // Launched by launchd (Finder / `open`) or already the disclaimed copy.
    if env[marker] != nil || getppid() == 1 { return }

    var attr: posix_spawnattr_t? = nil
    guard posix_spawnattr_init(&attr) == 0,
      responsibility_spawnattrs_setdisclaim(&attr, 1) == 0
    else { return }

    var childEnv = env
    childEnv[marker] = "1"
    let argv: [UnsafeMutablePointer<CChar>?] =
      CommandLine.arguments.map { strdup($0) } + [nil]
    let envp: [UnsafeMutablePointer<CChar>?] =
      childEnv.map { strdup("\($0.key)=\($0.value)") } + [nil]

    var pid: pid_t = 0
    let rc = posix_spawn(&pid, CommandLine.arguments[0], nil, &attr, argv, envp)
    guard rc == 0 else { return }  // fall back to running in-process
    disclaimedChild = pid

    for sig in [SIGINT, SIGTERM, SIGHUP, SIGQUIT] {
      signal(sig) { s in if disclaimedChild > 0 { kill(disclaimedChild, s) } }
    }

    var status: Int32 = 0
    while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
    exit(
      (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f))
  }
}

#endif
