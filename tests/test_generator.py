"""Bulletin generation tests."""
import pathlib
import subprocess
import sys
import tempfile

exe = pathlib.Path(sys.argv[1]).resolve()
subprocess.run([str(exe), '--self-test'], check=True)
with tempfile.TemporaryDirectory(prefix='mbulletin-test-') as directory:
    root = pathlib.Path(directory)
    blank = root / 'bullet.ans'
    blank.write_bytes(b'\x1b[1;1HBULLETIN-TICKER' + b'\r\nDISCONNECTED BY PEER // AT  DbP / 2000' + b'\r\n')
    original = blank.read_bytes()
    out = root / 'bullet2.ans'
    result = subprocess.run([str(exe), 'new', str(blank), str(out)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert not out.exists()
    result = subprocess.run([str(exe), 'new', str(blank), str(out), '--apply'], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert out.read_bytes() == original
    assert blank.read_bytes() == original
    result = subprocess.run([str(exe), 'new', str(blank), str(out), '--apply'], capture_output=True, text=True)
    assert result.returncode != 0
    assert 'exists' in result.stdout + result.stderr
print('PASS bulletin generation plans, writes from blank and refuses overwrites.')
