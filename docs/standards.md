# Coding standards

Read this before adding a feature or reorganizing code. These are Loe
conventions built on Apple and Swift guidance.

## Guidance from Apple and Swift

| Topic | Source | How Loe applies it |
| --- | --- | --- |
| Project organization | [Great Developer Habits, WWDC19](https://developer.apple.com/videos/play/wwdc2019/239/) | Group files by feature and mirror folders in Xcode. |
| Folders and groups | [Managing files and folders](https://developer.apple.com/documentation/xcode/managing-files-and-folders-in-your-xcode-project) | Keep the filesystem-synchronized app group. Check target membership after a move. |
| Model ownership | [Managing model data](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app) | One owner per session or screen model. Views observe it rather than rebuild business state. |
| UI state and dependencies | [Model data](https://developer.apple.com/documentation/swiftui/model-data) | Temporary UI state stays local. Pass values, actions or bindings. Use the environment only for truly shared context. |
| View composition | [Declaring a custom view](https://developer.apple.com/documentation/swiftui/declaring-a-custom-view) | Extract meaningful pieces with small inputs and clear state ownership. |
| Modules | [Organizing code with local packages](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages) | Add a package only when enforcing a stable boundary is worth its build and API cost. |
| API naming | [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) | `UpperCamelCase` types, `lowerCamelCase` members, meaningful argument labels. |

These support the principles, not a `ViewModel` per view or any third-party
architecture framework.

## Project

- A plain `Loe.xcodeproj`, hand-editable (`objectVersion` 77) with
  filesystem-synchronized groups, and a shared `Loe` scheme. iPhone only,
  iOS 26 and Swift 6.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and
  `SWIFT_APPROACHABLE_CONCURRENCY = YES`.
- Bundle identifiers start at `ee.helop.loe`.
- No third-party dependencies without serious deliberation. When one is
  added, its acknowledgement and licence text ship in the app.

## Folder structure

Code is organized by feature, with explicitly shared infrastructure:

```text
Loe/
  App/                         Entry, root composition, app navigation
  Features/
    Shelves/
    ReadNext/
    Search/                    Search, and the catalogue download
    Book/                      A book's own page
    Settings/                  Settings, About and credits, and the language and tastes asked on first launch
  Shared/
    Catalogue/                 The offline catalogue: SQLite access, search, works
    Places/                    The libraries and bookshops a reader can pick
    Library/                   The reader's shelves, stored with SwiftData
    Network/                   The session every client asks through
    UI/                        Brand type, colour and components used across features
  Resources/                   Fonts and licence texts
  Assets.xcassets/             Brand colours (from the brand repository)
  Loe.icon                     App icon (Icon Composer)
  Localizable.xcstrings        English source, Estonian translation
LoeTests/                      Unit tests, grouped by subject
LoeUITests/                    Journeys through the real app
tools/catalogue/               Builds the catalogue file (Python, standard library only)
```

Add `Shared/Models` or `Shared/Persistence` when a second feature needs the
same contract.

- Do not create empty folders to match the diagram. Keep small features flat.
- Feature-owned models and helpers stay beside their feature. Move code to
  `Shared` only when independent features need the same contract.
- No `Utils`, `Helpers` or `Common` dumping grounds.
- Move one cohesive area at a time, and never keep parallel copies of a type.

## Files and reusable components

- Name a file after its main type. Screens and substantial models get their
  own file, and a small private helper can stay beside its only caller.
- Extract when responsibilities, state lifetime or callers differ. Line count
  is a prompt to review, not a limit.
- Use `Type+Responsibility.swift` for a focused conformance or extension. Do
  not widen private state just to spread one object across files.
- Views render and handle interaction. Request coordination, persistence and
  resource lifetime belong to explicit owners. A view does not need its own
  view-model layer by default.
- Reuse existing components before copying markup. Pass a presentational
  component a few values, bindings and actions, not a whole session.
- Native controls over hand-rolled ones. Controls, sheets and menus stay the
  system's.
- Brand colours come from the generated asset symbols (`.loeInk`,
  `.loeBackground` and so on), never hex literals. Headings use
  `.loeHeading(_:)`. Every user-facing string is in `Localizable.xcstrings`
  with its Estonian translation. `TranslationTests` fails when a string there
  has none, or one still marked for review. It cannot see a string the
  catalogue doesn't hold, so add each new string to it with the code.
- The brand files (`Assets.xcassets/Loe`, `Loe.icon`, the fonts, and the
  tone values in `LoeTone.swift`) are generated in the private brand
  repository. Change them there and copy them over, so the two never drift.
- Text follows the view's locale, because Loe can show another language than
  the phone's (see [Language](#language)). A string built in code comes from
  `locale.localized(_:)` and a screen's title from `loeNavigationTitle(_:)`.

## Language

iOS has no Estonian of its own, so a phone set to English would never show
Loe's. Loe keeps its own choice,
[`LoeLanguage`](../Loe/App/LoeLanguage.swift): the phone's language, Estonian
or English, stored on the phone under `language`.

- **Where it is chosen.** The first launch asks before the tastes quiz, with
  the phone's own language chosen, and Settings offers the same three under a
  heading in both languages. A language is named in itself, "Eesti" and
  "English", so a reader finds theirs whatever is showing.
- **How it is applied.** `LoeApp` puts the choice into the environment's
  locale: the phone's locale with only its language changed, so dates, numbers
  and the clock keep the reader's region. SwiftUI's own text follows that
  locale at once, with no relaunch.
- **What needs help.** `String(localized:)` answers in the phone's language
  whatever the environment says, and the navigation bar keeps a title in the
  language its screen first appeared in. So a string built in code comes from
  `locale.localized(_:)`, with the locale read from the environment, and a
  screen's title from `loeNavigationTitle(_:)`. `LoeLanguageTests` fails when
  a file does either the other way.
- **What stays the phone's.** Text iOS draws itself, such as the question
  about the camera and the system's own buttons.
- **Journeys.** Debug builds launched with `-forgetLanguage YES` drop the
  stored choice, so a journey starts from the phone's language. The language
  journeys forget it again when they end, because every other journey reads
  Loe in English.

## State, concurrency, and boundaries

- Use Observation (`@Observable`, never `ObservableObject`). The owner of a
  model's lifetime stores it in `@State`, and controls that need bindings use
  `@Bindable`. A caller's value is never a second source of truth.
- Respect the default `MainActor` isolation. Mark values that cross isolation
  explicitly. Never use `@unchecked Sendable` or broaden isolation to silence
  the compiler. Document and verify the real synchronization contract.
- Models decoded from the wire are `nonisolated struct`s with defensive
  decoding.
- Every async operation has an owner, a cancellation behavior and a policy for
  late results. Load with `.task(id:)`. UI loading must not cancel itself by
  replacing the view branch that owns its task.
- Networking, credentials and response validation live in shared clients.
  Views never assemble their own requests. Every client asks through
  `PrivateSession`, which keeps no cookies, cache or credentials and sends a
  fixed `User-Agent` and `Accept-Language`. `PrivateSessionTests` fails when a
  file builds its own session.
- Add a protocol or package only for a concrete boundary, test seam or reuse
  need. Not for every type.
- A record saved on the device reads every key as optional and falls back
  field by field. A synthesized decoder throws on a key the record lacks, and
  the store then resets everything, so the first build to add a field would
  wipe what the reader saved. Pin the keys and shapes in a test.

## Review and verification

- Keep structural moves separate from behavior changes. After a move, check
  target membership, access control, resource paths and the build.
- Run the relevant tests. Add behavioral coverage for new logic or a
  regression, not tests that restate a file move. A test earns its place by
  failing when the behaviour it names breaks: break the code once and watch
  it fail.
- Verify changed UI in the simulator, in light and dark, in Estonian and
  English, and at accessibility sizes.
- Snapshot tests render a view with `Snapshot.verify` in `LoeTests` and compare
  it with a PNG in `LoeTests/Snapshots/iOS-<version>`, in light English, dark
  Estonian and an accessibility size. Text renders differently on each iOS
  version, so references are kept for each, and a run on a version without a
  folder fails and says so. To only render there, run with
  `TEST_RUNNER_LOE_SNAPSHOTS_RENDER_ONLY=1`. A missing reference is recorded
  and fails the test once: look at it before committing it. To record again,
  delete the PNG, or create the folder for a new runtime. A snapshot may
  differ from its reference by `Snapshot.budget` pixels and no more. That is a
  count and not a share of the image, so a changed icon fails however tall
  the snapshot is.
  A busy CI runner now and then renders an image no PNG can be made from, so
  a render that fails is tried up to three times before the test fails.
  `ImageRenderer` cannot draw a `NavigationStack`, and a `NavigationLink`
  outside one draws as disabled, so a view meant for a snapshot takes what
  opens a book as an action and its screen pushes it onto a path. It also
  leaves out native controls such as a progress bar and anything that scrolls
  sideways, and at the largest text size it does not lay text out as a screen
  does: it can cut short a line that a screen would wrap, and wrap one that a
  screen cuts short. A snapshot of such a view is drawn in a window, with
  `on: .window`: the view sits in a scroll view in a window of the app the
  tests run in, as it does on its screen.
- Journeys in `LoeUITests` launch Loe through
  [`JourneyTestCase`](../LoeUITests/JourneyTestCase.swift), never on their
  own, so each starts the same way: in English on a light phone, on an empty
  in-memory library, searching a
  [small catalogue of their own](catalogue.md#trying-it-in-the-simulator),
  with the quiz out of the way and off the network. Each ends by quitting Loe
  and waiting until it is gone, because a journey that launches while the
  last one's Loe is still on its way out fails on a slow simulator.
- A debug build launched with `-networkStub YES` never reaches the network.
  [`PrivateSession`](../Loe/Shared/Network/PrivateSession.swift) then fails
  every request as it does with no network, so the catalogue's update check
  at launch finds nothing. Open Library, its covers and ESTER answer from
  fixed answers kept beside each client, which
  [Catalogue](catalogue.md#books-from-abroad) and
  [Library](library.md#availability) describe. Every journey passes it, and
  the scheme passes it to the app that hosts the unit tests. The one journey
  that goes on the network downloads a catalogue served from the Mac.
- No new compiler warnings, and no blanket suppression.

### Pull requests

Work reaches `main` through a pull request from a feature branch. The types
are the commit types: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`,
`build`, `chore`, `ci`, `style` and `revert`.

- **Branch:** `<type>/<kebab-case-words>`, such as `feat/shelf-list`.
- **Title:** written like a commit subject, `<type>: <lowercase start>`, at
  most 72 characters, no full stop: `feat: show the reading shelf`.
- **Commits:** a conventional subject line and nothing else: no body, no
  trailers, no scope. Lowercase imperative, such as `feat: add the app icon`.
  One commit per distinct change, not per file: a rename across ten files is
  one commit, while pulling several different things out of a type is
  several. Order them so every intermediate state builds.
- **Description:** a short list and nothing more:

  ```
  Changes:
  - Add the shelf list
  - Show each book's cover at 56 pt
  ```

  One plain line per change. Something the reviewer must act on, such as
  "Needs a device check", is one more line. Rationale goes in the guide that
  owns the area, not the description.
- **No Sentry issue ids or Jira keys** in any of them, or in code comments.
- **Related changes that build on each other** go in a GitHub stack
  (`gh stack`), one pull request per theme, merged from the bottom up.
  Unrelated changes are separate pull requests, never one stack.
- **Every stack is linked on GitHub**, not left as pull requests that only
  target each other's branches. Open each with `gh pr create` against the
  branch below it, so its title and description pass the checks, then link
  them bottom to top with `gh stack link <bottom> <top>`. A linked stack is
  rebased and merged as one, so a follow-up never lands on a stale base.
- **Rebase a branch that falls behind `main`, never merge `main` into it.**
  `main` takes rebase merges only, so a conflict resolved in a merge commit
  comes back on merge. Rebase the branch, and the ones stacked on it, onto
  `origin/main`, resolve each conflict in the commit that causes it, and push
  with `--force-with-lease` (`gh stack sync` does all of it for a stack).
- **Coverage decides where the tests go.** SonarCloud scores each pull
  request on its own and wants 80 % of new code covered. New code in a file
  that `sonar.coverage.exclusions` does not exclude needs the tests that run
  it in the same pull request. In a stack, the feature and its tests are the
  bottom, and anything built on them goes above. Views are excluded, so their
  snapshots can still be a pull request of their own. Check the changed files
  against the exclusions before splitting.

`.github/workflows/conventions.yml` runs `scripts/check-pull-request.sh` on
every pull request and again when its title or description is edited. The
script reads the pull request from the environment, so it runs locally the
same way (usage is at its top). `.githooks/pre-push` runs its branch and
commit checks on every push, and `.githooks/commit-msg` strips attribution
trailers as a commit is made. Turn both on once per clone with
`git config core.hooksPath .githooks`. `.github/CODEOWNERS` names the owner of
every file, whose review GitHub requests on each pull request.

### Continuous integration

`.github/workflows/tests.yml` runs on every pull request and every push to
`main`, never on a schedule:

- **App tests (iOS)**: the unit tests, `LoeTests`, on GitHub's `xcode-27`
  image with Xcode 27.2, on a regular iPhone on the iOS the snapshot
  references are for: the newest folder in `LoeTests/Snapshots` that the image
  has a runtime for. A newer iOS on the image is left alone until its
  references are recorded, and the job fails when the image has a runtime for
  none of the folders. When the local Xcode moves, move `DEVELOPER_DIR` in the
  same change. A test that runs past five minutes fails and the rest still
  run. A run past 25 minutes is stopped as a failure, because the job's own
  limit would cancel it, and a cancelled run keeps nothing. A failed run keeps
  its result bundle and log for 14 days.
- **The journeys do not run on CI.** Its runner takes twice as long over them
  as a Mac and fails them at random. They run on a Mac, with the whole
  scheme, before a pull request is opened. Every journey runs there but the
  two that need the real thing, the README screens and the catalogue download.
- A pull request that changes only Markdown skips the app tests, and a
  skipped job counts as passed for the check `main` requires. A push to `main`
  always runs them.
- **Catalogue build tests**: `tools/catalogue` on Ubuntu.
- **SonarCloud scan**: the app tests collect coverage, and
  `scripts/coverage-to-sonar.py` turns the result bundle into Sonar's format.
  A pull request that skipped the app tests is scanned with an empty report.
  This job then runs the scan with it on Ubuntu, using the `SONAR_TOKEN`
  secret, and SonarCloud's app reports the quality gate on the pull request
  as "SonarCloud Code Analysis". It also runs on each push to `main`, so the
  dashboard for `main` stays current. A fork's pull request has no secrets, so
  it skips the scan. SonarCloud analyses the whole repository and takes no
  list of source or test folders, so `sonar-project.properties` leaves the
  tests out of coverage and out of the check for repeated code, keeps
  snapshots and fixtures out altogether, and leaves views out of coverage:
  files named `*View`, `*Sheet`, `*Picker`, `*Row`, `*Section`, `*Menu`,
  `*Controls` or `*Chip`, `BarcodeScanner.swift`, `TasteQuiz.swift` and
  `Shared/UI`.
  Snapshots, journeys and the simulator check those. A view-only file with another name
  goes on that list. The catalogue's Python is tested but reports no
  coverage, which would need a package the build doesn't otherwise use.
  Automatic analysis in SonarCloud must stay off, or the two analyses
  collide.
- The scan action is the one action from outside GitHub the repository
  allows, and only at the commit the workflow pins (Settings → Actions →
  General lists `SonarSource/sonarqube-scan-action@<commit>`). Moving the pin
  means moving that pattern too, or the scan stops running.

`main` requires the conventions check, both test jobs and SonarCloud's quality
gate. CI is a backstop, not a replacement: run the tests before pushing,
because CI only reports after the push and never runs the journeys.

## Writing

This covers code comments, docs, commit subjects, pull requests and the
changelog.

- Comments explain the reason for a constraint, only when the code cannot
  say it, in one short line where possible. No doc comments added to code
  that had none, no narration, no dead or commented-out code.
- No ticket keys, incident ids, measurement runs, attempt counts or dates in
  source. They belong where the work is tracked.
- No em dashes and no semicolons in prose. Write two sentences, or use a
  comma, a colon or "and".
- Book titles in user-facing text follow the brand: Estonian in „marks“,
  English in italics, never straight quotes.
