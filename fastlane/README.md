fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### configure_store_records

```sh
[bundle exec] fastlane configure_store_records
```

Configure truthful first-release App Store declarations for both apps

----


## Mac

### mac screenshots

```sh
[bundle exec] fastlane mac screenshots
```

Regenerate App Store screenshots for local review and upload

### mac verify_release_build

```sh
[bundle exec] fastlane mac verify_release_build
```

Validate the macOS release target without signing

### mac build_app_store

```sh
[bundle exec] fastlane mac build_app_store
```

Build a signed macOS package for App Store Connect

### mac release

```sh
[bundle exec] fastlane mac release
```

Upload the private local-AI macOS release and submit it for review

### mac publish_built

```sh
[bundle exec] fastlane mac publish_built
```

Publish the already-built macOS package, listing, and screenshots

### mac upload_binary

```sh
[bundle exec] fastlane mac upload_binary
```

Upload the already-built macOS package without changing listing metadata

----


## iOS

### ios refresh_profiles

```sh
[bundle exec] fastlane ios refresh_profiles
```

Refresh App Store profiles for the host app and private keyboard App Group

### ios verify_release_build

```sh
[bundle exec] fastlane ios verify_release_build
```

Validate the iOS app and keyboard extension without signing

### ios build_app_store

```sh
[bundle exec] fastlane ios build_app_store
```

Build a signed iOS archive containing the no-Full-Access keyboard

### ios release

```sh
[bundle exec] fastlane ios release
```

Upload the private local-AI iOS release and submit it for review

### ios publish_built

```sh
[bundle exec] fastlane ios publish_built
```

Publish the already-built iOS package, listing, and screenshots

### ios upload_binary

```sh
[bundle exec] fastlane ios upload_binary
```

Upload the already-built iOS package without changing listing metadata

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
