from pathlib import Path
import argparse
import zipfile

from verify_package import digest, verify


def main():
    parser = argparse.ArgumentParser(description='Build a release ZIP from the explicit checksum allowlist.')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    files = verify(root)
    output = args.output.resolve()
    if output.exists():
        raise FileExistsError('Output already exists; choose a new filename.')
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name in sorted([*files, 'SHA256SUMS.json']):
            info = zipfile.ZipInfo('ThemeHospital-PL-0.2-beta/' + name, (2026, 11, 8, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, (root / name).read_bytes())
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None:
            raise ValueError('ZIP integrity check failed')
    print(f'SHA256 {digest(output)}')
    print(f'Files: {len(files) + 1}; bytes: {output.stat().st_size}')


if __name__ == '__main__':
    main()
