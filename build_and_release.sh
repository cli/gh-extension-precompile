#!/bin/bash

# Exit early if a single command fails
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Add color utilities.
# TODO: Do we need to check for color support if a self-hosted runner happens to not support color?
source "${SCRIPT_DIR}"/utils.sh

# An array containing all GOOS-es to build the binaries for.
platforms=(
  darwin-amd64
  darwin-arm64
  freebsd-386
  freebsd-amd64
  freebsd-arm64
  linux-386
  linux-amd64
  linux-arm
  linux-arm64
  windows-386
  windows-amd64
  windows-arm64
)

if [[ "$RELEASE_ANDROID" == "true" ]]; then
  # We must have `ANDROID_SDK_VERSION` and `ANDROID_NDK_HOME` set to build for android.
  # The latter is available by default on GitHub hosted runners, but not necessarily the former.
  if [[ -z "$ANDROID_SDK_VERSION" ]]; then
    fail "Cannot build for Android without ANDROID_SDK_VERSION environment variable!"
  elif [[ ! -d "$ANDROID_NDK_HOME" ]]; then
    fail "Cannot build for Android without ANDROID_NDK_HOME environment variable!"
  fi

  platforms+=("android-amd64" "android-arm64")
fi

prerelease=""
# TODO: Do we want to allow users to set `--prerelease` via a workflow flag?
if [[ $GH_RELEASE_TAG = *-* ]]; then
  info "Marking release as not production-ready..."
  prerelease="--prerelease"
fi

draft_release=""
if [[ "$DRAFT_RELEASE" = "true" ]]; then
  info "Marking release as draft..."
  draft_release="--draft"
fi

if [ -n "$GH_EXT_BUILD_SCRIPT" ]; then
  info "Invoking build script override: $GH_EXT_BUILD_SCRIPT"
  ./"$GH_EXT_BUILD_SCRIPT" "$GH_RELEASE_TAG"
else
  # Create build for individual platforms, ensuring they are supported
  IFS=$'\n' read -d '' -r -a supported_platforms < <(go tool dist list) || true

  for p in "${platforms[@]}"; do
    goos="${p%-*}"
    goarch="${p#*-}"
    if [[ " ${supported_platforms[*]} " != *" ${goos}/${goarch} "* ]]; then
      warn "Skipping unsupported platform: $p"
      continue
    fi

    # Add .exe suffix on windows
    ext=""
    if [ "$goos" = "windows" ]; then
      ext=".exe"
    fi

    path="dist/${p}${ext}"

    cc=""
    cgo_enabled="${CGO_ENABLED:-0}"
    if [ "$goos" = "android" ]; then
      if [ "$goarch" = "amd64" ]; then
        cc="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android${ANDROID_SDK_VERSION}-clang"
        cgo_enabled="1"
      elif [ "$goarch" = "arm64" ]; then
        cc="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android${ANDROID_SDK_VERSION}-clang"
        cgo_enabled="1"
      fi
    fi

    if GOOS="$goos" GOARCH="$goarch" CGO_ENABLED="$cgo_enabled" CC="$cc" \
      go build -trimpath -ldflags="-s -w" -o "${path}" "${GO_BUILD_OPTIONS}"; then
      success "Successfully created binary for ${goos}/${goarch} at ${path}!"
    else
      fail "Error creating binary for ${goos}/${goarch}!" $?
    fi

  done
fi

# TODO: We can likely rework this to use `readarray` or just compacting the glob directly with `nullglob`
assets=()
for f in dist/*; do
  if [ -f "$f" ]; then
    assets+=("$f")
  fi
done

if [ "${#assets[@]}" -eq 0 ]; then
  fail "No executable files found in dist/!"
fi

if [ -n "$GPG_FINGERPRINT" ]; then
  shasum -a 256 "${assets[@]}" > checksums.txt
  gpg --output checksums.txt.sig --detach-sign checksums.txt
  assets+=(checksums.txt checksums.txt.sig)
  success "Successfully signed binaries!"
fi

if gh release view "$GH_RELEASE_TAG" >/dev/null; then
  gh release upload "$GH_RELEASE_TAG" --clobber -- "${assets[@]}"
  success "Uploaded assets to existing release ${GH_RELEASE_TAG}!"
else
  gh release create "$GH_RELEASE_TAG" $prerelease $draft_release --title="${GH_RELEASE_TITLE_PREFIX} ${GH_RELEASE_TAG#v}" --generate-notes -- "${assets[@]}"
  success "Created release ${GH_RELEASE_TAG} and uploaded assets!"
fi
