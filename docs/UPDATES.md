# Release feed

Advanced settings accepts an optional HTTPS URL returning this JSON:

```json
{
  "version": "0.2.0",
  "url": "https://your-project.example/releases/0.2.0"
}
```

The options menu's Check for Updates action compares the published version with the installed bundle version. If newer, View Release opens the HTTPS page in the default browser. No app list, paths, or layout data are sent. No automatic download or installation occurs. The feed is blank by default because this project does not yet have a public release host. A request has a 15-second timeout; invalid responses, unsafe download URL schemes, and manifests over 1 MB are rejected.

Build and test the release, publish signed/notarized assets, and configure the feed when a maintainer establishes public hosting.
