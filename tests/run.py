"""Run the logger regression tests with the standalone Luau CLI."""

from pathlib import Path
import subprocess
import sys
import tempfile


root = Path(__file__).resolve().parent.parent
source = (root / "rolog.lua").read_text()
tests = (root / "tests" / "rolog.test.lua").read_text()
runner = (
    "local function createLogger(environment)\n"
    "local function loadLogger()\n" + source + "\nend\n"
    "setfenv(loadLogger, environment)\n"
    "return loadLogger()\nend\n"
    "local runTests = (function()\n" + tests + "\nend)()\n"
    "runTests(createLogger)\n"
)

with tempfile.TemporaryDirectory(prefix="rolog-tests-") as directory:
    script = Path(directory) / "run.luau"
    script.write_text(runner)
    result = subprocess.run([sys.argv[1] if len(sys.argv) > 1 else "luau", str(script)])
    sys.exit(result.returncode)
