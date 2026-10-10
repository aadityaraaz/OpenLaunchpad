# Validation

Host: macOS 27.0.1 (26A434), Apple silicon, Swift 6.4, Command Line Tools with the macOS 27 SDK.

## Automated

Run `make test`. Latest run: 17 core checks and 24 integration checks passed.

- CoreChecks exercises grouping/dissolution, folder extraction, merging, hiding/restoration, malformed layouts, ordered batch movement, JSON backup validation, reconciliation, exact/prefix/initial/alias search, accents/camel case/pinyin, pinch/spread commit/cancel, explicit page slots, backward-compatible preferences, disconnected app sources, named profiles, and portable backup remapping with explicit page gaps.
- `OpenLaunchpad --self-test` uses temporary synthetic app bundles and a temporary SQLite database to check discovery, symlink deduplication, helper exclusion, legacy folder/page import, local persistence, malformed database rejection, uninstall path protection, favorites undo/redo, named profile persistence, vertical defaults, ascending/descending dates, cache invalidation, and HTTPS release-manifest validation. It never removes a real installed app.
- `make app` builds an optimized executable, creates a native .app bundle with a generated launcher icon, and ad-hoc signs it. The signature is local development signing, not Developer ID notarization.

## UI checks

Performed through the native application on this Mac:

- Opened the installed LaunchOS app and inspected its launcher, folder view, menus, and General/Interface/Apps/Advanced/About settings.
- Real installed applications and icons rendered in the Classic seven-column, five-row paged grid with large search, plain page dots, and native glass background.
- Search for Calculator returned one result; Return launched Calculator and dismissed the launcher.
- ⌃⌥Space from Calculator reopened the launcher and focused search.
- Organize mode selected Calculator and Calendar; Create folder produced a folder containing both applications.
- Opening that folder displayed its two children. Clicking the title opened rename; saving changed the title to Everyday.
- Escape returned to the main grid; ⌘comma opened the Settings window.
- Compact grouped settings rows, trailing switches, and five tabs inspected against the supplied reference. Interface now uses Full Screen/Window thumbnails, order/browsing radio controls, numeric grid fields, and Hide Names. Radio selection, a column increment, and label toggling were checked through the UI.
- Selected Vertical scrolling; native scrollbar moved from 0 to approximately 0.75 after a downward scroll, exposing the remaining applications.
- Dragged the top grip; the saved native window frame changed to `{{1114, 491}, {900, 700}}` and survived restart.
- Ellipsis menu exposed sort direction, display/browsing modes, reorganization, profiles, undo/redo, updates, restart, and quit.
- Check for Updates displayed the missing-feed configuration message without a network request.
- Restart created a new process and preserved the saved frame. Shortcut registration showed no conflict alert.

Additional comparison and regression checks on October 10, 2026:

- Inspected LaunchOS 2.4.0 (485), including all five settings tabs, fullscreen folders, app/folder context menus, sorting submenus, and the combined reorganization sheet. Its settings and layout were left unchanged.
- Fullscreen now has a compact centered search field, a bounded grid with larger icons, a wallpaper-backed material, and a centered folder panel sized to its contents. Window mode retains its larger search field and dark material.
- Dragged Activity Monitor onto AirPort Utility in fullscreen and observed a new folder. Dragged App Store onto that folder and observed three children. Reordered App Store ahead of AirPort Utility inside it and verified the saved child order. Undid all three changes.
- Repeated app-on-app folder creation in window mode and undid it. Native mouse tracking provides a moving icon preview and a highlighted destination without updating the SwiftUI tree on each mouse movement.
- Checked the new reorganization sheet's current/all/selected-page choices. Selected-page checkboxes and the complete explanatory text fit the sheet; canceled without applying changes to the real library.
- Checked fullscreen horizontal paging with ⌘→ and second-page app content. Restored fullscreen vertical scrolling afterward.
- Six additional integration regressions cover target-slot preservation during grouping, child reordering, moving out of folders, restoring folder/page after search, and reorganization restricted to selected pages.

Fullscreen follow-up after the user's 4:07 PM screenshot:

- Corrected screen-height-stretched rows: continuous browsing now uses a stable icon-based row height; paged mode centers its bounded rows. Fullscreen labels are 16 pt and search is 300 × 44 pt. A 72 pt bottom inset reserves space when the Dock is visible.
- Replaced the live wallpaper Gaussian blur with an asynchronously pre-rendered, cached texture bounded to 2048 pixels on its longest side. File loading and blur processing run in a background actor; scrolling does not apply a wallpaper blur effect each frame.
- Restarted the optimized app and inspected the corrected fullscreen grid. Scrolled to the bottom and back to the top, searched Calculator, cleared search, opened/closed Everyday, switched to pages, navigated to page two/back, and restored vertical scrolling. All 41 existing checks and strict signature verification passed again.
- This establishes functional checks and removal of the expensive live blur path. It is not a measured FPS claim; physical trackpad momentum and display refresh-rate behavior still need user/hardware validation.

