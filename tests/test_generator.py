"""mbulletin theme workflow tests: new, list and delete."""
import pathlib
import shutil
import subprocess
import sys
import tempfile

exe = pathlib.Path(sys.argv[1]).resolve()
T = b'T'
T100 = T * 100
THEMES = ('default', 'dbp_de')


def run(root, args, stdin=None):
    result = subprocess.run([str(root / 'mbulletin')] + args,
                            capture_output=True, input=stdin)
    return result.returncode, result.stdout.decode('utf-8', 'replace'), \
        result.stderr.decode('utf-8', 'replace')


def ini_text():
    return (
        '[default]\n'
        'BlankFile = blank/default/bullet.blank.ans\n'
        'BlankFileC132 = blank/default/bullet.blank.c132.ans\n'
        'BlankFileC160 = blank/default/bullet.blank.c160.ans\n'
        'BlankFileAsc = blank/default/bullet.blank.asc\n'
        'Top = 2\n'
        'Bottom = 4\n'
        'Left = 1\n'
        'Right = 1\n'
        '[dbp_de]\n'
        'BlankFile = blank/dbp_de/bullet.blank.ans\n'
        'BlankFileC132 = blank/dbp_de/bullet.blank.c132.ans\n'
        'BlankFileC160 = blank/dbp_de/bullet.blank.c160.ans\n'
        'BlankFileAsc = blank/dbp_de/bullet.blank.asc\n'
        'Top = 2\n'
        'Bottom = 4\n'
        'Left = 0\n'
        'Right = 2\n'
    )


def make_blank(path, code):
    lines = ['KEEP%s0' % code, 'A1', 'A2', 'A3', 'FOOT%s0' % code]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(('\r\n'.join(lines) + '\r\n').encode())


THEME_CODES = {'default': 'd', 'dbp_de': 'z'}

