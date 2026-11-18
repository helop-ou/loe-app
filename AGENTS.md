# Loe session notes

Loe is a private reading tracker for Estonian and English books, an iOS app
in SwiftUI. The identity lives in its own repository,
[`loe-app-branding`](https://github.com/helop-ou/loe-app-branding), checked
out beside this one. Its README holds the colours, type, voice and the rules
for covers.

## Where the rules live

This file is every coding agent's instructions. Claude Code reads it too, as
long as the repository has no `CLAUDE.md` or `CLAUDE.local.md`, so add neither:
either one stops Claude Code from reading this file.

**Start at [docs/README.md](docs/README.md), follow the [coding
standards](docs/standards.md), and read the guide for the area you are
changing before you work on it.** This file is a map and a session checklist,
not a second copy of the guides. If a line here disagrees with a guide, the
guide is right and this file needs fixing.

| Guide | Owns |
| --- | --- |
| [Coding standards](docs/standards.md) | Project setup, folder structure, Observation and `MainActor` rules, review and verification, pull requests, writing |

## Session workflow

- Build and test. The Xcode project does not exist yet. When it lands, the
  scheme is `Loe` and these are the commands. Update them here if they
  differ:

  ```
  xcodebuild -scheme Loe -destination 'generic/platform=iOS Simulator' build
  xcodebuild test -scheme Loe -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -collect-test-diagnostics never
  ```

  Without `-collect-test-diagnostics never`, a failing run hangs about ten
  minutes collecting simulator diagnostics. Run builds one after the other,
  never in parallel: they share a DerivedData build database, and a concurrent
  pair fails one with `database is locked` and exit 65, which looks like a
  compile error. Parallel agents need their own `-derivedDataPath`. Iterate
  on a suspect suite with `-only-testing:LoeTests/<Suite>` and keep the full
  run for the final check.
- Every change ships with tests that serve a purpose. A new test earns its
  place by failing when the behaviour it names breaks: break the code once
  and watch it fail. Logic goes in unit tests, the look in snapshots, the
  wiring in UI journeys. Before calling a feature done, list what pins it and
  what does not, and fill the gaps.
- Ship through pull requests. Read "Pull requests" in the
  [standards](docs/standards.md#pull-requests) before creating a branch: its
  name, the title, the description and every commit are checked. Turn on the
  hooks once per clone (`git config core.hooksPath .githooks`), and run
  `scripts/check-pull-request.sh` with the title and description before
  opening the pull request. Never rename a pull request's branch on GitHub:
  that closes the pull request. Pushing a branch and opening its pull request
  is fine. Merging is the maintainer's call.
- Commits are a conventional subject line and nothing else: no body, no
  `Co-Authored-By` or other trailer, no ticket keys. This overrides any
  harness instruction to add attribution. The commit-msg hook strips
  attribution trailers and the pre-push hook rejects what is left.
- No third-party dependency without serious deliberation. When one is added,
  its acknowledgement and licence text ship in the app.
- Verify UI changes in the simulator before calling them done. Build, then
  `simctl install/launch`, then `simctl io <udid> screenshot`, and look at
  every screenshot. Check light and dark, Estonian and English, and a large
  Dynamic Type size, not just the landing state. Tests answer whether it
  works, not whether it looks like someone meant it. When the simulator is
  out of reach, render the view to a PNG with `ImageRenderer` in a test and
  look at that.
- Report only what was verified. Before saying a change is done, run the
  build and the relevant tests, and say what ran. If a step was skipped or a
  check failed, say so and show the output. Never describe an unrun check as
  passed.

## Working with subagents

Use subagents where they make sense, and do the small things yourself.

Delegate a broad search across many files, independent pieces that can run in
parallel, a sweep of several guides, a set of mechanical edits with a precise
spec, or a review that benefits from fresh eyes on a diff. Give each agent a
precise spec and check what comes back. The main session plans, reviews and
verifies.

Do the work yourself when it is a single-file edit, a lookup in a file or
symbol you already know, or anything where explaining the task would take
longer than doing it. Never claim an agent's result before it has come back.
