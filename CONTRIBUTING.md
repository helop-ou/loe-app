# Contributing to Loe

Loe is one iPhone app target in SwiftUI for iOS 26, with unit tests, journeys
through the real app, and a small Python tool that builds its book catalogue.
It has no third-party dependencies.

- Loe's code is **MPL-2.0** ([LICENSE](LICENSE)), with the name and brand
  artwork carved out by [TRADEMARKS.md](TRADEMARKS.md). Contributions are made
  under those terms.
- Bugs, wrong book data and ideas go through the issue forms. Anything with
  security or privacy impact follows [SECURITY.md](SECURITY.md) instead.
- Everyone keeps to the [Code of Conduct](CODE_OF_CONDUCT.md). Report breaches
  to kontakt@helop.ee.
- Loe is maintained by one person. Before a large change, open an issue saying
  what you want to do. Anything that would change what Loe promises its
  readers (no account, no ads, no tracking, no server of its own) is the
  maintainer's decision.

## What you need

A Mac with Xcode 27.2 and an iPhone simulator. The catalogue tool needs
Python 3 and nothing beyond its standard library.

## Build and test

Open `Loe.xcodeproj` and run the `Loe` scheme on an iPhone simulator. From the
command line:

```sh
xcodebuild -scheme Loe -destination 'generic/platform=iOS Simulator' build
xcodebuild test -scheme Loe -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -collect-test-diagnostics never
python3 -I -m unittest discover -s tools/catalogue
python3 -I -m unittest discover -s scripts
```

The second command runs the unit tests and the journeys through the real
app. CI runs only the unit tests, so run it on a Mac before opening a pull
request: nothing else checks the journeys.

Run builds one after the other, never two at once. [AGENTS.md](AGENTS.md)
says why, and holds the rest of the session checklist.

Loe fetches its book catalogue from GitHub by itself when it first opens, in
the simulator too. To use one you built, copy it in as
[Catalogue](docs/catalogue.md#trying-it-in-the-simulator) describes. The
journeys search a small catalogue of their own.

## Where the rules live

[`docs/README.md`](docs/README.md) is the index and
[`docs/standards.md`](docs/standards.md) holds the rules. Read the guide for
the area you are changing first, and update the guide that owns a contract you
change. The rules a newcomer most often trips on:

- Work reaches `main` through a pull request whose branch name, title,
  description and commits are all checked.
  [Pull requests](docs/standards.md#pull-requests) has the forms. Turn the
  hooks on once with `git config core.hooksPath .githooks`, and run
  `scripts/check-pull-request.sh` before opening one.
- A commit is a conventional subject line and nothing else: no body and no
  trailers.
- Every change ships with tests that fail when the behaviour they name breaks.
  A change to what a reader sees is looked at in the simulator, in light and
  dark, in Estonian and English, and at a large text size.
- Every string a reader sees is in `Loe/Localizable.xcstrings` with its
  Estonian translation.
- No new dependency without a real argument for it.

A pull request from a fork runs the tests but not the SonarCloud scan, which
needs a secret a fork does not get. The maintainer brings such a change in
from a branch of this repository.

## Signing and the brand

Simulator builds need no signing. The project carries the maintainer's team,
the bundle identifier `ee.helop.loe` and the iCloud container
`iCloud.ee.helop.loe`. To run on a device, change them to your own, and keep
those changes out of what you submit.

The colours, the icon and the wordmark in the app are copied from a separate
brand project and are not edited here. They are not part of the source
licence, and the Newsreader typeface has its own, as
[TRADEMARKS.md](TRADEMARKS.md) says.
