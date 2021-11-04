#!/bin/bash
set -e

tag=$(git describe --tags --abbrev=0)
platforms=$(echo $GH_EXT_PLATFORMS | tr "," "\n")
include="dist/*"

if [ -n "${GH_EXT_BUILD_SCRIPT}" ]; then
  echo "invoking build script override ${GH_EXT_BUILD_SCRIPT}"
  ./${GH_EXT_BUILD_SCRIPT} $tag || exit $?
else
  for p in $platforms; do
    goos=$(echo $p | sed 's/-.*//')
    goarch=$(echo $p | sed 's/.*-//')
    GOOS=${goos} GOARCH=${goarch} go build -o "dist/${goos}-${goarch}-${tag}"
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
