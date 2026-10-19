# ClipShelf Implementation Plan

Goal: deliver the approved Russian native clipboard manager as a local Apple Silicon .app, source archive and instructions.
Architecture: SwiftUI/AppKit application, independently testable SwiftData repository and clipboard policies; no third-party dependencies or network access.
Spec: the user-approved plan in this conversation; copied into README feature contract.

## Constraints
Swift 6.2; macOS 15.4+; 500 ms polling; local storage; 1000 ordinary entries / 30 days; preserve favorites, snippets and collection entries; login disabled initially.

## Tasks
1. Core: models, payload identity, search/transforms, retention, recording policy, repository and image ownership. Write behavioral Swift Testing tests, run red, implement, run green.
2. System integration: typed pasteboard capture/write, permissions, exclusions, hotkeys, focused-app restore, login item. Test against isolated pasteboards and pure policies before integrating.
3. UI: Spotlight-style panel, sidebar/history/preview, keyboard handling, collection and snippet editors, preferences/onboarding and full preview. Verify by native UI inspection.
4. Delivery: reproducible build/sign/package script, app icon, source ZIP and Russian instructions. Run full tests/release build/sign verification and launch the .app independently.

## Review focus
- Do not record pre-launch clipboard, paused/excluded copies or sensitive markers.
- Do not paste to another app if original target vanished or focus changed.
- Preserve protected records during pruning; explicit full deletion may remove them.
- Keep image files and records consistent; show errors without resetting the database.
- Never repeat denied permission requests in the polling timer.

## Execution ledger
Ruling: fresh project has no Git repository; work in the dedicated work/ClipShelf directory and initialize its own codex/clipshelf branch.
Ruling: the user's explicit implementation request approves the presented plan; no extra plan review gate is needed.

Ruling: CLT omits SwiftDataMacros; use native Core Data SQLite with Codable library snapshots. This preserves behavior and buildability without Xcode.

## Completion ledger
- Core, system integration and UI implemented. Full behavioral suite: 18 checks, 0 failures.
- Swift Testing cannot import missing _Testing_Foundation development module in this CLT installation. Ruling: keep tests dependency-free as ClipShelfChecks executable with fail-fast exit status and real repository/isolated-pasteboard assertions.
- Independent read-only review completed. Source-transition leak, first-save rollback and HTML-only capture were reproduced by failing tests and fixed; 18-check suite passed afterward.
- Copy-only restores original app focus; target disappearance/focus-loss during insertion gives copy-only guidance.
- Release app built for arm64, ad-hoc signed, strict codesign verification and plist validation passed.
- Packaged app launched outside SwiftPM; dark/light layouts, search, arrows, collection creation, settings, long text and image filtering/preview inspected using native UI.
- Ruling: discard clipboard generations on app activation because NSPasteboard does not reliably expose writer identity. Cost: a fast copy/switch can be omitted; prevents attribution to an allowed app after copying in an excluded app.
- Ruling: no upstream/base branch exists in this fresh project; preserve local source and deliver artifacts instead of an unrelated merge/PR workflow.
- System clipboard recording, cross-app injected paste, permission denial/revocation and login after reboot remain manual acceptance checks requiring user permissions. No system permission was granted automatically.
