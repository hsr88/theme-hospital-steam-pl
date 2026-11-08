from pathlib import Path, PurePosixPath
import argparse
import base64
import hashlib
import json
import re


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def package_files(root):
    checksums = json.loads((root / 'SHA256SUMS.json').read_text(encoding='utf-8'))
    for name, expected in checksums.items():
        relative = PurePosixPath(name)
        if relative.is_absolute() or '..' in relative.parts or '\\' in name or ':' in name:
            raise ValueError('Invalid package path: ' + name)
        path = root.joinpath(*relative.parts)
        if path.is_symlink() or not path.is_file() or digest(path) != expected:
            raise ValueError('Missing or modified package file: ' + name)
    return checksums


def verify(root):
    checksums = package_files(root)
    allowed = re.compile(r'^(DATA/LANG-0\.DAT|QDATA/FONT[0-9]+V\.(DAT|TAB)|QDATAM/FONT[0-9]+M\.(DAT|TAB)|LEVELS/(EASY|FULL|HARD|NET)00\.SAM)$')
    for folder, version, count in [(root, '0.2-beta', 93), (root / 'aktualizacja-z-0.1', '0.1-beta', 89)]:
        patch = json.loads((folder / 'patch.json').read_text(encoding='utf-8'))
        if (patch['version'], patch['appid'], patch['build']) != (version, 2229820, '25682708'):
            raise ValueError('Unexpected patch version')
        if digest(folder / 'rnc_decode.exe') != patch['rnc_sha256']:
            raise ValueError('RNC executable hash mismatch')
        paths = [entry['path'] for entry in patch['files']]
        if len(paths) != count or len(set(paths)) != count or not all(allowed.fullmatch(x) for x in paths):
            raise ValueError('Unexpected target paths')
        if set(patch['encoding'].values()) != set(range(176, 194)):
            raise ValueError('Invalid Polish character map')
        for entry in patch['files']:
            for key in ['before', 'after']:
                if not re.fullmatch('[0-9a-f]{64}', entry[key]):
                    raise ValueError('Invalid target hash')
            if 'strings' in entry:
                for key, text in entry['strings'].items():
                    if not re.fullmatch(r'\d+:\d+', key) or '\0' in text:
                        raise ValueError('Invalid translation entry')
                    for char in text:
                        if str(ord(char)) not in patch['encoding']:
                            char.encode('cp437')
            else:
                for op in entry['ops']:
                    if 'copy' in op:
                        if not isinstance(op['copy'], int) or not isinstance(op['length'], int) or min(op['copy'], op['length']) < 0:
                            raise ValueError('Invalid delta range')
                    else:
                        base64.b64decode(op['data'], validate=True)
    return checksums


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Check the public package without accessing a game installation.')
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    result = verify(args.root.resolve())
    print(f'OK: {len(result)} package files; current and previous patch manifests verified.')
