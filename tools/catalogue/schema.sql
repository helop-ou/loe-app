-- The offline catalogue Loe searches. Built by tools/catalogue/build.py from the
-- Estonian National Bibliography. The app refuses a file whose schema_version it
-- does not know, so bump it with any change here. See docs/catalogue.md.

PRAGMA page_size = 4096;

CREATE TABLE meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
) WITHOUT ROWID;

CREATE TABLE edition (
  id INTEGER PRIMARY KEY,
  erb_id TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  subtitle TEXT,
  authors TEXT,
  translators TEXT,
  year INTEGER,
  publisher TEXT,
  place TEXT,
  language TEXT,
  original_title TEXT,
  original_language TEXT,
  edition_statement TEXT,
  series TEXT,
  series_number TEXT,
  pages INTEGER,
  fiction INTEGER NOT NULL,
  electronic INTEGER NOT NULL
);

CREATE TABLE isbn (
  isbn13 TEXT NOT NULL,
  edition_id INTEGER NOT NULL REFERENCES edition(id),
  qualifier TEXT
);
CREATE INDEX isbn_by_number ON isbn(isbn13);

-- Subject headings (650) and genres (655), shared across editions.
CREATE TABLE heading (
  id INTEGER PRIMARY KEY,
  kind INTEGER NOT NULL,
  name TEXT NOT NULL,
  ems_id TEXT,
  UNIQUE (kind, name)
);

CREATE TABLE edition_heading (
  edition_id INTEGER NOT NULL REFERENCES edition(id),
  heading_id INTEGER NOT NULL REFERENCES heading(id),
  PRIMARY KEY (edition_id, heading_id)
) WITHOUT ROWID;
CREATE INDEX edition_heading_by_heading ON edition_heading(heading_id, edition_id);

CREATE VIRTUAL TABLE edition_search USING fts5(
  title, authors, series, original_title,
  content = 'edition', content_rowid = 'id',
  tokenize = "unicode61 remove_diacritics 2"
);
