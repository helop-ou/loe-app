# Security policy

## Supported versions

Loe ships as one moving build. Only the newest build in TestFlight is
supported, and the current App Store release once there is one. Fixes land in
the next build, not in patches to older ones. Settings → About Loe shows the
version and build you are running.

## Reporting a vulnerability

Please report privately and not in an issue, and give the fix a chance to ship
before describing the problem publicly.

- Use GitHub's [private vulnerability
  reporting](https://github.com/helop-ou/loe-app/security/advisories/new), or
  email **kontakt@helop.ee**.
- Include the app version and build, the iOS version and the iPhone, what an
  attacker could achieve, and the steps to reproduce it.
- Say whether you want credit, and under what name.

There is no bug bounty. Loe is maintained by one person, so expect an
acknowledgement within about a week, an assessment after that, and a note when
the fix is in a build. If you have not heard back in two weeks, send a
reminder.

## What Loe talks to

Loe has no account and no server of its own. It talks to GitHub for its book
catalogue, to ESTER for library copies, to Open Library and the Internet
Archive for books from abroad and covers, and to the reader's own iCloud for
their shelves. [Privacy](docs/release.md#privacy) lists exactly what is sent
where, and Settings → About Loe → Privacy tells readers the same.

The catalogue is the one file Loe downloads and opens. The app checks it
against the SHA-256 in the manifest on `main` before unpacking it, as
[Catalogue](docs/catalogue.md#download-and-updates) describes, so reports
about that path are especially welcome.

Vulnerabilities in ESTER, Open Library, the Internet Archive or iCloud belong
to those services. Report them there.
