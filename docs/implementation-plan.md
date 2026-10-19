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
