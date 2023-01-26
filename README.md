# Action for publishing GitHub CLI extensions

A GitHub CLI extension is any GitHub repository named `gh-*` that publishes a Release with precompiled binaries. This GitHub Action can be used in your extension repository to automate the creation and publishing of those binaries.

## Go extensions

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
      - uses: actions/checkout@v3
      - uses: cli/gh-extension-precompile@v1
        with:
          go_version: "1.16"
```

Then, either push a new git tag like `v1.0.0` to your repository, or create a new Release and have it initialize the associated git tag.

When the `release` workflow finishes running, compiled binaries will be uploaded as assets to the `v1.0.0` Release and your extension will be installable by users of `gh extension install` on supported platforms.

You can safely test out release automation by creating tags that have a `-` in them; for example: `v2.0.0-rc.1`. Such Releases will be published as _prereleases_ and will not count as a stable release of your extension.

To maximize portability of built products, this action builds Go binaries with [cgo](https://pkg.go.dev/cmd/cgo) disabled. To override that, set the `CGO_ENABLED` environment variable:

```yaml
- uses: cli/gh-extension-precompile@v1
  env:
    CGO_ENABLED: 1
```

## Extensions written in other compiled languages

If you aren't using Go for your compiled extension, you'll need to provide your own script for compiling your extension:

```yaml
- uses: cli/gh-extension-precompile@v1
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
      - uses: actions/checkout@v3
      - id: import_gpg
        uses: crazy-max/ghaction-import-gpg@v5
        with:
          gpg_private_key: ${{ secrets.GPG_PRIVATE_KEY }}
          passphrase: ${{ secrets.GPG_PASSPHRASE }}
      - uses: cli/gh-extension-precompile@v1
        with:
          gpg_fingerprint: ${{ steps.import_gpg.outputs.fingerprint }}
```

## Authors

- nate smith <https://github.com/vilmibm>
- the GitHub CLI team <https://github.com/cli>
