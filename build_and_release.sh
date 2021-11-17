#!/bin/bash
set -e

tag=$(git describe --tags --abbrev=0)
platforms=$(echo "darwin-amd64,linux-386,linux-arm,linux-amd64,linux-arm64,windows-386,windows-amd64" | tr "," "\n")
include="dist/*"

if [ -n "${GH_EXT_BUILD_SCRIPT}" ]; then
  echo "invoking build script override ${GH_EXT_BUILD_SCRIPT}"
  ./${GH_EXT_BUILD_SCRIPT} $tag || exit $?
else
  for p in $platforms; do
    goos=$(echo $p | sed 's/-.*//')
    goarch=$(echo $p | sed 's/.*-//')
    ext=""
    if [[ "${goos}" == "windows" ]]; then
      ext=".exe"
    fi
    GOOS=${goos} GOARCH=${goarch} go build -o "dist/${goos}-${goarch}${ext}"
  done
fi

ls -A dist >/dev/null || (echo "no files found in dist/" && exit 1)

if [ -n "${GPG_FINGERPRINT}" ]; then
  for f in $(ls dist); do
    shasum -a 256 dist/$f >> checksums.txt
  done
  gpg --output checksums.txt.sig --detach-sign checksums.txt
  include="dist/* checksums*"
fi

prerelease=""

if [[ "${tag}" =~ .*-.* ]]; then
  prerelease="-p"
fi

gh api repos/$GITHUB_REPOSITORY/releases/generate-notes \
  -f tag_name="${tag}" -q .body > CHANGELOG.md

gh release create $tag $prerelease --notes-file CHANGELOG.md $include