Outside-click dismissal uses global mouse monitoring and application deactivation. The UI driver posts application-local events, so physical outside clicks and Carbon shortcut delivery still need manual confirmation. Scrolling was functionally checked, but no frame-rate guarantee or broad hardware performance certification is claimed.

Fullscreen calibration against the user's 4:14 PM LaunchOS screenshot (supersedes the earlier size choices):

- Measured the installed reference at 3008 × 1692 points: 240 × 38 pt search, a 1760 pt wide seven-column grid, 128 pt icon frames, 12 pt labels, five evenly distributed rows, and 8 pt page dots spaced 20 pt apart. Applied those dimensions to Classic fullscreen; smaller displays retain adaptive icon sizing.
- Observed LaunchOS converting vertical wheel input into horizontal pages. Selected Pages in OpenLaunchpad and verified down/up wheel input changes pages in both directions. Page changes now slide horizontally with a 0.28 second transition; Reduce Motion bypasses the slide.
- Matched the compact folder thumbnail with children aligned at its upper left and reserved 108 pt below the page indicators for the visible Dock.
- Corrected the stale Sonoma background returned by NSWorkspace on this Mac by resolving the selected, already downloaded aerial wallpaper and caching a blurred final-frame still. Missing or unsupported aerial metadata falls back to NSWorkspace. Per-display aerial overrides are not covered by this resolver.
- Rebuilt and restarted the optimized app; all 17 core and 24 integration checks passed, as did strict local signature verification. The existing library and folders were preserved, so the reference's app order and page count differ. No claim of pixel-perfect equivalence, measured FPS, or identical physical trackpad timing is made.

Hardware-specific integrations and destructive operations are not represented as tested: physical multifinger gestures, side buttons, real Dock drop / explicit Dock preference write, multi-display arrangements, F4 variants, login registration, and real app removal require separate manual validation. See FEATURES.md for feature-level qualifications.

Page-transition performance follow-up:

- Replaced page-keyed grid insertion/removal with a persistent horizontal deck. Paged grids use eager layout so icon/native interaction views are mounted before navigation; continuous scrolling retains lazy layout. Only the deck's offset animates when the page changes.
- Unified slide and swipe-release timing at 0.24 seconds, removed no-op boundary page mutations, and excluded inactive pages from hit testing, accessibility, and marquee frame collection. Keeping pages mounted trades additional initial view allocation for less work during navigation.
- Restarted the release build, inspected window rendering, switched to fullscreen, navigated 1 → 2 → 3 with keyboard input, and returned 3 → 2 → 1 using wheel input. Correct content and fixed column spacing were verified, including the sparse final page. Automated checks and strict signature verification passed. Physical trackpad frame pacing remains unmeasured.

Settings Sort By popup follow-up:

- Replaced menu toggles that inherited SettingsSwitchStyle with a native single-selection menu picker. The old custom toggle layout produced extra controls, missing labels, and oversized menu rows.
- Rebuilt and restarted the release app; opened Interface → Sort By and visually verified five compact labeled options with one selection checkmark. Selected Name, verified Order controls became enabled, then restored Custom and verified they became disabled. Strict signature verification passed.

Fullscreen scrollbar follow-up:

- Hid launcher scroll indicators in fullscreen; window-mode indicators remain available. Vertical scrolling remains enabled.
- Rebuilt and restarted the release app in fullscreen continuous mode. Scrolled to later applications and visually verified that the inset scrollbar is gone; wheel input still moves the content. Strict signature verification passed.

Default logo and system appearance follow-up:

- Load the user's supplied `/System/Applications/Apps.app/Contents/Resources/AppIcon.icns` directly and copy it into the local app bundle during builds when available. Verified the bundled file is byte-identical to that source. Hosts without the system file retain the generated fallback.
- New preferences default to System appearance. Selected Apps Icon and System appearance for the current library through Settings. Visually checked Light appearance, then restored System; the launcher tint and aerial variant selection now use SwiftUI's effective color scheme.
- Release build, all 41 automated checks, and strict signature verification passed. Restarted the updated app. The supplied ICNS artwork is preserved; no alternate logo artwork is synthesized.

Adaptive app-icon follow-up:

- The system Apps asset catalog contains AppIcon IconImageStack variants for Aqua, Dark Aqua, and tintable appearance. Local builds now copy that catalog when present and declare CFBundleIconName = AppIcon; the static ICNS remains the fallback. No Apple catalog is added to repository source.
- Removed the fixed NSApp.applicationIconImage override for the default icon. macOS now owns rendering the bundle icon and its icon-appearance variants; the optional Rocket continues to use its explicit image. Native icon appearance is controlled by macOS, separately from an app-only UI appearance override.
- Verified the local catalog is byte-identical to the system source, the bundle names AppIcon, and the release build and strict signature verification pass. Restarted the app. A full system light/dark/tint cycle has not been visually verified; drawing Bundle.image(forResource:) under Aqua and Dark Aqua yields the same static fallback, so that preview is not evidence of Dock adaptation.
