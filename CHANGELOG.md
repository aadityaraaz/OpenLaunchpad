# Changelog

## 0.1.0 — 2026-10-10

First public preview of OpenLaunchpad for macOS 26 and later.

### Launcher and appearance

- Native SwiftUI and AppKit launcher with Classic and Workspace interfaces.
- Fullscreen launcher and movable window with remembered position and outside-click dismissal.
- Vertical scrolling with lazy rendering, hidden fullscreen scroll indicators, and optional horizontal pages with persistent grids and sliding transitions.
- Configurable grid, app and folder labels, native Liquid Glass controls, wallpaper blur, cached aerial wallpaper stills, and system/light/dark appearance.
- Apps-style default icon, native icon appearance variants when the local system catalog is available, and optional Rocket icon.

### Search and organization

- Discover installed apps, custom directories, aliases, and external sources; deduplicate resolved paths and exclude nested helpers.
- Ranked app-name and alias search with initials, accents, abbreviations, camel case, and pinyin support.
- Drag icons onto other icons to create folders, merge folders, reorder items, and move between pages.
- Rename folders, hide and restore apps, edit aliases, and reveal apps in Finder.
- Multi-selection, batch organization, scoped reorganization, empty-slot preservation, and ascending/descending sorting by name, date added, last opened, or icon color.
- Pinned favorites, named layout profiles, and 30-step organization undo/redo.
- JSON backup/restore, read-only legacy Launchpad SQLite import, atomic persistence, and recovery handling.

### Activation and integration

- Configurable global shortcut, optional F4, keyboard navigation, wheel/swipe paging, page dots, and mouse side buttons.
- Hot corners, optional menu bar activation, login item registration, display selection, fullscreen Dock hiding, and delayed first-page reset.
- Experimental opt-in 3/4/5-finger pinch/spread activation with progress and cancellation.
- Native Dock drag data, explicit Add to Dock, app information, and conservative uninstall-to-Trash preview.
- Periodic app rescanning, volume/wake refresh, icon caching, and disconnected-source layout preservation.
- Manual update checks using an optional HTTPS release feed, restart, and quit actions.

### Validation and distribution

- 17 core checks and 24 integration checks pass.
- Optimized Apple silicon build for macOS 26+; Intel binaries are not included in this release.
- Downloadable application ZIP, drag-to-Applications DMG, and SHA-256 checksum manifest.
- Ad-hoc signed development app; no Developer ID signature or Apple notarization.
- Hardware-dependent gestures, physical outside-click behavior, multiple displays, and full system icon appearance cycles are not fully certified. No FPS guarantee is made.

See [feature coverage](docs/FEATURES.md) and [validation notes](docs/VALIDATION.md) for qualifications. The MIT license covers project code; Apple and third-party artwork retains its respective ownership.
