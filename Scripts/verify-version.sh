#!/bin/bash
#
# Fails if Wake.sdkVersion disagrees with the release tag. sdkVersion is stamped on
# every event, so drift makes server-side sdk_version lie about what shipped.
#
# Usage:
#   Scripts/verify-version.sh          # checks against the tag on HEAD
#   Scripts/verify-version.sh 0.1.1    # checks against a tag you're about to cut
#
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_file="$root/Sources/Wake/Wake.swift"

source_version="$(sed -n 's/.*sdkVersion = "\([^"]*\)".*/\1/p' "$source_file")"
if [ -z "$source_version" ]; then
    echo "error: could not read sdkVersion from $source_file" >&2
    exit 2
fi

if [ $# -ge 1 ]; then
    tag="$1"
else
    tag="$(git -C "$root" describe --tags --exact-match HEAD 2>/dev/null || true)"
    if [ -z "$tag" ]; then
        echo "error: HEAD is not tagged; pass the intended version, e.g. $0 $source_version" >&2
        exit 2
    fi
fi

if [ "$source_version" != "${tag#v}" ]; then
    echo "error: version mismatch — Wake.sdkVersion is $source_version, tag is $tag" >&2
    echo "       update sdkVersion in $source_file, or tag $source_version instead" >&2
    exit 1
fi

echo "ok: Wake.sdkVersion $source_version matches tag $tag"
