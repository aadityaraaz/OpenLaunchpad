# Release feed

Advanced settings accepts an optional HTTPS URL returning this JSON:

```json
{
  "version": "0.2.0",
  "url": "https://your-project.example/releases/0.2.0"
}
```

The options menu's Check for Updates action compares the published version with the installed bundle version. If newer, View Release opens the HTTPS page in the default browser. No app list, paths, or layout data are sent. No automatic download or installation occurs. The feed is blank by default; manual downloads are available on [GitHub Releases](https://github.com/aadityaraaz/OpenLaunchpad/releases). A request has a 15-second timeout; invalid responses, unsafe download URL schemes, and manifests over 1 MB are rejected.

Run `make release` to build the optimized app, package ZIP/DMG assets, and generate SHA-256 checksums in `dist/releases`. Current public previews are ad-hoc signed, not notarized. Developer ID signing and notarization require maintainer credentials. Configure an HTTPS JSON feed when one is available; a GitHub release webpage is not itself a JSON feed.
