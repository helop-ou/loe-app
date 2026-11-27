"""python3 -I -m unittest discover -s tools/catalogue"""
import contextlib
import http.server
import io
import json
import os
import sys
import tempfile
import threading
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_manifest  # noqa: E402

ADDRESS = "https://github.com/helop-ou/loe-app/releases/download/catalogue-2026-11/catalogue.sqlite.xz"
CATALOGUE = {"version": "2026-11", "schema_version": 1, "url": ADDRESS, "sha256": "ab12", "size": 300, "editions": 20}


def published(**changes):
    """A release as GitHub describes it, holding the catalogue above."""
    file = {"name": "catalogue.sqlite.xz", "browser_download_url": ADDRESS, "digest": "sha256:ab12", "size": 300}
    release = {"tag_name": "catalogue-2026-11", "immutable": True, "assets": [file]}
    for key, value in changes.items():
        (release if key in release else file)[key] = value
    return release


class ProblemTests(unittest.TestCase):
    def problems(self, manifest=CATALOGUE, releases=None):
        releases = {"catalogue-2026-11": published()} if releases is None else releases
        self.asked = []

        def release_for(tag):
            self.asked.append(tag)
            return releases.get(tag)

        return check_manifest.problems(manifest, release_for)

    def test_a_catalogue_published_as_the_manifest_says_has_none(self):
        self.assertEqual(self.problems(), [])
        self.assertEqual(self.asked, ["catalogue-2026-11"])

    def test_a_hash_that_is_not_the_files_is_one(self):
        [problem] = self.problems({**CATALOGUE, "sha256": "ab13"})
        self.assertIn("the catalogue of schema 1", problem)
        self.assertIn("the manifest's sha256 is ab13 and the file's is sha256:ab12", problem)

    def test_a_file_github_gives_no_hash_for_is_one(self):
        [problem] = self.problems(releases={"catalogue-2026-11": published(digest=None)})
        self.assertIn("the file's is None", problem)

    def test_a_size_that_is_not_the_files_is_one(self):
        [problem] = self.problems({**CATALOGUE, "size": 301})
        self.assertIn("the manifest's size is 301 and the file's is 300", problem)

    def test_a_release_that_is_not_published_is_one(self):
        address = ADDRESS.replace("2026-11", "2026-12")
        [problem] = self.problems({**CATALOGUE, "url": address})
        self.assertIn("the release catalogue-2026-12 is not published", problem)

    def test_a_release_without_a_file_at_the_address_is_one(self):
        address = ADDRESS.replace("sqlite.xz", "sqlite")
        [problem] = self.problems({**CATALOGUE, "url": address})
        self.assertIn(f"the release catalogue-2026-11 has no file at {address}", problem)

    def test_a_release_whose_file_can_be_replaced_is_one(self):
        for immutable in (False, None):
            [problem] = self.problems(releases={"catalogue-2026-11": published(immutable=immutable)})
            self.assertIn("the release catalogue-2026-11 is not immutable", problem)

    def test_an_address_that_is_no_release_of_the_repository_is_one_and_nobody_is_asked(self):
        for address in (
            ADDRESS.replace("helop-ou", "someone-else"),
            ADDRESS.replace("https://github.com", "https://example.com"),
            ADDRESS.replace("https://", "http://"),
            "https://evil.example/?" + ADDRESS,
            ADDRESS + "/more",
            "",
        ):
            [problem] = self.problems({**CATALOGUE, "url": address})
            self.assertIn("is not a file of a release of helop-ou/loe-app", problem)
            self.assertEqual(self.asked, [])

    def test_an_entry_with_no_address_is_one(self):
        [problem] = self.problems({"schema_version": 1})
        self.assertIn("is not a file of a release", problem)

    def test_the_catalogue_of_every_schema_is_checked(self):
        later = {**CATALOGUE, "schema_version": 2, "url": ADDRESS.replace("2026-11", "2027-03"), "sha256": "cd34"}
        manifest = {**CATALOGUE, "catalogues": [later]}
        both = {
            "catalogue-2026-11": published(),
            "catalogue-2027-03": published(browser_download_url=later["url"], digest="sha256:cd34"),
        }
        self.assertEqual(self.problems(manifest, both), [])
        self.assertEqual(self.asked, ["catalogue-2026-11", "catalogue-2027-03"])

        [problem] = self.problems(manifest, {**both, "catalogue-2027-03": published()})
        self.assertIn("the catalogue of schema 2", problem)
        self.assertIn("has no file at", problem)


