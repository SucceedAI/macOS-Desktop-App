fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac screenshots

```sh
[bundle exec] fastlane mac screenshots
```

Regenerate App Store screenshots for local review and Fastlane upload

### mac verify_release_build

```sh
[bundle exec] fastlane mac verify_release_build
```

Validate the macOS app compiles without requiring local signing secrets

### mac build_app_store

```sh
[bundle exec] fastlane mac build_app_store
```

Build a signed macOS package for App Store Connect

### mac upload_metadata

```sh
[bundle exec] fastlane mac upload_metadata
```

Upload metadata and screenshots only, without uploading a binary

### mac release

```sh
[bundle exec] fastlane mac release
```

Build the macOS package, upload listing assets, and leave review submission manual

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
