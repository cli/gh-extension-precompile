#!/bin/bash
set -e

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
  platforms+=("android-amd64")
  platforms+=("android-arm64")
fi

# We must know the android sdk version to build for android.
if [[ "$RELEASE_ANDROID" == "true" && -z "$ANDROID_SDK_VERSION" ]]; then
  echo "error: Cannot build for android without android_sdk_version." >&2
  exit 1
fi

# We must have `ANDROID_NDK_HOME` set to build for android.
# This will be available by default on GitHub hosted runners.
if [[ "$RELEASE_ANDROID" == "true" && ! -d "$ANDROID_NDK_HOME" ]]; then
  echo "error: Cannot build for android without android_ndk_home." >&2
  exit 1
fi

prerelease=""
if [[ $GH_RELEASE_TAG = *-* ]]; then
  prerelease="--prerelease"
fi

draft_release=""
if [[ "${DRAFT_RELEASE:-}" = "true" ]]; then
  draft_release="--draft"
fi

if [ -n "$GH_EXT_BUILD_SCRIPT" ]; then
  echo "invoking build script override $GH_EXT_BUILD_SCRIPT"
  ./"$GH_EXT_BUILD_SCRIPT" "$GH_RELEASE_TAG"
else
  IFS=$'\n' read -d '' -r -a supported_platforms < <(go tool dist list) || true

  for p in "${platforms[@]}"; do
    goos="${p%-*}"
    goarch="${p#*-}"
    if [[ " ${supported_platforms[*]} " != *" ${goos}/${goarch} "* ]]; then
      echo "warning: skipping unsupported platform $p" >&2
      continue
    fi
    ext=""
    if [ "$goos" = "windows" ]; then
      ext=".exe"
    fi
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
    GOOS="$goos" GOARCH="$goarch" CGO_ENABLED="$cgo_enabled" CC="$cc" go build -trimpath -ldflags="-s -w" -o "dist/${p}${ext}" "${GO_BUILD_OPTIONS}"
  done
fi

assets=()
for f in dist/*; do
  if [ -f "$f" ]; then
    assets+=("$f")
  fi
done

if [ "${#assets[@]}" -eq 0 ]; then
  echo "error: no files found in dist/*" >&2
  exit 1
fi

if [ -n "$GPG_FINGERPRINT" ]; then
  shasum -a 256 "${assets[@]}" > checksums.txt
  gpg --output checksums.txt.sig --detach-sign checksums.txt
  assets+=(checksums.txt checksums.txt.sig)
fi

if gh release view "$GH_RELEASE_TAG" >/dev/null; then
  echo "uploading assets to an existing release..."
  gh release upload "$GH_RELEASE_TAG" --clobber -- "${assets[@]}"
else
  echo "creating release and uploading assets..."
  gh release create "$GH_RELEASE_TAG" $prerelease $draft_release --title="${GH_RELEASE_TITLE_PREFIX} ${GH_RELEASE_TAG#v}" --generate-notes -- "${assets[@]}"
fi
