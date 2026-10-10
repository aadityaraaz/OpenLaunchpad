# Feature coverage

Research: [features](https://launchosapp.com/features/), [homepage and Pro features](https://launchosapp.com/), [release notes through v2.4.0](https://launchosapp.com/release.en), [FAQ](https://launchosapp.com/faq/), comparisons and public sitemap. This table describes implemented behavior, not a promise that every interaction is identical to LaunchOS.

See the [installed LaunchOS comparison and remaining gaps](LAUNCHOS-AUDIT.md) for the October 10, 2026 audit.

| Area | OpenLaunchpad implementation | Qualification |
|---|---|---|
| Dock/menu bar/global shortcut | Native Dock activation, menu bar icon/menu, custom Carbon hotkey | UI launch and global toggle checked |
| F4 | Optional Carbon key registration | Keyboard mappings / system Spotlight conflicts need hardware testing |
| Trackpad activation | Optional 3/4/5-finger raw pinch/spread recognizer; live opacity, cancel/commit | Experimental private ABI; off by default; no gesture suppression |
| Hot corners | Poll pointer, configurable delay, filter internal display corners | Multi-monitor hardware testing outstanding |
| Close behavior | Escape, blank background, toggle launch action, local spread gesture | Sheet cancellation and search composition respected |
| Browsing | Pages, vertical scroll, page dots, arrows, wheel, horizontal trackpad events, side buttons, mouse drag | Precision wheel debouncing; drag-edge page turn; no performance certification |
| Last position | Remember page, reset every open or after configured delay | Explicit empty slots preserved for manual page moves |
| Keyboard | Arrows, Return, Escape, ⌘←/→, ⌘K, ⌘comma, ⌘Q | IME marked-text Return not intercepted |
| Search | Ranked alias/name substring, prefix, initials, camel case, subsequence, accents and pinyin | Core regression checks pass |
| App organization | Manual/name/date/recent/color sorting; combined Apple/folder placement and ungroup rules for current/all/selected pages | Recent means opened through this launcher; ungrouping can expand selected pages |
| Multi-selection | ⌘ click, selection rectangle, Organize mode, batch move/group/hide | UI batch folder creation checked |
| Dock pinning | Native file URL drag provider and explicit Add to Dock using a bookmarked Dock tile | Dock transfer and preference write require additional manual validation |
| Extras | Pinned favorites, named layout profiles, 30-step undo/redo, app info, optional hidden-app search, local diagnostic export | Core profile and store undo/redo checks pass |
| Rename/hide | Aliases, folder title rename, hide, Settings restore | Real bundles are not renamed |
| Uninstall | Review app plus exact bundle-ID leftovers, Trash, reject running/system apps | Conservative cleanup; shared/group-container data and generic-name remnants omitted |
| Folders | Center-drop create/merge, child reordering, context move/dissolve, automatic dissolve at one child | Creation/merge/reordering verified in the native UI; no continuous insertion preview |
| Windows/displays | Fullscreen/windowed, main/active/pointer screen, adaptive grid, optional hide Dock | Draggable window remembers position; outside clicks dismiss it; multiple physical displays not available for testing |
| Grid | Independent 3–15 columns, 2–15 rows, adaptive icons | Compact grids omit labels where icons would otherwise overlap |
| Appearance | Classic search/grid/folders and five-tab settings, optional Workspace interface; native Liquid Glass, wallpaper still image, blur/tint, label toggles, appearance and icon treatments | Dynamic wallpaper playback and full OS icon mode integration incomplete |
| Launcher icons | Uses the installed macOS Apps icon at runtime; bundled search/six-tile fallback and original vector rocket | Apple icon resources are loaded from the OS, not distributed in the repository |
| Data | Atomic local JSON persistence, validated export/restore, bundle remapping | Layout and settings round trip checked |
| Native migration | Read-only legacy SQLite apps/items/groups import and page-tree traversal | Synthetic fixture checked; real legacy DB variants need testing |
| App sources | Defaults/custom paths, external drives, symlinks/aliases, path deduplication, skip nested bundles | Offline custom-source entries retained; external hot-plug testing outstanding |
| Auto refresh | 30-second scan, mount/unmount/wake scan; unchanged layouts and icons retained; background icon prefetch | Polling instead of filesystem watchers |
| Login | SMAppService registration/unregistration | Requires stable installed bundle; not enabled during validation |
| Options menu / updates | Sort direction, display/browse modes, reorganization, undo/redo, profiles, restart; optional HTTPS manifest version check | No release feed configured by default; no automatic installation; no paid gates |
| Localization | Unicode app names and Unicode search | Settings/interface English only |
| Licensing/privacy | MIT; no gates, activation, or telemetry | Network only for explicit update checks against the configured feed and the separate website audit script |
