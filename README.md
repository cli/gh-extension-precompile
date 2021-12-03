# Action for releasing precompiled gh extensions

[gh](https://github.com/cli/cli) is GitHub on the command line. It can be extended with both first and third-party user-defined commands via `gh extension`. These commands can be written in a compiled language like Go or Rust and this action exists to automate the release of such compiled extensions, making it possible to deliver binaries to users without having to worry about them having any kind of local toolchain in place.

## Quickstart (golang)

Assuming your extension is written in Go and you don't care about signing your releases, you can incorporate this release into your extension's repo by adding a workflow file like this at `.github/workflows/release.yml`:

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
      - uses: actions/checkout@v2
      - uses: cli/gh-extension-precompile@latest
```

Then, from the command line, push a tag to initiate a release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Within a few minutes, users of your extension will be able to install your latest version.

## Prereleases

To test out a release, you can push a prerelease tag like `v2.0.0-pre0`. This will create a prerelease and not result in an upgrade notice for your users.

## Go version

By default, Go 1.16 will be used to build your extension. To change this, set `go_version`:

```yaml
- uses: cli/gh-extension-precompile@v1
  with:
    go_version: "1.17"
```

## Using with another language

If you aren't using Go, you'll need to provide your own script for compiling your extension and configure this action to use `build_script_override`:

This script must produce executables in a `dist` directory all named with a suffix in the format: `platform-architecture`. For example: `my-extension_v1.0.0_windows-arm64`. Front matter in the filename is ignored by `gh`; only the suffix is matched.

For examples of platform/architecture names, see [this list](https://github.com/cli/cli/blob/trunk/pkg/cmd/extension/manager.go#L650).

Your build script will receive the tag to compile against as its first argument (`$1`).

```yaml
- uses: cli/gh-extension-precompile@v1
  with:
    build_script_override: "script/build.sh"
```

Potentially useful environment variables exposed to your build script:

- `GITHUB_REPOSITORY`: name of your repo in `owner/repo` format
- `GITHUB_TOKEN`: auth token being used to run this workflow

## Signing

This action can produce a checksum file for all generated executables and then sign it with GPG.

To enable this, make sure your repository has the secrets `GPG_SECRET_KEY` and `GPG_PASSPHRASE` set. Then, configure this action like so:

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
      - uses: actions/checkout@v2
      - id: import_gpg
        uses: crazy-max/ghaction-import-gpg@v3
        with:
          gpg-private-key: ${{ secrets.GPG_PRIVATE_KEY }}
          passphrase: ${{ secrets.GPG_PASSPHRASE }}
      - uses: cli/gh-extension-precompile@v1
        with:
          gpg_fingerprint: ${{ steps.import_gpg.outputs.fingerprint }}
```

## Author

nate smith <vilmibm@github.com>
