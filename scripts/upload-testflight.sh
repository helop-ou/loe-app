#!/usr/bin/env bash
#
# Archives the newest commit of main and uploads it to TestFlight. See
# docs/release.md.
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

# Every build is the newest commit of main, read from git and never from this
# checkout, so a branch, a change or an ignored file here can't end up in it.
git fetch --quiet origin main
commit="$(git rev-parse origin/main)"
on_main() { git show "$commit:$1"; }

# What main says an upload checks is what gets checked.
on_main scripts/upload-testflight.sh | cmp -s - "$root/scripts/upload-testflight.sh" \
    || fail "This script is not the one on main. Run it from a checkout that has main's"

# TestFlight builds sync through CloudKit's Production environment, which has
# to know every synced field first. See docs/release.md.
if ! cmp -s <(on_main scripts/synced-models.txt) <(on_main scripts/synced-models.deployed.txt); then
    diff <(on_main scripts/synced-models.deployed.txt) <(on_main scripts/synced-models.txt) | grep '^[<>]' >&2 || true
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

# The build number is the commit count of main, which only grows because main
# takes rebase merges and is never rewritten.
build="$(git rev-list --count "$commit")"
version="$(on_main Loe.xcodeproj/project.pbxproj | awk -F' = ' '/MARKETING_VERSION/ && !found { found = 1; sub(/;$/, "", $2); print $2 }')"
archive="$root/build/Loe-$version-$build.xcarchive"
echo "Loe $version ($build) from $(git rev-parse --short "$commit")"

auth=(-allowProvisioningUpdates
      -authenticationKeyPath "$key"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

if $dry_run; then
    echo "✔ Ready to archive and upload. Nothing was built."
    exit 0
fi

mkdir -p build
worktree="$root/build/main"
git worktree remove --force "$worktree" 2> /dev/null || true
git worktree prune
git worktree add --quiet --detach "$worktree" "$commit"
trap 'git -C "$root" worktree remove --force "$worktree"' EXIT

xcodebuild -version > build/archive.log
xcodebuild archive \
    -project "$worktree/Loe.xcodeproj" -scheme Loe -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive" \
    CURRENT_PROJECT_VERSION="$build" \
    "${auth[@]}" >> build/archive.log 2>&1 || { tail -30 build/archive.log; fail "Archive failed, see build/archive.log"; }

xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportOptionsPlist "$worktree/ExportOptions.plist" \
    -exportPath "$root/build/export-$build" \
    "${auth[@]}" > build/upload.log 2>&1 || { tail -30 build/upload.log; fail "Upload failed, see build/upload.log"; }

echo "✔ Uploaded Loe $version ($build). It appears in TestFlight once App Store Connect has processed it."
