# Release

How a build of Loe gets to TestFlight, and how the repository stays safe to
make public.

## Version and build number

- **Marketing version** is `MARKETING_VERSION` in the project, `MAJOR.MINOR.PATCH`.
  Change it in a pull request when a release needs it.
- **Build number** is the number of commits on `main` at the archived commit,
  set at archive time. It only grows, because `main` takes rebase merges and is
  never rewritten. A build number finds its commit:
  `git rev-list --reverse origin/main | sed -n '<build>p'`. An upload also
  tags that commit `build-<build>`. The project file keeps 1, which only local
  builds use.
- `ExportOptions.plist` sets `manageAppVersionAndBuildNumber` to false, or
  Xcode would renumber the build on upload.

## Uploading to TestFlight

```sh
scripts/upload-testflight.sh --dry-run   # checks everything, builds nothing
scripts/upload-testflight.sh             # archives main, uploads it and tags it
```

Every build is the newest commit of `main` on GitHub, whatever the checkout
the script runs from has on it. The script archives a fresh worktree of that
commit, in `build/main`, so a branch, a local change or an ignored file never
ends up in a build. What it checks, it reads from that commit too. It refuses,
also with `--dry-run`:

- A script that differs from the one on `main`, so what `main` says an upload
  checks is what gets checked.
