"""python3 -I -m unittest discover -s scripts

Runs the upload script in a throwaway repository with a remote of its own.
`xcodebuild` is a stand-in that writes down how it was called, so nothing is
built or uploaded, and no key is read. `gh` is a stand-in that answers with
the checks a test gives it, one "name<tab>result" to a line, which is what the
script asks GitHub for.
"""
import os
import pathlib
import shutil
import stat
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parent / "upload-testflight.sh"

XCODEBUILD = """#!/usr/bin/env bash
echo "$*" >> "$STUB_CALLS"
case "$1" in
    -version)
        echo "Xcode 27.2"
        ;;
    archive)
        while [[ $# -gt 0 && "$1" != -project ]]; do shift; done
        (cd "$(dirname "$2")" && git rev-parse HEAD && find . -type f -not -path './.git') > "$STUB_ARCHIVED"
        exit "${STUB_ARCHIVE_STATUS:-0}"
        ;;
    -exportArchive)
        exit "${STUB_UPLOAD_STATUS:-0}"
        ;;
esac
"""

GH = """#!/usr/bin/env bash
echo "$*" > "$STUB_ASKED"
cat "$STUB_CHECKS"
"""

PASSED = {
    "SonarCloud Code Analysis": "success",
    "SonarCloud scan": "success",
    "App tests (iOS)": "success",
    "Catalogue build tests": "success",
    "What changed": "success",
}


