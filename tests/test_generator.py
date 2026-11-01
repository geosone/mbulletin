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
    out = root / 'bullet3.ans'
    request = root / 'bulletin.ini'
    request.write_text('[Bulletin]' + chr(10) + 'BlankFile = ' + str(blank) + chr(10) + 'OutFile = ' + str(out) + chr(10))
    result = subprocess.run([str(exe), 'new', str(request)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert not out.exists()
    result = subprocess.run([str(exe), 'new', str(request), '--apply'], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert out.read_bytes() == original
    assert blank.read_bytes() == original
    result = subprocess.run([str(exe), 'new', str(request), '--apply'], capture_output=True, text=True)
    assert result.returncode != 0
    assert 'exists' in result.stdout + result.stderr
print('PASS bulletin generation plans, writes from blank and refuses overwrites.')
