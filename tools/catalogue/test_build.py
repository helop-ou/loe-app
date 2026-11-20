"""python3 -I -m unittest discover -s tools/catalogue"""
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build  # noqa: E402

FIXED = "740101s1974    et a          000 1 est d"  # 008: 1974, fiction, Estonian


def field(tag, *subs, ind1=" ", ind2=" "):
    inner = "".join(f'<subfield code="{c}">{v}</subfield>' for c, v in subs)
    return f'<datafield tag="{tag}" ind1="{ind1}" ind2="{ind2}">{inner}</datafield>'


def record(id, *fields, leader="00000cam a2200000 i 4500", fixed=FIXED, control=""):
    return (
        f"<record><leader>{leader}</leader>"
        f'<controlfield tag="001">{id}</controlfield>{control}'
        f'<controlfield tag="008">{fixed}</controlfield>{"".join(fields)}</record>'
    )


TODE_JA_OIGUS = record(
    "b10500820",
    field("020", ("a", "9789916099896"), ("q", "(pdf)")),
    field("100", ("a", "Tammsaare, A. H.,"), ("d", "1878-1940,"), ("e", "autor."), ind1="1"),
    field("245", ("a", "Tõde ja õigus :"), ("b", "romaan."), ("n", "1. [kd.] /"), ("c", "A. H. Tammsaare."), ind1="1", ind2="0"),
    field("260", ("a", "Tallinn :"), ("b", "Eesti Raamat,"), ("c", "1974"), ("e", "(Tallinn :"), ("f", "Ühiselu)")),
    field("300", ("a", "534, [2] lk. :"), ("b", "ill. ;")),
    field("490", ("a", "Kooli kirjandus ;"), ("v", "4."), ind1="0"),
    field("650", ("a", "külaelu"), ("0", "https://ems.elnet.ee/id/EMS019465."), ind2="4"),
    field("655", ("a", "romaanid (vormimärksõna)"), ind2="4"),
)

TRANSLATION = record(
    "b20000001",
    field("041", ("a", "est"), ("h", "fre"), ind1="1"),
    field("100", ("a", "Montesquieu,"), ("e", "autor."), ind1="1"),
    field("245", ("a", "Pärsia kirjad /"), ind1="1", ind2="0"),
    field("246", ("a", "Lettres persanes."), ("g", "Eesti keeles."), ind1="1", ind2="9"),
    field("260", ("a", "[S.l.] :"), ("b", "[s.n.],"), ("c", "1966")),
    field("700", ("a", "Hollo, Anselm,"), ("d", "1934-2013,"), ("e", "tõlkija."), ind1="1"),
)

THESIS = record("b30000001", field("245", ("a", "Väitekiri.")), field("502", ("a", "Doktoritöö")))
MAP = record("b30000002", field("245", ("a", "Kaart.")), leader="00000cem a2200000 i 4500")
DIGITAL_COPY = record(
    "b30000003",
    field("245", ("a", "Tõde ja õigus.")),
    field("588", ("a", "Digikoopia andmed loodud automaatselt.")),
)


def collection(*records):
    return '<collection xmlns="http://www.loc.gov/MARC21/slim">' + "".join(records) + "</collection>"


