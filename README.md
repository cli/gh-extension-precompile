# Action for publishing GitHub CLI extensions

A GitHub CLI extension is any GitHub repository named `gh-*` that publishes a Release with precompiled binaries. This GitHub Action can be used in your extension repository to automate the creation and publishing of those binaries.

## Go extensions

> [!Note]
> With the use of `actions/setup-go@v5` for Go extensions, **cache is enabled by default** as part of the [action's `v4` release](https://github.com/actions/setup-go/releases/tag/v4.0.0). The action won’t throw an error if the cache can’t be restored or saved. The action will throw a warning message but it won’t stop a build process. 

Create a workflow file at `.github/workflows/release.yml`:

```yaml
name: release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cli/gh-extension-precompile@v2
        with:
          go_version_file: go.mod
```

Then, either push a new git tag like `v1.0.0` to your repository, or create a new Release and have it initialize the associated git tag.

When the `release` workflow finishes running, compiled binaries will be uploaded as assets to the `v1.0.0` Release and your extension will be installable by users of `gh extension install` on supported platforms.

You can safely test out release automation by creating tags that have a `-` in them; for example: `v2.0.0-rc.1`. Such Releases will be published as _prereleases_ and will not count as a stable release of your extension.

To maximize portability of built products, this action builds Go binaries with [cgo](https://pkg.go.dev/cmd/cgo) disabled with the exception of [Android build targets](#building-for-android). To override cgo for all build targets, set the `CGO_ENABLED` environment variable:

```yaml
- uses: cli/gh-extension-precompile@v2
  env:
    CGO_ENABLED: 1
```

### Building for Android

`gh-extension-precompile@v2` introduces a breaking change by disabling `android-arm64` and `android-amd64` build targets by default due to [Go external linking requirements](https://github.com/cli/gh-extension-precompile/issues/50#issuecomment-2078086299).

To enable Android build targets:

1. `release_android` must be set to `true`
2. `android_sdk_version` must be set to a targeted [Android API level](https://developer.android.com/tools/releases/platforms)
3. `android_ndk_home` must be set to the path to Android NDK installed on Actions runner

   `cli/gh-extension-precompile` will use pre-installed Android tools on GitHub-managed runners by default; self-hosted runners will need to install and configure this input.

   _For more information on Android NDK installed on GitHub-managed runners, see [`actions/runner-images`](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md#android)_

### Customizing the build process for Go extensions

If you only need to customize the `go build` command, the `go_build_options` input parameter can include additional flags and arguments for all platforms:

```yaml
- uses: cli/gh-extension-precompile@v2
  with:
    go_build_options: './cmd/my-extension'
```

```yaml
- uses: cli/gh-extension-precompile@v2
  with:
    go_build_options: '-tags production'
```

For more complex customizations, see [Extensions written in other compiled languages](#extensions-written-in-other-compiled-languages) to provide a custom build script.

## Extensions written in other compiled languages

If you aren't using Go for your compiled extension, or your Go extension requires customizations to the build script, you'll need to provide your own script for compiling your extension:

```yaml
- uses: cli/gh-extension-precompile@v2
  with:
    build_script_override: "script/build.sh"
```

The build script will receive the release tag name as the first argument.

This script **must** produce executables in a `dist` directory with file names ending with: `{os}-{arch}{ext}`, where the extension is `.exe` on Windows and blank on other platforms. For example:
- `dist/gh-my-ext_v1.0.0_darwin-amd64`
- `dist/gh-my-ext_v1.0.0_windows-386.exe`

For valid `{os}-{arch}` combinations, see the output of `go tool dist list` with the Go version you intend to use for compiling.

Potentially useful environment variables available in your build script:

- `GITHUB_REPOSITORY`: name of your extension repository in `owner/repo` format
- `GITHUB_TOKEN`: auth token with access to GITHUB_REPOSITORY

## Checksum file and signing

This action can optionally produce a checksum file for all published executables and sign it with GPG.

To enable this, make sure your repository has the secrets `GPG_SECRET_KEY` and `GPG_PASSPHRASE` set. (Tip: you can use `gh secret set` for this; follow the instructions [here](https://github.com/crazy-max/ghaction-import-gpg) to obtain the correct secret values.) Then, configure this action like so:

```yaml
name: release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - id: import_gpg
        uses: crazy-max/ghaction-import-gpg@v5
        with:
          gpg_private_key: ${{ secrets.GPG_PRIVATE_KEY }}
          passphrase: ${{ secrets.GPG_PASSPHRASE }}
      - uses: cli/gh-extension-precompile@v2
        with:
          gpg_fingerprint: ${{ steps.import_gpg.outputs.fingerprint }}
```

## Support for Artifact Attestations

This action can optionally generate signed build provenance attestations for all published executables within `${{ github.workspace }}/dist/*`.

For more information, see ["Using artifact attestations to establish provenance for builds"](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds).

```yaml
name: release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write
  id-token: write
  attestations: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cli/gh-extension-precompile@v2
        with:
          generate_attestations: true
```

## Authors

- nate smith <https://github.com/vilmibm>
- the GitHub CLI team <https://github.com/cli>
