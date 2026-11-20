#!/usr/bin/env bash
#
# Archives Loe from main and uploads it to TestFlight. See docs/release.md.
#
#   scripts/upload-testflight.sh            # archive and upload
#   scripts/upload-testflight.sh --dry-run  # check everything, upload nothing
#
# Needs an App Store Connect API key, in .env (see .env.example) or exported:
# ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH. Only the path is passed on. This
# script never reads or prints the key.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
dry_run=false
[[ "${1:-}" == "--dry-run" ]] && dry_run=true

fail() { echo "✘ $*" >&2; exit 1; }

# TestFlight builds sync through CloudKit's Production environment, which has
# to know every synced field first. See docs/release.md.
if ! cmp -s scripts/synced-models.txt scripts/synced-models.deployed.txt; then
    diff scripts/synced-models.deployed.txt scripts/synced-models.txt | grep '^[<>]' >&2 || true
    fail "The synced models changed since the CloudKit schema was last deployed. Deploy it to Production, then copy scripts/synced-models.txt over scripts/synced-models.deployed.txt in a pull request"
fi

# Read only the three keys from .env, without running it as shell.
if [[ -f .env ]]; then
    while IFS='=' read -r name value; do
        case "$name" in
            ASC_KEY_ID|ASC_ISSUER_ID|ASC_KEY_PATH) [[ -n "${!name:-}" ]] || export "$name=$value" ;;
        esac
    done < .env
fi
: "${ASC_KEY_ID:?Set ASC_KEY_ID, see .env.example}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID, see .env.example}"
: "${ASC_KEY_PATH:?Set ASC_KEY_PATH, see .env.example}"
key="${ASC_KEY_PATH/#\~/$HOME}"
[[ -f "$key" ]] || fail "No key at ASC_KEY_PATH"
[[ "$(stat -f %Lp "$key")" == 600 ]] || fail "The key should be readable only by you: chmod 600 it"

# Every build comes from a commit on main, so it can be traced and rebuilt.
git fetch --quiet origin main
[[ -z "$(git status --porcelain)" ]] || fail "The working tree has changes"
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || fail "HEAD is not origin/main"

# The build number is the commit count of main, which only grows because main
# takes rebase merges and is never rewritten.
build="$(git rev-list --count HEAD)"
version="$(grep -m1 'MARKETING_VERSION' Loe.xcodeproj/project.pbxproj | sed -E 's/.*= (.*);/\1/')"
archive="build/Loe-$version-$build.xcarchive"
echo "Loe $version ($build) from $(git rev-parse --short HEAD)"

auth=(-allowProvisioningUpdates
      -authenticationKeyPath "$key"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

if $dry_run; then
    echo "✔ Ready to archive and upload. Nothing was built."
    exit 0
fi

mkdir -p build
xcodebuild archive \
    -project Loe.xcodeproj -scheme Loe -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive" \
    CURRENT_PROJECT_VERSION="$build" \
    "${auth[@]}" > build/archive.log 2>&1 || { tail -30 build/archive.log; fail "Archive failed, see build/archive.log"; }

xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportOptionsPlist ExportOptions.plist \
    -exportPath "build/export-$build" \
    "${auth[@]}" > build/upload.log 2>&1 || { tail -30 build/upload.log; fail "Upload failed, see build/upload.log"; }

echo "✔ Uploaded Loe $version ($build). It appears in TestFlight once App Store Connect has processed it."
