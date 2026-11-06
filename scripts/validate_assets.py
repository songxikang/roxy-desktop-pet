#!/usr/bin/env python3
"""Check package integrity and basic v2 sprite geometry, not animation semantics."""

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
COUNTS = (6, 8, 8, 4, 5, 8, 6, 6, 6, 8, 8)
SIZE = (1536, 2288)
CELL = (192, 208)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    metadata = json.loads((ROOT / 'pet.json').read_text(encoding='utf-8'))
    require(metadata.get('id') == 'roxy-desktop-pet', 'Unexpected package id')
    require(bool(metadata.get('displayName')), 'Missing displayName')
    require(metadata.get('spriteVersionNumber') == 2, 'Expected v2 sprite format')
    sprite_path = ROOT / metadata['spritesheetPath']
    try:
        sprite_path.resolve().relative_to(ROOT)
    except ValueError:
        raise ValueError('Sprite path must stay inside the package') from None
    require(sprite_path.is_file(), 'Referenced sprite sheet is missing')

    checksums = ROOT / 'SHA256SUMS'
    require(checksums.is_file(), 'Missing SHA256SUMS')
    checked = []
    for line in checksums.read_text(encoding='utf-8').splitlines():
        if not line.strip():
            continue
        expected, name = line.split('  ', 1)
        candidate = (ROOT / name).resolve()
        try:
            candidate.relative_to(ROOT)
        except ValueError:
            raise ValueError('Checksum path escapes the package') from None
        require(candidate.is_file(), 'Missing checksum file: ' + name)
        actual = hashlib.sha256(candidate.read_bytes()).hexdigest()
        require(actual == expected, 'Checksum mismatch: ' + name)
        checked.append(name)
    require(set(checked) == {'pet.json', 'assets/spritesheet.png', 'assets/spritesheet.webp'},
            'Checksum list must cover metadata, PNG, and WebP exactly once')
    require(len(checked) == 3, 'Duplicate checksum entries')

    decoded = []
    for name, expected_format in [('spritesheet.png', 'PNG'), ('spritesheet.webp', 'WEBP')]:
        path = ROOT / 'assets' / name
        require(path.stat().st_size <= 20 * 1024 * 1024, name + ' exceeds 20 MiB')
        with Image.open(path) as opened:
            require(opened.format == expected_format, name + ' has the wrong encoded format')
            require(opened.size == SIZE, name + ' has incorrect dimensions')
            require('A' in opened.getbands(), name + ' must have an alpha channel')
            atlas = opened.convert('RGBA')
        require(atlas.getchannel('A').getextrema()[0] == 0, name + ' lacks transparent pixels')
        occupied = 0
        unused = 0
        for row, count in enumerate(COUNTS):
            for col in range(8):
                box = (col * CELL[0], row * CELL[1], (col + 1) * CELL[0], (row + 1) * CELL[1])
                alpha = atlas.crop(box).getchannel('A')
                pixels = sum(alpha.histogram()[1:])
                if col < count:
                    require(pixels >= 400, f'{name}: empty or sparse row {row}, frame {col}')
                    require(pixels < CELL[0] * CELL[1] * 0.95,
                            f'{name}: likely opaque background in row {row}, frame {col}')
                    occupied += 1
                else:
                    require(pixels == 0, f'{name}: artwork in unused row {row}, frame {col}')
                    unused += 1
        require((occupied, unused) == (73, 15), 'Unexpected occupied/unused cell count')
        decoded.append(atlas.tobytes())
    require(decoded[0] == decoded[1], 'PNG and WebP RGBA pixels differ')
    print('OK: checksums, v2 metadata, 73 populated frames, 15 transparent unused cells, identical PNG/WebP pixels.')
    print('This check does not replace visual animation or direction review.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        print('Validation failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