class CleaningTests(unittest.TestCase):
    def test_strips_isbd_punctuation_and_brackets(self):
        self.assertEqual(build.clean("Tõde ja õigus :"), "Tõde ja õigus")
        self.assertEqual(build.clean("[jutustus] /"), "jutustus")
        self.assertEqual(build.clean("Eesti Raamat,"), "Eesti Raamat")

    def test_keeps_the_full_stop_of_initials_and_abbreviations(self):
        self.assertEqual(build.clean("Tammsaare, A. H."), "Tammsaare, A. H.")
        self.assertEqual(build.clean("1. kd."), "1. kd.")
        self.assertEqual(build.clean("romaan."), "romaan")
        self.assertEqual(build.clean("4."), "4")
        self.assertEqual(build.clean("Repr."), "Repr.")
        self.assertEqual(build.clean("2. uppl."), "2. uppl.")

    def test_puts_given_names_first(self):
        self.assertEqual(build.person("Tammsaare, A. H.,"), "A. H. Tammsaare")
        self.assertEqual(build.person("Montesquieu,"), "Montesquieu")

    def test_isbn_normalises_to_13_digits(self):
        self.assertEqual(build.isbn13("544001361X"), "9785440013612")
        self.assertIsNone(build.isbn13("5440013611"))
        self.assertEqual(build.isbn13("0-306-40615-2"), "9780306406157")
        self.assertEqual(build.isbn13("978-9949-633-28-9"), "9789949633289")
        self.assertEqual(build.isbn13("9789949445707(vale)"), "9789949445707")
        self.assertIsNone(build.isbn13("9789949445708"))

    def test_an_isbn_written_with_spaces_is_read(self):
        self.assertEqual(build.isbn13("978 9949 633 28 9"), "9789949633289")
        self.assertEqual(build.isbn13("978-9949-633 28 9 (köites)"), "9789949633289")
        self.assertEqual(build.isbn13("0 306 40615 2"), "9780306406157")

    def test_text_after_an_isbn_is_never_joined_into_it(self):
        self.assertEqual(build.isbn13("9789949633289 5 (köites)"), "9789949633289")
        self.assertEqual(build.isbn13("9789949633289 hind 12 eurot"), "9789949633289")
        self.assertIsNone(build.isbn13("978 9949 633 28 hind 9"))
        self.assertIsNone(build.isbn13("978 9949 633 28 9 5.50"))

    def test_an_x_anywhere_but_last_in_an_isbn_10_is_not_an_isbn(self):
        self.assertIsNone(build.isbn13("0X00000009"))
        self.assertIsNone(build.isbn13("X306406152"))

    def test_a_dirty_isbn_does_not_stop_the_build(self):
        with tempfile.TemporaryDirectory() as directory:
            source = os.path.join(directory, "erb.xml")
            dirty = record(
                "b40000001",
                field("020", ("a", "0X00000009")),
                field("020", ("a", "9789916099896")),
                field("245", ("a", "Raamat")),
            )
            with open(source, "w", encoding="utf-8") as f:
                f.write(collection(dirty))
            out = os.path.join(directory, "catalogue.sqlite")
            build.build(out, [source], log=lambda _: None, allow_small=True)
            db = sqlite3.connect(out)
            self.assertEqual(db.execute("SELECT isbn13 FROM isbn").fetchall(), [("9789916099896",)])
            db.close()

    def test_a_spaced_isbn_is_kept_in_the_catalogue(self):
        with tempfile.TemporaryDirectory() as directory:
            source = os.path.join(directory, "erb.xml")
            spaced = record("b40000002", field("020", ("a", "978 9949 633 28 9"), ("q", "(köites)")), field("245", ("a", "Raamat")))
            with open(source, "w", encoding="utf-8") as f:
                f.write(collection(spaced))
            out = os.path.join(directory, "catalogue.sqlite")
            build.build(out, [source], log=lambda _: None, allow_small=True)
            db = sqlite3.connect(out)
            self.assertEqual(db.execute("SELECT isbn13, qualifier FROM isbn").fetchall(), [("9789949633289", "köites")])
            db.close()

    def test_page_counts(self):
        self.assertEqual(build.pages("189, [3] lk. :"), 189)
        self.assertEqual(build.pages("320 lehekülge :"), 320)
        self.assertEqual(build.pages("[89] lk. koos kaanega :"), 89)
        self.assertEqual(build.pages("534 lk., 12 l. ill. :"), 534)
        self.assertIsNone(build.pages("Lk. 23-45"))
        self.assertIsNone(build.pages("1 kaart"))


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        source = os.path.join(self.directory.name, "erb.xml")
        with open(source, "w", encoding="utf-8") as f:
            f.write(collection(TODE_JA_OIGUS, TRANSLATION, THESIS, MAP, DIGITAL_COPY))
        self.out = os.path.join(self.directory.name, "catalogue.sqlite")
        self.kept, self.skipped = build.build(self.out, [source], latest_year=2026, log=lambda _: None, allow_small=True)
        self.db = sqlite3.connect(self.out)
        self.db.row_factory = sqlite3.Row

    def tearDown(self):
        self.db.close()
        self.directory.cleanup()

    def edition(self, erb_id):
        return self.db.execute("SELECT * FROM edition WHERE erb_id = ?", (erb_id,)).fetchone()

    def test_keeps_books_and_says_why_it_skipped_the_rest(self):
        self.assertEqual(self.kept, 2)
        self.assertEqual(
            self.skipped,
            {"thesis": 1, "not text": 1, "digital copy of a print record": 1},
        )

    def test_reads_a_novel(self):
        book = self.edition("b10500820")
        self.assertEqual(book["title"], "Tõde ja õigus. 1. kd.")
        self.assertEqual(book["subtitle"], "romaan")
        self.assertEqual(book["authors"], "A. H. Tammsaare")
        self.assertEqual(book["year"], 1974)
        self.assertEqual(book["publisher"], "Eesti Raamat")
        self.assertEqual(book["place"], "Tallinn")
        self.assertEqual(book["pages"], 534)
        self.assertEqual(book["series"], "Kooli kirjandus")
        self.assertEqual(book["series_number"], "4")
        self.assertEqual(book["language"], "est")
        self.assertEqual(book["fiction"], 1)

    def test_links_a_translation_to_its_original(self):
        book = self.edition("b20000001")
        self.assertEqual(book["original_title"], "Lettres persanes")
        self.assertEqual(book["original_language"], "fre")
        self.assertEqual(book["translators"], "Anselm Hollo")
        self.assertEqual(book["authors"], "Montesquieu")

    def test_unknown_publisher_and_place_are_empty(self):
        book = self.edition("b20000001")
        self.assertIsNone(book["publisher"])
        self.assertIsNone(book["place"])

    def test_isbns_keep_their_qualifier(self):
        rows = self.db.execute("SELECT isbn13, qualifier FROM isbn").fetchall()
        self.assertEqual([tuple(r) for r in rows], [("9789916099896", "pdf")])

    def test_subjects_and_genres_are_shared_headings(self):
        rows = self.db.execute(
            "SELECT kind, name, ems_id FROM heading JOIN edition_heading ON heading.id = heading_id ORDER BY kind"
        ).fetchall()
        self.assertEqual(
            [tuple(r) for r in rows],
            [(build.SUBJECT, "külaelu", "EMS019465"), (build.GENRE, "romaanid", None)],
        )

    def test_search_ignores_diacritics(self):
        rows = self.db.execute(
            "SELECT title FROM edition_search WHERE edition_search MATCH 'tode oigus'"
        ).fetchall()
        self.assertEqual([r["title"] for r in rows], ["Tõde ja õigus. 1. kd."])

    def test_search_finds_a_translation_by_its_original_title(self):
        rows = self.db.execute(
            "SELECT title FROM edition_search WHERE edition_search MATCH 'persanes'"
        ).fetchall()
        self.assertEqual([r["title"] for r in rows], ["Pärsia kirjad"])

    def test_records_its_schema_version(self):
        version = self.db.execute("SELECT value FROM meta WHERE key = 'schema_version'").fetchone()[0]
        self.assertEqual(version, str(build.SCHEMA_VERSION))

    def test_the_summary_counts_isbn_values_that_held_no_valid_isbn(self):
        with tempfile.TemporaryDirectory() as directory:
            source = os.path.join(directory, "erb.xml")
            book = record(
                "b40000003",
                field("020", ("a", "9789916099896")),
                field("020", ("a", "0X00000009"), ("a", "5440013611")),
                field("020", ("a", "9789916099896")),
                field("245", ("a", "Raamat")),
            )
            with open(source, "w", encoding="utf-8") as f:
                f.write(collection(book, TODE_JA_OIGUS))
            lines = []
            build.build(os.path.join(directory, "catalogue.sqlite"), [source], log=lines.append, allow_small=True)
            self.assertIn("dropped 2 ISBN values that were not valid", lines)


