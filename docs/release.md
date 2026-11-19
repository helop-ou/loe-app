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

TestFlight builds use CloudKit's Production environment. Deploy the schema from
Development to Production in the CloudKit Console after any change to
`ShelvedBook`, or sync stops for testers. See [Library](library.md).

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

## Before the repository goes public

Checked on 2026-11-19: no secret or credential file in any commit, and the
Release binary carries none of the debug launch arguments.

- Protect `main` and every tag with rulesets: pull request required, required
  checks, linear history, no force push or deletion. Free on a public
  repository.
- Keep every workflow on `pull_request`, never `pull_request_target`, with
  `permissions: contents: read` unless a job needs more, and
  `persist-credentials: false` on checkout. A fork's pull request then gets a
  read-only token and no secrets.
- Pin every action to a full commit SHA with its version in a comment, and
  allow only GitHub-owned actions in the repository's Actions settings.
- A workflow that uploads gets its secrets from an environment limited to
  `main` (Settings → Environments), never from repository secrets, and runs
  only on `workflow_dispatch`.
- Run the history scan again before switching:
  `git rev-list --all | while read c; do git grep -I -l -E 'BEGIN ([A-Z]+ )?PRIVATE KEY|ghp_|github_pat_|AKIA' "$c"; done`.

## Privacy

`Loe/PrivacyInfo.xcprivacy` declares no tracking and no collected data. The
only required-reason API is `UserDefaults`, for the appearance setting and the
catalogue's update check. The catalogue download sends nothing about the
reader, and covers are the reader's own photos.