class Upload(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.origin = self.tmp / "origin.git"
        self.work = self.tmp / "work"
        self.calls = self.tmp / "calls"
        self.record = self.tmp / "archived"

        stubs = self.tmp / "stubs"
        stubs.mkdir()
        self.stub(stubs / "xcodebuild", XCODEBUILD)
        self.stub(stubs / "gh", GH)
        self.asked = self.tmp / "asked"
        self.checks = self.tmp / "checks"
        self.check(PASSED)
        key = self.tmp / "key.p8"
        key.write_text("not a key")
        key.chmod(0o600)
        self.env = {
            "PATH": f"{stubs}{os.pathsep}{os.environ['PATH']}",
            "HOME": str(self.tmp),
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_SYSTEM": os.devnull,
            "GIT_AUTHOR_NAME": "Loe",
            "GIT_AUTHOR_EMAIL": "loe@example.com",
            "GIT_COMMITTER_NAME": "Loe",
            "GIT_COMMITTER_EMAIL": "loe@example.com",
            "ASC_KEY_ID": "KEYID",
            "ASC_ISSUER_ID": "issuer",
            "ASC_KEY_PATH": str(key),
            "STUB_CALLS": str(self.calls),
            "STUB_ARCHIVED": str(self.record),
            "STUB_ASKED": str(self.asked),
            "STUB_CHECKS": str(self.checks),
        }

        self.git("init", "--quiet", "--bare", "--initial-branch=main", str(self.origin), cwd=self.tmp)
        self.git("clone", "--quiet", str(self.origin), str(self.work), cwd=self.tmp)
        self.git("switch", "--quiet", "-c", "main")
        self.write("scripts/upload-testflight.sh", SCRIPT.read_text())
        (self.work / "scripts/upload-testflight.sh").chmod(0o755)
        self.write("scripts/synced-models.txt", "ShelvedBook.title\n")
        self.write("scripts/synced-models.deployed.txt", "ShelvedBook.title\n")
        self.write("Loe.xcodeproj/project.pbxproj", "\t\t\t\tMARKETING_VERSION = 0.1.0;\n\t\t\t\tMARKETING_VERSION = 0.1.0;\n")
        self.write("ExportOptions.plist", "<plist/>\n")
        self.write(".gitignore", "build/\n")
        self.commit("first")
        self.write("Loe/App.swift", "// the app\n")
        self.commit("second")
        self.git("push", "--quiet", "origin", "main")

    def stub(self, path, text):
        path.write_text(text)
        path.chmod(path.stat().st_mode | stat.S_IXUSR)

    def check(self, results):
        self.checks.write_text("".join(f"{name}\t{result}\n" for name, result in results.items()))

    def git(self, *args, cwd=None):
        result = subprocess.run(
            ["git", *args], cwd=cwd or self.work, env=self.env, capture_output=True, text=True, check=True
        )
        return result.stdout.strip()

    def write(self, name, text):
        path = self.work / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def commit(self, subject):
        self.git("add", "--all")
        self.git("commit", "--quiet", "-m", subject)

    def upload(self, *args, checkout=None, **env):
        return subprocess.run(
            [str((checkout or self.work) / "scripts/upload-testflight.sh"), *args],
            cwd=self.tmp, env={**self.env, **env}, capture_output=True, text=True,
        )

    def tags(self):
        return self.git("tag", "--list", cwd=self.origin).split()

    def refused(self, result, words):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(words, result.stderr)
        self.assertFalse(self.calls.exists(), "xcodebuild ran for an upload that was refused")

    def archived(self):
        commit, *files = self.record.read_text().split()
        return commit, files

    def test_a_dry_run_names_the_build_and_builds_nothing(self):
        result = self.upload("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"Loe 0.1.0 (2) from {self.git('rev-parse', '--short', 'main')}", result.stdout)
        self.assertFalse(self.calls.exists())
        self.assertFalse((self.work / "build").exists())

    def test_an_upload_archives_main_with_its_commit_count_as_the_build_number(self):
        result = self.upload()
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls.read_text().splitlines()
        self.assertEqual(calls[0], "-version")
        self.assertTrue(calls[1].startswith("archive "), calls)
        self.assertIn(" CURRENT_PROJECT_VERSION=2 ", calls[1])
        self.assertTrue(calls[2].startswith("-exportArchive "), calls)
        self.assertIn("Xcode 27.2", (self.work / "build/archive.log").read_text())

    def test_what_the_checkout_holds_stays_out_of_the_archive(self):
        self.git("switch", "--quiet", "-c", "feat/elsewhere")
        self.write("Loe/Unmerged.swift", "// not on main\n")
        self.commit("third")
        self.write("Loe/Stray.swift", "// never committed\n")
        self.write("Loe/App.swift", "// changed here\n")

        result = self.upload()
        self.assertEqual(result.returncode, 0, result.stderr)
        commit, files = self.archived()
        self.assertEqual(commit, self.git("rev-parse", "origin/main"))
        self.assertIn("./Loe/App.swift", files)
        self.assertNotIn("./Loe/Unmerged.swift", files)
        self.assertNotIn("./Loe/Stray.swift", files)
        self.assertIn(" CURRENT_PROJECT_VERSION=2 ", self.calls.read_text())

    def test_the_worktree_is_gone_after_a_failed_upload_and_after_one_that_worked(self):
        self.assertNotEqual(self.upload(STUB_ARCHIVE_STATUS="65").returncode, 0)
        self.assertEqual(len(self.git("worktree", "list").splitlines()), 1)
        self.assertEqual(self.upload().returncode, 0)
        self.assertEqual(len(self.git("worktree", "list").splitlines()), 1)

    def test_an_upload_tags_the_commit_on_main_with_its_build_number(self):
        self.git("switch", "--quiet", "-c", "feat/elsewhere")
        self.write("Loe/Unmerged.swift", "// not on main\n")
        self.commit("third")

        result = self.upload()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("tagged it build-2", result.stdout)
        self.assertEqual(self.tags(), ["build-2"])
        self.assertEqual(self.git("rev-parse", "build-2^{commit}", cwd=self.origin), self.git("rev-parse", "origin/main"))
        self.assertEqual(
            self.git("tag", "--list", "--format=%(contents:subject)", "build-2", cwd=self.origin), "Loe 0.1.0 (2)"
        )

    def test_nothing_is_tagged_by_a_dry_run_or_by_an_upload_that_failed(self):
        self.assertEqual(self.upload("--dry-run").returncode, 0)
        self.assertNotEqual(self.upload(STUB_ARCHIVE_STATUS="65").returncode, 0)
        self.assertNotEqual(self.upload(STUB_UPLOAD_STATUS="70").returncode, 0)
        self.assertEqual(self.tags(), [])
        self.assertEqual(self.git("tag", "--list"), "")

    def test_a_build_that_has_its_tag_is_not_uploaded_again(self):
        self.assertEqual(self.upload().returncode, 0)
        self.calls.unlink()
        for args in ([], ["--dry-run"]):
            with self.subTest(args=args):
                self.refused(self.upload(*args), "Build 2 was already uploaded: build-2 exists")

    def test_a_tag_that_could_not_be_made_is_said_after_the_upload(self):
        result = self.upload(GIT_COMMITTER_NAME="", GIT_COMMITTER_EMAIL="")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("-exportArchive", self.calls.read_text())
        self.assertIn("Uploaded, but", result.stderr)
        self.assertIn("could not be tagged build-2", result.stderr)

    def test_a_tag_that_did_not_reach_origin_is_said_and_stops_the_next_upload(self):
        self.stub(self.origin / "hooks/pre-receive", "#!/bin/sh\nexit 1\n")
        result = self.upload()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Uploaded, but build-2 did not reach origin", result.stderr)
        self.assertEqual(self.tags(), [])

        self.calls.unlink()
        self.refused(self.upload(), "build-2 is still to push: git push origin refs/tags/build-2")

    def test_a_script_that_is_not_the_one_on_main_is_refused(self):
        with open(self.work / "scripts/upload-testflight.sh", "a") as script:
            script.write("# changed here\n")
        self.refused(self.upload("--dry-run"), "This script is not the one on main")

    def test_synced_models_that_main_has_not_recorded_as_deployed_are_refused(self):
        self.write("scripts/synced-models.txt", "ShelvedBook.title\nShelvedBook.finished\n")
        self.commit("third")
        self.git("push", "--quiet", "origin", "main")
        result = self.upload("--dry-run")
        self.refused(result, "The synced models changed")
        self.assertIn("> ShelvedBook.finished", result.stderr)

    def test_the_deployed_record_is_read_from_main_and_not_from_the_checkout(self):
        self.write("scripts/synced-models.deployed.txt", "ShelvedBook.title\nShelvedBook.finished\n")
        self.assertEqual(self.upload("--dry-run").returncode, 0)

    def test_a_shallow_clone_is_refused(self):
        shallow = self.tmp / "shallow"
        self.git("clone", "--quiet", "--depth", "1", self.origin.as_uri(), str(shallow), cwd=self.tmp)
        self.refused(self.upload("--dry-run", checkout=shallow), "This clone is shallow")

    def test_github_is_asked_about_the_commit_on_main(self):
        self.git("switch", "--quiet", "-c", "feat/elsewhere")
        self.write("Loe/Unmerged.swift", "// not on main\n")
        self.commit("third")
        self.assertEqual(self.upload("--dry-run").returncode, 0)
        self.assertIn(f"/commits/{self.git('rev-parse', 'origin/main')}/check-runs", self.asked.read_text())

    def test_a_commit_with_no_checks_is_refused(self):
        self.check({})
        self.refused(self.upload("--dry-run"), '"App tests (iOS)" has not passed')

    def test_each_check_main_requires_has_to_have_passed(self):
        for name in ("App tests (iOS)", "Catalogue build tests", "SonarCloud Code Analysis"):
            for result in (None, "failure", "cancelled", "skipped", "in_progress", "queued"):
                with self.subTest(name=name, result=result):
                    checks = {**PASSED, name: result}
                    if result is None:
                        del checks[name]
                    self.check(checks)
                    self.refused(self.upload("--dry-run"), f'"{name}" has not passed')

    def test_any_other_check_that_did_not_pass_is_refused(self):
        for result in ("failure", "cancelled", "timed_out", "in_progress", "queued"):
            with self.subTest(result=result):
                self.check({**PASSED, "SonarCloud scan": result})
                refusal = self.upload("--dry-run")
                self.refused(refusal, "Not every check passed")
                self.assertIn(f"SonarCloud scan\t{result}", refusal.stderr)

    def test_a_check_that_was_skipped_beside_the_required_ones_is_no_refusal(self):
        self.check({**PASSED, "What changed": "skipped", "Something else": "neutral"})
        self.assertEqual(self.upload("--dry-run").returncode, 0)

    def test_checks_that_cannot_be_read_are_a_refusal(self):
        self.checks.unlink()
        self.refused(self.upload("--dry-run"), "Could not read the checks")

    def test_a_key_others_can_read_is_refused(self):
        pathlib.Path(self.env["ASC_KEY_PATH"]).chmod(0o644)
        self.refused(self.upload("--dry-run"), "chmod 600")


if __name__ == "__main__":
    unittest.main()
