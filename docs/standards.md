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
    Search/
  Shared/
    UI/                        Brand type, colour and components used across features
  Resources/                   Fonts and licence texts
  Assets.xcassets/             Brand colours (from loe-app-branding)
  Loe.icon                     App icon (Icon Composer)
  Localizable.xcstrings        English source, Estonian translation
LoeTests/                      Unit tests, grouped by subject
```

Add `Shared/Models` or `Shared/Persistence` when a second feature needs the
same contract, and a `LoeUITests` target with the first journey.

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
  with its Estonian translation.
- The brand files (`Assets.xcassets/Loe`, `Loe.icon`, the fonts, and the
  tone values in `LoeTone.swift`) are generated in `loe-app-branding`. Change
  them there and copy them over, so the two never drift.

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
  Views never assemble their own requests.
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

`.github/workflows/conventions.yml` runs `scripts/check-pull-request.sh` on
every pull request and again when its title or description is edited. The
script reads the pull request from the environment, so it runs locally the
same way (usage is at its top). `.githooks/pre-push` runs its branch and
commit checks on every push, and `.githooks/commit-msg` strips attribution
trailers as a commit is made. Turn both on once per clone with
`git config core.hooksPath .githooks`. `.github/CODEOWNERS` names the owner of
every file, whose review GitHub requests on each pull request.

### Continuous integration

A tests workflow arrives with the Xcode project and runs the unit suite on
every pull request. CI runs on pull requests and pushes to `main` only,
never on a schedule. It is a backstop, not a replacement: run the tests
before pushing, because CI only reports after the push.

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
