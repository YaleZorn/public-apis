import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PARSE = ROOT / "scripts" / "parse_apis.py"
OUT = ROOT / "explorer" / "public" / "data" / "apis.json"


class TestParseApis(unittest.TestCase):
    def test_parser_writes_valid_catalog(self):
        result = subprocess.run(
            [sys.executable, str(PARSE)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(OUT.exists())
        data = json.loads(OUT.read_text(encoding="utf-8"))
        self.assertGreater(data["count"], 1000)
        self.assertEqual(data["count"], len(data["apis"]))
        self.assertTrue(data["categories"])
        sample = data["apis"][0]
        for key in ("id", "name", "url", "description", "auth", "https", "cors", "category"):
            self.assertIn(key, sample)


if __name__ == "__main__":
    unittest.main()
