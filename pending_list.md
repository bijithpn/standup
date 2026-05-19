 Not fully complete:

  - flutter test cannot pass because there is no test/ directory.
  - Video-call detection is best-effort frontmost-app detection, not deep
    meeting-state detection.
  - macOS Focus/DND detection remains best-effort via existing native
    fallback.
  - Manual checklist items like “Dashboard opens from tray icon,” “strict
    mode prevents skipping,” and “notifications sound behavior” need hands-
    on UI verification.
  - Some previously existing broad changes were already in the worktree
    before my edits, so I did not rewrite every related service from
    scratch.