class GitHub(http.server.BaseHTTPRequestHandler):
    """Answers as GitHub's API does for one release, and remembers what it was sent."""

    seen = []

    def do_GET(self):
        GitHub.seen.append((self.path, self.headers.get("Authorization")))
        status, body = {
            "/repos/helop-ou/loe-app/releases/tags/catalogue-2026-11": (200, published()),
            "/repos/helop-ou/loe-app/releases/tags/limited": (403, {"message": "API rate limit exceeded"}),
        }.get(self.path, (404, {"message": "Not Found"}))
        self.send_response(status)
        self.end_headers()
        self.wfile.write(json.dumps(body).encode())

    def log_message(self, *args):
        pass


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        GitHub.seen = []
        server = http.server.HTTPServer(("127.0.0.1", 0), GitHub)
        threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.01}, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        api = mock.patch.object(check_manifest, "API", f"http://127.0.0.1:{server.server_port}")
        api.start()
        self.addCleanup(api.stop)
        environment = mock.patch.dict(os.environ)
        environment.start()
        self.addCleanup(environment.stop)
        os.environ.pop("GITHUB_TOKEN", None)

    def test_a_release_is_read_by_its_tag(self):
        self.assertEqual(check_manifest.release("catalogue-2026-11"), published())
        self.assertEqual(GitHub.seen, [("/repos/helop-ou/loe-app/releases/tags/catalogue-2026-11", None)])

    def test_the_token_is_sent_when_there_is_one(self):
        os.environ["GITHUB_TOKEN"] = "a-token"
        check_manifest.release("catalogue-2026-11")
        self.assertEqual(GitHub.seen[0][1], "Bearer a-token")

    def test_a_tag_github_has_no_release_for_is_none(self):
        self.assertIsNone(check_manifest.release("catalogue-2026-12"))

    def test_a_tag_cannot_reach_another_part_of_the_api(self):
        self.assertIsNone(check_manifest.release("../tags/catalogue-2026-11"))
        self.assertEqual(GitHub.seen[0][0], "/repos/helop-ou/loe-app/releases/tags/..%2Ftags%2Fcatalogue-2026-11")

    def test_a_refusal_is_not_taken_for_a_missing_release(self):
        with self.assertRaises(OSError):
            check_manifest.release("limited")

    def run_command(self, manifest):
        errors = io.StringIO()
        with mock.patch.object(check_manifest.build, "MANIFEST", self.written(manifest)):
            with contextlib.redirect_stderr(errors), contextlib.redirect_stdout(io.StringIO()):
                try:
                    check_manifest.main()
                except SystemExit as exit:
                    return exit.code, errors.getvalue()
        return 0, errors.getvalue()

    def written(self, manifest):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = os.path.join(directory.name, "manifest.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(manifest, f)
        return path

    def test_the_command_passes_a_manifest_that_is_published_as_it_says(self):
        self.assertEqual(self.run_command(CATALOGUE), (0, ""))

    def test_the_command_fails_and_names_each_catalogue_that_is_not(self):
        later = {**CATALOGUE, "schema_version": 2, "url": ADDRESS.replace("2026-11", "2026-12")}
        status, errors = self.run_command({**CATALOGUE, "sha256": "ab13", "catalogues": [later]})
        self.assertEqual(status, 1)
        self.assertIn("error: the catalogue of schema 1: the manifest's sha256 is ab13", errors)
        self.assertIn("error: the catalogue of schema 2: the release catalogue-2026-12 is not published", errors)

    def test_the_command_fails_when_github_does_not_answer(self):
        status, _ = self.run_command({**CATALOGUE, "url": ADDRESS.replace("catalogue-2026-11", "limited")})
        self.assertIn("error: could not read a release from GitHub: 403", str(status))


if __name__ == "__main__":
    unittest.main()
