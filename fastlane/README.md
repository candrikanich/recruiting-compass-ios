fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios pull_metadata

```sh
[bundle exec] fastlane ios pull_metadata
```

Read-only: download the live App Store listing text into fastlane/metadata

### ios pull_screenshots

```sh
[bundle exec] fastlane ios pull_screenshots
```

Read-only: download the live App Store screenshots into fastlane/screenshots (gitignored)

### ios push_metadata

```sh
[bundle exec] fastlane ios push_metadata
```

Upload fastlane/metadata text to the editable App Store version (no screenshots, no submit)

### ios push_screenshots

```sh
[bundle exec] fastlane ios push_screenshots
```

Replace App Store screenshots with planning/app-store/{iphone,ipad} (no metadata, no submit)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