with tempfile.TemporaryDirectory(prefix='mbulletin-test-', delete=False) as directory:
    root = pathlib.Path(directory)
    shutil.copy(exe, root / 'mbulletin')
    (root / 'mbulletin.ini').write_text(ini_text())
    for theme in THEMES:
        for template in ('bullet.blank.ans', 'bullet.blank.c132.ans',
                         'bullet.blank.c160.ans', 'bullet.blank.asc'):
            make_blank(root / 'blank' / theme / template, THEME_CODES[theme])

    # --- new: one TXT argument builds a bulletin in every theme and width ----
    text = root / 'one.txt'
    text.write_bytes(T100 + b'\r\nMahlzeit\r\n')
    code, out, err = run(root, ['new', str(text)])
    assert code == 0, out + err
    for theme in THEMES:
        for suffix in ('.ans', '.asc', '.c132.ans', '.c160.ans'):
            assert (root / 'blank' / theme / ('bullet1' + suffix)).exists()

    # blank templates stay untouched
    blank = (root / 'blank' / 'default' / 'bullet.blank.ans').read_bytes()
    assert blank == b'KEEPd0\r\nA1\r\nA2\r\nA3\r\nFOOTd0\r\n'

    # default base .ans: title wraps into the 78-column area (80 - margins),
    # the report fills Top..Bottom exactly, everything else is kept
    rows = (root / 'blank' / 'default' / 'bullet1.ans').read_bytes().split(b'\r\n')
    assert rows == [b'KEEPd0', b' ' + T * 78, b' ' + T * 22, b' Mahlzeit',
                    b'FOOTd0', b'']

    # the c132 variant has 130 columns: title fits, remaining rows pad up
    rows = (root / 'blank' / 'default' / 'bullet1.c132.ans').read_bytes().split(b'\r\n')
    assert rows == [b'KEEPd0', b' ' + T100, b' Mahlzeit', b' ', b'FOOTd0', b'']

    # dbp_de has no left margin and keeps the full title in the wide variants
    rows = (root / 'blank' / 'dbp_de' / 'bullet1.ans').read_bytes().split(b'\r\n')
    assert rows == [b'KEEPz0', T * 78, T * 22, b'Mahlzeit', b'FOOTz0', b'']
    rows = (root / 'blank' / 'dbp_de' / 'bullet1.c160.ans').read_bytes().split(b'\r\n')
    assert rows == [b'KEEPz0', T100, b'Mahlzeit', b'', b'FOOTz0', b'']

    # --- new again: umlauts become ASCII in .asc and CP437 bytes in .ans -----
    text = root / 'two.txt'
    text.write_bytes('Titel zwei\r\nGrüße\r\nÜbung!\r\n'.encode('utf-8'))
    code, out, err = run(root, ['new', str(text)])
    assert code == 0, out + err
    asc = (root / 'blank' / 'default' / 'bullet2.asc').read_bytes()
    assert b'Gruesse' in asc
    assert b'Uebung!' in asc
    ans = (root / 'blank' / 'default' / 'bullet2.ans').read_bytes()
    assert b'\x81' in ans   # ü
    assert b'\xe1' in ans   # ß
    assert b'\x9a' in ans   # Ü

    # --- list shows numbers plus the titles read from the report area --------
    code, out, err = run(root, ['list'])
    assert code == 0, out + err
    assert 'default:' in out
    assert 'dbp_de:' in out
    assert ('1: ' + T.decode() * 78) in out
    assert '2: Titel zwei' in out
    assert 'Mahlzeit' not in out   # body lines are not titles

    # --- delete: bad number and J/N confirmation -----------------------------
    code, out, err = run(root, ['delete'], stdin=b'x\n')
    assert code != 0
    code, out, err = run(root, ['delete'], stdin=b'2\nn\n')
    assert code == 0, out + err
    assert (root / 'blank' / 'default' / 'bullet2.ans').exists()
    code, out, err = run(root, ['delete'], stdin=b'2\nj\n')
    assert code == 0, out + err
    for suffix in ('.ans', '.asc', '.c132.ans', '.c160.ans'):
        assert not (root / 'blank' / 'default' / ('bullet2' + suffix)).exists()
    assert (root / 'blank' / 'default' / 'bullet1.ans').exists()

    # --- delete in the middle renumbers: old 3 becomes the new 2 -------------
    text = root / 'three.txt'
    text.write_bytes(b'DREI\r\nDritter Text\r\n')
    code, out, err = run(root, ['new', str(text)])
    assert code == 0, out + err
    assert (root / 'blank' / 'default' / 'bullet2.ans').exists()
    text = root / 'four.txt'
    text.write_bytes(b'VIER\r\nVierter Text\r\n')
    code, out, err = run(root, ['new', str(text)])
    assert code == 0, out + err
    assert (root / 'blank' / 'default' / 'bullet3.ans').exists()
    code, out, err = run(root, ['delete'], stdin=b'2\nj\n')
    assert code == 0, out + err
    assert not (root / 'blank' / 'default' / 'bullet3.ans').exists()
    rows = (root / 'blank' / 'default' / 'bullet2.ans').read_bytes().split(b'\r\n')
    assert rows[1] == b' VIER'
    code, out, err = run(root, ['list'])
    assert '2: VIER' in out
    assert '3: VIER' not in out

    # --- themes with diverging bulletin counts are refused -------------------
    (root / 'blank' / 'default' / 'bullet3.ans').write_bytes(b'Fake\r\n')
    code, out, err = run(root, ['new', str(text)])
    assert code != 0 and 'out of sync' in out + err
    code, out, err = run(root, ['delete'], stdin=b'3\nj\n')
    assert code != 0 and 'out of sync' in out + err
    (root / 'blank' / 'default' / 'bullet3.ans').unlink()

    # --- new takes exactly one argument; missing files fail cleanly ----------
    code, out, err = run(root, ['new', str(text), 'extra'])
    assert code != 0
    code, out, err = run(root, ['new', str(root / 'missing.txt')])
    assert code != 0 and 'not found' in out + err

print('PASS mbulletin new/list/delete workflow across themes and widths.')
