"""Exercise distinct native ANSI/ASCII widths and CP437 transliteration."""
import pathlib
import shutil
import subprocess
import sys
import tempfile

binary = pathlib.Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='mbulletin-wide-') as tmp:
    root = pathlib.Path(tmp)
    tool = root / binary.name
    shutil.copy2(binary, tool)
    ini = ['[test]']
    for width, suffix, key in [(80, '.ans', ''), (132, '.c132.ans', 'C132'),
                               (160, '.c160.ans', 'C160'), (80, '.asc', 'Asc'),
                               (132, '.c132.asc', 'C132Asc'),
                               (160, '.c160.asc', 'C160Asc')]:
        blank = root / ('bullet.blank' + suffix)
        blank.write_bytes(('HEADER\r\n' + (' ' * width + '\r\n') * 4 + 'FOOTER').encode())
        ini += [f'BlankFile{key}={blank.name}', f'Coord1{key}=3,2',
                f'Coord2{key}={width-4},5']
    (root / 'mbulletin.ini').write_text('\n'.join(ini))
    text = root / 'text.txt'
    text.write_text('X' * 200 + '\näöü\n', encoding='utf-8')
    subprocess.run([str(tool), 'new', str(text)], check=True)
    for width, suffix in [(80, '.ans'), (132, '.c132.ans'), (160, '.c160.ans'),
                          (80, '.asc'), (132, '.c132.asc'), (160, '.c160.asc')]:
        data = (root / ('bullet1' + suffix)).read_bytes()
        first = data.split(b'\r\n')[1]
        assert first == b'  ' + b'X' * (width - 6), (width, suffix, first)
        assert (b'aeoeue' if suffix.endswith('.asc') else bytes([132, 148, 129])) in data, (suffix, data)
    print('PASS independent wrapping and translation for six variants')