class ConvertTests(unittest.TestCase):
    def convert(self, *fields, fixed=FIXED):
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "erb.xml")
            with open(path, "w", encoding="utf-8") as f:
                f.write(collection(record("b40000004", *fields, fixed=fixed)))
            return build.convert(next(build.read(path)), 2026)

    def test_a_language_code_that_is_not_a_language_is_stored_as_none(self):
        title = field("245", ("a", "Raamat"))
        for code in ("|||", "   ", ""):
            self.assertIsNone(self.convert(title, fixed=FIXED[:35] + code + FIXED[38:]).language, repr(code))
        self.assertIsNone(self.convert(title, fixed=FIXED[:30]).language)
        self.assertEqual(self.convert(title, fixed=FIXED[:35] + "eng" + FIXED[38:]).language, "eng")


class RefusalTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.out = os.path.join(self.directory.name, "catalogue.sqlite")

    def tearDown(self):
        self.directory.cleanup()

    def source(self, text, name="erb.xml"):
        path = os.path.join(self.directory.name, name)
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        return path

    def run_script(self, *arguments):
        script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build.py")
        return subprocess.run([sys.executable, "-I", script, *arguments], capture_output=True, text=True)

    def test_a_build_that_kept_nothing_fails_and_leaves_no_file(self):
        source = self.source(collection(THESIS, MAP))
        for allow_small in (False, True):
            with self.assertRaisesRegex(build.BuildError, "kept no records"):
                build.build(self.out, [source], log=lambda _: None, allow_small=allow_small)
            self.assertFalse(os.path.exists(self.out))

    def test_input_without_the_marc_namespace_keeps_nothing(self):
        source = self.source(f"<collection>{TODE_JA_OIGUS}</collection>")
        with self.assertRaisesRegex(build.BuildError, "kept no records"):
            build.build(self.out, [source], log=lambda _: None, allow_small=True)
        self.assertFalse(os.path.exists(self.out))

    def test_an_empty_file_fails_and_leaves_no_file(self):
        with self.assertRaisesRegex(build.BuildError, "not readable XML"):
            build.build(self.out, [self.source("")], log=lambda _: None, allow_small=True)
        self.assertFalse(os.path.exists(self.out))

    def test_far_fewer_records_than_were_published_fails_without_allow_small(self):
        source = self.source(collection(TODE_JA_OIGUS, TRANSLATION))
        with self.assertRaisesRegex(build.BuildError, "under 90%"):
            build.build(self.out, [source], log=lambda _: None)
        self.assertFalse(os.path.exists(self.out))

    def test_allow_small_keeps_a_sample(self):
        source = self.source(collection(TODE_JA_OIGUS, TRANSLATION))
        kept, _ = build.build(self.out, [source], log=lambda _: None, allow_small=True)
        self.assertEqual(kept, 2)
        self.assertTrue(os.path.exists(self.out))

    def test_the_limit_is_ninety_percent_of_the_published_count(self):
        with mock.patch.object(build, "MANIFEST", self.source('{"editions": 20}', "manifest.json")):
            build.check_size(18, allow_small=False)
            with self.assertRaises(build.BuildError):
                build.check_size(17, allow_small=False)

    def test_the_command_exits_non_zero_with_a_message_and_no_file(self):
        result = self.run_script(self.out, self.source(collection(THESIS)))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("kept no records", result.stderr)
        self.assertFalse(os.path.exists(self.out))

    def test_the_command_takes_allow_small_before_or_after_the_paths(self):
        source = self.source(collection(TODE_JA_OIGUS))
        for arguments in (("--allow-small", self.out, source), (self.out, source, "--allow-small")):
            result = self.run_script(*arguments)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(os.path.exists(self.out))
            os.remove(self.out)

    def test_a_failed_integrity_check_fails_the_build_and_leaves_no_file(self):
        source = self.source(collection(TODE_JA_OIGUS))
        with mock.patch.object(build, "check_integrity", side_effect=build.BuildError("damaged")) as check:
            with self.assertRaisesRegex(build.BuildError, "damaged"):
                build.build(self.out, [source], log=lambda _: None, allow_small=True)
        check.assert_called_once()
        self.assertFalse(os.path.exists(self.out))

    def test_a_corrupted_file_fails_the_integrity_check(self):
        build.build(self.out, [self.source(collection(TODE_JA_OIGUS))], log=lambda _: None, allow_small=True)
        db = sqlite3.connect(self.out)
        build.check_integrity(db)
        db.close()
        with open(self.out, "r+b") as f:
            f.seek(4096 * 2)
            f.write(b"\xff" * 4096)
        db = sqlite3.connect(self.out)
        with self.assertRaises(build.BuildError):
            build.check_integrity(db)
        db.close()


if __name__ == "__main__":
    unittest.main()
