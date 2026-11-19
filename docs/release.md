# Release

How a build of Loe gets to TestFlight, and how the repository stays safe to
make public.

## Version and build number

- **Marketing version** is `MARKETING_VERSION` in the project, `MAJOR.MINOR.PATCH`.
  Change it in a pull request when a release needs it.
- **Build number** is the number of commits on `main` at the archived commit,
  set at archive time. It only grows, because `main` takes rebase merges and is
  never rewritten. A build number finds its commit:
  `git rev-list --reverse origin/main | sed -n '<build>p'`. The project file
  keeps 1, which only local builds use.
- `ExportOptions.plist` sets `manageAppVersionAndBuildNumber` to false, or
  Xcode would renumber the build on upload.

## Uploading to TestFlight

```sh
scripts/upload-testflight.sh --dry-run   # checks the key and the checkout
scripts/upload-testflight.sh             # archives main and uploads it
```

The script refuses a working tree with changes or a `HEAD` that is not
`origin/main`, so every build comes from a commit anyone can see. It signs
automatically with the App Store Connect key and uploads a build that can go to
internal or external testers. Adding it to an external group, which needs Beta
App Review the first time, stays a step in App Store Connect.

TestFlight builds use CloudKit's Production environment. After a change to any
synced model (`ShelvedBook`, `Taste`, `ChosenPlace`, or a new one), teach
Development the new fields, then deploy the schema from Development to
Production in the CloudKit Console before testers sync, or sync stops for them.
See [Library](library.md).

A debug build launched with `-initializeCloudKitSchema YES` pushes every synced
model to Development from a throwaway store, so no shelves are touched and
nothing needs tapping. On a device signed into iCloud, wired or on the same
network:

```sh
xcodebuild -scheme Loe -configuration Debug -destination 'id=<device>' \
  -derivedDataPath /tmp/loe-device -allowProvisioningUpdates build
xcrun devicectl device install app --device <device> /tmp/loe-device/Build/Products/Debug-iphoneos/Loe.app
xcrun devicectl device process launch --device <device> --console --terminate-existing ee.helop.loe \
  -- -initializeCloudKitSchema YES -inMemoryLibrary YES
```

It prints "CloudKit schema: Development now has every synced model". Then
choose Deploy Schema Changes in the CloudKit Console, and reinstall Loe from
TestFlight on that device. `xcrun devicectl list devices` gives the device's
identifier.

## Secrets

Loe has one secret: the App Store Connect API key "Loe uploads".

- The `.p8` lives in `~/.appstoreconnect/private_keys/`, readable only by its
  owner (`chmod 600`), with its download attributes removed (`xattr -c`). It is
  never copied, printed, attached to an issue or pasted into a chat. Its
  metadata counts as secret too: a browser can record the whole key there.
- Its ID, issuer and path go in `.env`, which git ignores. `.env.example`
  shows the shape. The upload script reads only those three names from it and
  passes only the path to `xcodebuild`.
- A key that has been exposed anywhere is revoked in App Store Connect and
  replaced, not kept.
- Nothing else in the repository is secret. The team ID, bundle identifiers,
  the iCloud container and the catalogue's address are all visible in any
  signed build.

## Keeping the public repository safe

The repository is public. It stays safe to be:

- Rulesets protect `main` (pull request required, the required checks, linear
  history, no force push or deletion) and every tag (no update or deletion),
  so a catalogue release can never change under the apps that use it.
- Only GitHub-owned actions may run, and the default workflow token can only
  read.
- Workflows run on `pull_request`, never `pull_request_target`, with
  `permissions: contents: read` and `persist-credentials: false` on checkout. A
  fork's pull request gets a read-only token and no secrets.
- Every action is pinned to a full commit SHA with its version in a comment.
- A workflow that uploads would get its secrets from an environment limited to
  `main` (Settings → Environments), never from repository secrets, and run only
  on `workflow_dispatch`. Uploads happen locally for now.
- Before anything that could hold a secret merges, run the history scan:
  `git rev-list --all | while read c; do git grep -I -l -E 'BEGIN ([A-Z]+ )?PRIVATE KEY|ghp_|github_pat_|AKIA' "$c"; done`.

## README screens

The screens in the README are the real app, captured by `ReadmeScreensTests`
with the catalogue on the simulator and a cover photo as the newest picture in
its Photos (the green cover is a stand-in, not publisher artwork). It skips
unless asked:

```sh
xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100
TEST_RUNNER_LOE_README_SCREENS=1 xcodebuild test -scheme Loe \
  -destination 'platform=iOS Simulator,id=<udid>' \
  -only-testing:LoeUITests/ReadmeScreensTests -resultBundlePath /tmp/readme.xcresult
xcrun xcresulttool export attachments --path /tmp/readme.xcresult --output-path /tmp/readme
cwebp -q 82 -resize 600 0 /tmp/readme/<file>.png -o .github/readme/screens/<name>.webp
xcrun simctl status_bar <udid> clear
```

The header images come from the brand repository's GitHub images.

## Privacy

`Loe/PrivacyInfo.xcprivacy` declares no tracking and no collected data. The
only required-reason API is `UserDefaults`, for the appearance setting and the
catalogue's update check. The catalogue download sends nothing about the
reader, and covers are the reader's own photos.

When a reader has picked libraries, a book's page asks ESTER about that book
as it opens, over HTTPS with no cookies (see [Library](library.md#availability)).
ESTER sees which book records were asked about, from the phone's address, as
any website would. Loe keeps nothing of it, so the manifest's collected data
stays empty.

## Before the App Store

- Ask ELNET (ester@elnet.ee) for permission to show ESTER's availability in
  the app. ESTER's statutes put copying its data under ELNET's permission.
  Internal TestFlight testing goes ahead without it.
