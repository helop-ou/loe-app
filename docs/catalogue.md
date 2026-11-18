# Catalogue

Loe searches an offline copy of the Estonian National Bibliography (ERB): every
book published in Estonia, in Estonian and in other languages. It is one SQLite
file, built by [`tools/catalogue/build.py`](../tools/catalogue/build.py) from
the National Library's open data, with the schema in
[`tools/catalogue/schema.sql`](../tools/catalogue/schema.sql).

## Source

| Set | Export | Records (November 2026) |
| --- | --- | --- |
| Books in Estonian (`raamat`) | `https://data.digar.ee/erb/ERB_eestikeelne_raamat.zip` | 232,181 |
| Books in other languages (`muukeelne`) | `https://data.digar.ee/erb/ERB_muukeelne_raamat.zip` | 92,205 |

The same records are served over OAI-PMH at
`https://data.digar.ee/repox/OAIHandler` (sets `raamat` and `muukeelne`,
`metadataPrefix=marc21xml`). Its datestamps are bulk reload dates, not edit
dates, it publishes no deletions, and the weekly change feed on data.digar.ee
has been empty since 2023. So every build starts from the full exports and
replaces the whole file. There is no incremental update.

**Licence.** Zenodo, the RaRa Digilab and andmed.eesti.ee publish the
bibliography as CC0 1.0. One page on data.digar.ee says CC BY-SA 3.0 EE
instead. Loe credits the National Library of Estonia in the app either way.

The bibliography only holds books published in Estonia. An English translation
of an Estonian novel published abroad is not in it.

## Rebuilding

```sh
mkdir -p /tmp/erb && cd /tmp/erb
curl -O https://data.digar.ee/erb/ERB_eestikeelne_raamat.zip
curl -O https://data.digar.ee/erb/ERB_muukeelne_raamat.zip
cd -
python3 -I tools/catalogue/build.py /tmp/erb/catalogue.sqlite /tmp/erb/ERB_*.zip
xz -9 -k /tmp/erb/catalogue.sqlite
```

A build takes about a minute. It prints how many records it kept and why it
skipped the rest. Run the tests with
`python3 -I -m unittest discover -s tools/catalogue`.

The November 2026 build kept 312,349 editions. It is 123 MB, or 31 MB as xz,
which the app can unpack with Apple's Compression framework.

## What is kept

Skipped: records that are not text (maps, music), doctoral theses (a 502
note), and the digital copies the library now creates automatically beside a
print record (a 588 note starting "Digikoopia").

Each remaining record is one row in `edition`, read like this:

| Column | MARC | Notes |
| --- | --- | --- |
| `erb_id` | 001 | The ESTER record number, such as `b10500820` |
| `title` | 245 `$a`, `$n`, `$p` | ISBD punctuation and cataloguer brackets removed, part numbers joined with ". " |
| `subtitle` | 245 `$b` | |
| `authors` | 100, and 700 with the role autor or kaasautor | Given name first. Falls back to koostaja (compiler) for anthologies. The role is only ever an Estonian word in `$e`, never a `$4` code |
| `translators` | 700 with the role tõlkija | |
| `year` | 008/07-10, else 264 or 260 `$c` | Years after next year are dropped as errors |
| `publisher`, `place` | 264 (second indicator 1), else 260 | "s.n." and "S.l." become empty |
| `language` | 008/35-37 | |
| `original_title` | 240, else 246 with second indicator 9, else a "Tõlgitud …:" note | 246 with indicator 9 is ERB's own convention and its main source |
| `original_language` | 041 `$h` | `und` and `mul` become empty |
| `series`, `series_number` | 490, else 830 or 800 | Numbers stay text: "2. kd." |
| `pages` | 300 `$a` | Numbered pages before bracketed ones. Offprint ranges give none |
| `fiction` | 008/33 | Novels, drama, humour, short stories, poetry or unspecified fiction |
| `electronic` | 007, 300 | Born digital, not a print book with a scanned copy |

`isbn` holds every valid ISBN as 13 digits with its qualifier (`pdf`,
`köites`, `vale` for a wrong ISBN printed on the book). Keep `vale`: it is
what a barcode scan of that book returns. Volumes of a set can share one ISBN.

`heading` holds subject headings (650, from the Estonian Subject Thesaurus,
with its EMS id) and genres (655), and `edition_heading` links them.

`edition_search` is an FTS5 index over title, authors, series and original
title that ignores diacritics: "tode" finds „Tõde“. It does not forgive typos.
