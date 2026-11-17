"""Regression tests for a shared macOS, Windows, and Linux update feed."""
import pathlib
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

SCRIPT = pathlib.Path(__file__).with_name("patch_appcast.py")
NS = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


class AppcastTests(unittest.TestCase):
    def test_platform_entries_coexist_and_reruns_only_patch_their_platform(self):
        with tempfile.TemporaryDirectory() as directory:
            feed = pathlib.Path(directory) / "appcast.xml"
            feed.write_text('<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><language>en</language></channel></rss>')

            def patch(os_name, size, signature=""):
                subprocess.run([
                    sys.executable, str(SCRIPT), "--appcast", str(feed),
                    "--os", os_name, "--version", "2.0.0", "--build", "51",
                    "--size", str(size), "--signature", signature,
                    "--url", f"https://example.com/{os_name}?a=1&b=2",
                ], check=True, capture_output=True)

            patch("macos", 100, "mac-signature")
            patch("windows", 200)
            patch("linux", 300)
            patch("macos", 101, "new-mac-signature")
            patch("windows", 201)
            enclosures = list(ET.parse(feed).iter("enclosure"))
            self.assertEqual(len(enclosures), 3)
            by_os = {e.get(NS + "os", "macos"): e for e in enclosures}
            self.assertEqual(by_os["macos"].get("length"), "101")
            self.assertEqual(by_os["windows"].get("length"), "201")
            self.assertEqual(by_os["linux"].get("length"), "300")
            self.assertEqual(by_os["macos"].get(NS + "edSignature"), "new-mac-signature")
            self.assertEqual(by_os["windows"].get(NS + "edSignature"), "")
            self.assertEqual(by_os["linux"].get(NS + "edSignature"), "")
            self.assertEqual(by_os["windows"].get("url"), "https://example.com/windows?a=1&b=2")


if __name__ == "__main__":
    unittest.main()
