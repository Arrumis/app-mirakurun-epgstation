"""認証情報の新規生成と既存DBの保護を検証する。"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class SecretsTest(unittest.TestCase):
    def test_generation_is_private_and_stable(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            (p / "scripts").mkdir()
            shutil.copy2(ROOT / "scripts/init-secrets.py", p / "scripts/init-secrets.py")
            shutil.copy2(ROOT / ".env.example", p / ".env.example")
            a = subprocess.run(["python3", "scripts/init-secrets.py"], cwd=p, capture_output=True)
            self.assertEqual(a.returncode, 0)
            first = (p / ".env.local").read_bytes()
            self.assertEqual((p / ".env.local").stat().st_mode & 0o777, 0o600)
            a = subprocess.run(["python3", "scripts/init-secrets.py"], cwd=p, capture_output=True)
            self.assertEqual(a.returncode, 0)
            self.assertEqual(first, (p / ".env.local").read_bytes())
            (p / ".env.local").unlink()
            data = p / 'data/mirakurun/mira_sql'
            data.mkdir(parents=True)
            (data / "existing").touch()
            a = subprocess.run(["python3", "scripts/init-secrets.py"], cwd=p, capture_output=True)
            self.assertNotEqual(a.returncode, 0)
            self.assertFalse((p / ".env.local").exists())

if __name__ == "__main__":
    unittest.main()
