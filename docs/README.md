# Documentation

Start with [Coding standards](standards.md), then read the guide for the area
you are changing. The guides describe the code as it is today.

| Guide | Use it for |
| --- | --- |
| [Coding standards](standards.md) | Project setup, folder structure, state and concurrency, review, pull requests and writing |
| [Library](library.md) | The reader's shelves: storage, iCloud sync and the rules for moving books |
| [Catalogue](catalogue.md) | The offline book catalogue: source, licence, rebuilding, and how each field is read |
| [Release](release.md) | Build numbers, uploading to TestFlight, secrets, and going public safely |

The brand (colours, type, voice, covers, the cover wash and Sinu toon) is
defined in a separate, private brand repository. What the app needs from it is
copied in: the colour sets, `Loe.icon`, the fonts and the tone values. The
[coding standards](standards.md#files-and-reusable-components) say how to
change them.

## Keeping this clean

- Update the guide that owns a contract when you change it. Give each rule one
  home and link to it from elsewhere.
- Long technical investigations go in `reference/`.
- Validation evidence (revision, environment, result, what is owed) belongs
  where the work is tracked, not in a guide.
- Keep routine session history out of the guides.
