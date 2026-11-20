# Name and brand assets

Loe's source code is licensed under the Mozilla Public License 2.0, in
[LICENSE](LICENSE). This file describes the one thing that licence does not
give you.

**The Loe name, the „Loe“ marks, the wordmark, the app icon and the other brand
artwork are not part of the grant.** MPL-2.0 covers every file in a repository
by default, so this is an explicit carve-out. It applies to `Loe/Loe.icon`, the
colour sets and the title wordmark in `Loe/Assets.xcassets/Loe`, the images in
`.github/readme`, and the brand sources, which are kept in a separate
repository and are not published.

## What you may do

Fork the code, build it, change it and ship it, under the terms in LICENSE.
Nothing here narrows those terms for the source.

## What to change first

Give your fork its own name and its own artwork before you distribute it. A
build that calls itself Loe and wears Loe's marks is one that people will
report bugs about to this project, which is the practical reason for the
carve-out as much as the legal one.

Renaming means the display name, the icon and colour assets, the bundle
identifiers and the iCloud container in `Loe.entitlements`.

## What stays true

Say where it came from. MPL-2.0 already requires the licence notice to travel
with the files it covers, and this project's interest is attribution rather
than getting changes back.

Referring to Loe by name to say what your fork is based on, or to discuss or
review the project, is normal nominative use and needs no permission.

## What is licensed separately

- **Newsreader**, the typeface, is © The Newsreader Project Authors under the
  SIL Open Font License 1.1, in
  [`Loe/Resources/Licenses`](Loe/Resources/Licenses).
- **The catalogue** is built from the Estonian National Bibliography
  (Eesti rahvusbibliograafia), published by the National Library of Estonia as
  open data. See [docs/catalogue.md](docs/catalogue.md).

Copyright © Helop OÜ. Loe is a project of Helop OÜ.