- A shallow clone, which cannot count the build number.
- A commit CI has not passed. `App tests (iOS)`, `Catalogue build tests` and
  `SonarCloud Code Analysis` have to have passed on it: the checks `main`
  requires that run on a push. No other check on it may have failed, been
  cancelled or still be running. The script asks GitHub through `gh`, which
  has to be signed in. When the checks `main` requires change, change the
  list in the script. The journeys are not among them, because CI never runs
  them ([standards](standards.md#continuous-integration)): a passed commit
  says nothing about the journeys.
- Synced models whose deploy to Production is not recorded, as described
  below.
- A build number that has its tag, because that build was uploaded already.

After an upload the script tags the commit `build-<n>` and pushes the tag. The
tag says the commit was uploaded as that build, not that App Store Connect
took it: processing comes later, and a build it turns down keeps its tag. A
tag is permanent, and the next upload needs a new commit, so no number is used
twice. `git log --oneline build-<older>..build-<newer>` lists what changed
between two builds. When the tag does not reach GitHub, the script says so
with the command that pushes it, and refuses another upload until it is
pushed. No GitHub release is made for a build.

The script signs automatically with the App Store Connect key and uploads a
build that can go to internal or external testers. Adding it to an external
group, which needs Beta App Review the first time, stays a step in App Store
Connect. `build/archive.log` starts with the version of Xcode that built the
archive.

`scripts/test_upload_testflight.py` runs the script in a throwaway repository
with a remote of its own, and with stand-ins for `xcodebuild` and `gh`, so it
builds and uploads nothing: `python3 -I -m unittest discover -s scripts`.

TestFlight builds use CloudKit's Production environment. After a change to any
synced model (`ShelvedBook`, `Taste`, `ChosenPlace`, or a new one), teach
Development the new fields, then deploy the schema from Development to
Production in the CloudKit Console before testers sync, or sync stops for them.
See [Library](library.md).

`scripts/synced-models.txt` lists every synced field and `StoredNamesTests`
holds the models to it, so a pull request that changes a synced model changes
that file too. `scripts/synced-models.deployed.txt` records what Production
has. The upload script refuses, also with `--dry-run`, while the two differ
on `main`.

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
identifier. The last step is to copy `scripts/synced-models.txt` over
`scripts/synced-models.deployed.txt` in a pull request, which is the record
that the deploy happened.

## Secrets

Loe has two secrets: the App Store Connect API key "Loe uploads", and
SonarCloud's analysis token.

- The `.p8` lives in `~/.appstoreconnect/private_keys/`, readable only by its
  owner (`chmod 600`), with its download attributes removed (`xattr -c`). It is
  never copied, printed, attached to an issue or pasted into a chat. Its
  metadata counts as secret too: a browser can record the whole key there.
- Its ID, issuer and path go in `.env`, which git ignores. `.env.example`
  shows the shape. The upload script reads only those three names from it and
  passes only the path to `xcodebuild`.
- A key that has been exposed anywhere is revoked in App Store Connect and
  replaced, not kept.
- The SonarCloud token is the repository secret `SONAR_TOKEN`, used only by
  the scan job (see [standards](standards.md#continuous-integration)). It can
  only run analyses. Nobody reads its value back: if it may have leaked,
  revoke it in SonarCloud and set a new one.
- Nothing else in the repository is secret. The team ID, bundle identifiers,
  the iCloud container and the catalogue's address are all visible in any
  signed build.

## Keeping the public repository safe

The repository is public. It stays safe to be:

- Rulesets protect `main` (pull request required, rebase merges only, the
  required checks, linear history, no force push or deletion) and every tag
  (no update or deletion).
- Releases are immutable: once one is published, its tag and its files cannot
  be changed, so a catalogue can never change under the apps that use it.
  `catalogue-2026-11` was published before that was turned on, and its file
  can still be replaced. The app checks every download against the manifest's
  SHA-256, so a replaced file would fail to install and never be read.
- Secret scanning and push protection are on. GitHub refuses a push that holds
  a key it recognises, and reports one it finds in the history.
- Private vulnerability reporting is on, which is where `SECURITY.md` sends
  reporters.
- Only GitHub-owned actions may run, plus SonarCloud's scan action at the one
  commit the workflow pins, and the default workflow token can only read.
- Workflows run on `pull_request`, never `pull_request_target`, with
  `permissions: contents: read` and `persist-credentials: false` on checkout. A
  fork's pull request gets a read-only token and no secrets.
- Every action is pinned to a full commit SHA with its version in a comment.
- A workflow that uploads would get its secrets from an environment limited to
  `main` (Settings → Environments), never from repository secrets, and run only
  on `workflow_dispatch`. Uploads happen locally for now.
- Push protection catches the kinds of key GitHub recognises, not every
  private key. So before anything that could hold a secret merges, run the
  history scan:
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

`Loe/PrivacyInfo.xcprivacy` declares no tracking and no collected data. It
names two required-reason APIs: `UserDefaults`, for the appearance setting and
the catalogue's update check, and file timestamps, by which `Covers` remembers
for 30 days that a book has no cover. `PrivacyManifestTests` fails when the
code calls one the manifest doesn't declare, or the manifest declares one the
code doesn't call. Loe fetches the catalogue from GitHub by itself, from the
first launch, and that sends nothing about the reader.

The camera is asked for once, with one text for both of its uses: reading a
barcode in Search and photographing a cover on a book's page.

Every request goes through
[`PrivateSession`](../Loe/Shared/Network/PrivateSession.swift): no cookies,
cache or credentials, a `User-Agent` that names the app, its repository and the
developer's contact, and `Accept-Language: en`, so the reader's own languages
are never sent.

When a reader has picked libraries, a book's page asks ESTER about that book
as it opens, over HTTPS with no cookies (see [Library](library.md#availability)).
ESTER sees which book records were asked about, from the phone's address, as
any website would. Loe keeps nothing of it, so the manifest's collected data
stays empty.

Search asks Open Library about what the reader typed once they pause, over
HTTPS with no cookies (see [Catalogue](catalogue.md#books-from-abroad)). Open
Library, run by the Internet Archive, sees the search text from the phone's
address. An ISBN, typed or scanned, is sent only when the catalogue has no
edition with it. The `User-Agent` names the app and the developer's contact,
never the reader. Loe keeps the answers in memory only, so the collected data stays
empty here too.

A book found on Open Library asks it for the work's record as its page opens,
for the description (see [Catalogue](catalogue.md#books-from-abroad)). Open
Library sees which of those books was opened, from the phone's address. The
description is kept in memory only.

Covers come from Open Library too (see [Library](library.md#covers)), but
only for a book found on Open Library: its cover id, or its ISBN when it has
none, is sent to `covers.openlibrary.org` when the book shows, which
redirects to the Internet Archive (`archive.org`) for the image, so both see
which of those books' covers were asked for. A book entered by hand asks for
none. The images are kept in the caches folder on the phone, and nothing else.

A catalogue book's cover comes from ESTER's cover service, EPIK
(`epik.ester.ee`), asked from the book's own page and from the shelves: the
record numbers of the book's editions are sent, so ESTER sees which books'
covers were asked for, from the phone's address. A record's own summary comes
back with its cover. Both are kept in the caches folder on the phone.

The catalogue manifest, which Loe reads from GitHub once a week, can turn off
what Loe asks ESTER: availability, covers and summaries (see
[Library](library.md#turning-ester-off)). It is the one thing outside the
phone that changes what Loe does, and it can only make Loe ask less.

The Privacy page, under About in Settings (`PrivacyView`), tells the reader
all of this in plain words. Change it with this section, so the two never
disagree.

The About page credits every source and ships the licence text of what Loe
copies: Newsreader's OFL and the catalogue's CC0 1.0, in
`Loe/Resources/Licenses`. `CreditTests` fails when a licence file is added
there without a credit, or a credit names a file that isn't shipped.

## Before the App Store

- Ask ELNET (ester@elnet.ee) for permission to show ESTER's availability in
  the app. ESTER's statutes put copying its data under ELNET's permission.
  Internal TestFlight testing goes ahead without it.
- The same permission covers ESTER's covers and summaries, which Loe takes
  from EPIK, ELNET's cover service (see [Library](library.md#covers)). EPIK
  has no published terms and its `robots.txt` disallows everything, so a
  public release waits for ELNET's answer. Without it, take ESTER's covers and
  summaries out before releasing.
- The first public build has to be one that reads the manifest's
  [switch for ESTER](library.md#turning-ester-off), since an older build
  cannot be told to stop.
