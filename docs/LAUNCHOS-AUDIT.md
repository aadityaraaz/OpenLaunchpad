# LaunchOS comparison — October 10, 2026

Reference: installed LaunchOS **2.4.0 (485)** on this Mac, inspected through its native interface. Reviewed its fullscreen launcher, folder view, ellipsis menu, app/folder context menus, all five settings tabs, and reorganization sheet. Inspection did not change LaunchOS preferences or its layout. Paid features visible during the trial were included.

Cross-checked the public [feature page](https://launchosapp.com/features/) and [release history](https://launchosapp.com/release.en). The broader [website inventory](website-audit.json) records 155 successfully fetched sitemap pages, including translations and policy/marketing pages. This is a comparison of observable behavior and local implementation, not an inspection of LaunchOS internals or a claim to have tested every hardware combination.

## Problems found and fixed

| Finding in OpenLaunchpad | Result |
|---|---|
| Fullscreen reused the window toolbar and distributed small icons across the entire display | Compact centered fullscreen search, bounded grid, larger adaptive icons |
| Fullscreen glass could become a flat gray surface | Cached wallpaper texture, including the selected local aerial when available; window mode retains a darker material |
| Folder view reused the main fullscreen grid | Centered folder title and rounded panel sized for the child rows |
| App icon click control intercepted dragging; overlapping drop handlers competed | Native mouse tracking with threshold, moving icon preview, destination highlight, one internal drop operation |
| Dropping sorted apps switched to the old manual order | Freeze visible order before switching to manual organization |
| Creating a folder could shift it away from the target slot | Account for removed source slots before inserting the folder |
| Dragging within a folder appended instead of reordering | Insert dragged children at the destination position |
| Clearing search or closing a folder jumped to page one | Restore the previous page and folder when returning |
| Reorganization offered only separate all-layout shortcuts | Combined sort, Apple placement, folder placement, and ungroup rules, scoped to current/all/selected pages |
| Folder context menu lacked page movement | Folder Move to Page and New Page actions |

Native UI checks created a folder by dropping Activity Monitor onto AirPort Utility, merged App Store into it, and reordered its children. Checked folder creation in both fullscreen and window mode; undid the test layout changes. Verified fullscreen second-page navigation and restored vertical browsing. Automated regressions cover the ordering, search return, and scoped reorganization logic. See [validation](VALIDATION.md).

## Launcher and menus

| Observed LaunchOS function | OpenLaunchpad status |
|---|---|
| Fullscreen and movable window; search/grid/page dots | Implemented; Classic fullscreen calibrated to the reference's 240 × 38 pt search, 1760 pt grid, 128 pt icon frames, and 12 pt labels |
| Paged or continuous browsing | Implemented; current user configuration uses horizontal sliding pages with wheel navigation, matching the reference. New-install default remains vertical scrolling. |
| App-on-app folder creation, folder merge/extraction, child organization | Implemented; creation/merge/reorder tested; physical cross-page edge dragging needs further validation |
| Custom/name/date added/date last opened ordering and directions | Implemented; last-opened tracking covers launches through OpenLaunchpad |
| App menu: Open, Finder, Dock, Info, Rename, Hide, Uninstall, Move to folder/page | Implemented; actual Dock transfer and real uninstall were not performed |
| Folder menu: Open, Rename, page movement, Ungroup | Implemented |
| Ellipsis: settings, sort, display/browse, reorganize, updates, restart, quit | Implemented; updater is manual and requires a configured feed |
| Reorganize: current order/name/date/recent/color; Apple before/mixed/after; folders before/mixed/after; ungroup; page scope | Implemented as a combined sheet; scoped-layout regression passes |
| Command selection and drag selection | Implemented; batch create/move/hide and Organize mode available |
| Return to previous location after search | Implemented in this pass; page and folder restoration tested |
| Licensing/trial/activation commands | Omitted intentionally: MIT, no paid gates |

## All settings tabs

| Tab and observed controls | Coverage and limits |
|---|---|
| **General — Launch:** login, hotkey, F4, trackpad, hot corner; command multi-selection hint | Implemented. Trackpad supports individual 3/4/5-finger modes; reference's combined “4 or 5” choice is missing. Physical input compatibility remains unverified. |
| **General — Appearance:** menu bar icon, Add to Dock, launcher icon variants | Implemented. Uses the OS Apps icon when available, a code-generated fallback, and an original rocket. Reference branding is not bundled. |
| **Interface — Display:** Full Screen/Window, Hide Dock | Implemented. Settings use display thumbnails; native fullscreen window respects the selected screen. |
| **Interface — Layout:** sort/order, paged/scroll, grid columns/rows, fill empty slots, hide names | Implemented; shared reorganization sheet added. App/folder label switches are also available separately. |
| **Interface — Background:** wallpaper/glass, wallpaper blur | Implemented with material intensity and appearance controls. Current wallpaper is a still image; exact reference wallpaper/color rendering is not guaranteed. |
| **Apps:** application sources, adding/removing paths, hidden apps, search hidden | Implemented; defaults, aliases/symlinks, and disconnected-source retention covered by checks. |
| **Advanced — Display/position:** display selection, timed first-page reset | Implemented; pointer/main/active display selection. Physical multiple-display validation outstanding. |
| **Advanced — Option uninstall** | Implemented with a review step and Trash; conservative exact bundle-ID leftovers only. No real removal performed. |
| **Advanced — Layout:** native restore, import/export, reorganize | Own JSON backup and read-only legacy Launchpad SQLite import implemented. LaunchOS's opaque `.launchos` format is not supported. |
| **Advanced — Updates/logs:** automatic checks, update information, export logs | Diagnostic export and manual HTTPS version check implemented. Automatic checking/downloading/installing missing. |
| **About:** version, website/social links, policies, updates, feedback | Own version/license/project information present. Product-specific LaunchOS links and activation are intentionally absent. |

## Remaining work, ranked

1. **Drag and animation polish.** Internal dragging is functional, but continuous animated insertion/reflow and the exact source-to-folder zoom animation are not implemented. Native preview and destination highlight are present. Cross-page dragging, scrolling while dragging, extracting to an outside area, and physical Dock drops need a broader manual pass.
2. **Gesture parity.** Add combined 4-or-5-finger mode and system hot-corner conflict diagnostics. Global pinch/spread currently drives opacity; exact progress-driven scaling is incomplete. Test built-in/external trackpads, wake/hot-plug, Show Desktop conflicts, F4 mappings, side buttons, and multi-display corners. Core recognition tests are not hardware proof.
3. **System appearance integration.** Complete live following of all OS icon color/tint modes and their cache invalidation. Current icons use NSWorkspace with refresh and optional local treatments. Refine material/spacing/animation across resolutions, light/dark modes, Reduce Motion, and Reduce Transparency. No frame-rate certification has been done.
4. **Release updater.** Implement optional automatic checks and a verified delivery/install flow. Requires a public release feed and distribution setup. Present builds are ad-hoc signed; Developer ID signing/notarization is not configured.
5. **Localization.** Unicode/pinyin search works, but the interface is English. Translated settings/help remain missing.
6. **Backup compatibility.** Legacy SQLite import is tested using synthetic fixtures; real OS database variants need coverage. Importing LaunchOS's proprietary backup needs an independently understood format; own portable JSON backups already work.
7. **Uninstall differences.** Long-press uninstall is missing. Option and context-menu uninstall exist. Shared/group containers and generic app-name remnants are deliberately excluded from cleanup because ownership cannot be inferred safely.

Wallpaper playback is also limited to a still image. This is a local limitation, not a verified claim that LaunchOS supports animated wallpaper playback.

## Additional OpenLaunchpad features

Pinned favorites, named layout profiles, 30-step undo/redo, separate folder/app label controls, app information, optional hidden-app search, reverse paging direction, and an optional Workspace interface. Organization and premium-style controls are freely available.

## Evidence limits

Working code is distinct from verified interaction. `make test` passes **17 core + 24 integration checks**; release build and strict local signature verification pass. Native UI confirms fullscreen/window rendering, folder creation/merge/reorder, context menus, the reorganization sheet, search/launch, and page navigation. Real Dock changes, login registration, physical outside clicks, permission-dependent gestures, multiple physical displays, and actual uninstallation are not certified by these checks. No LaunchOS source, artwork, or opaque backups were extracted.
