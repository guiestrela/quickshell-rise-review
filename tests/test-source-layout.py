#!/usr/bin/env python3
"""Check local QML imports/resources after moving the runtime directories."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [ROOT / name for name in ('Bar.qml', 'shell.qml')]
for directory in ('core', 'shared', 'variants', 'tests/qml'):
    SOURCES.extend(p for p in (ROOT / directory).rglob('*') if p.suffix in ('.qml', '.js'))

references = re.compile(
    r'''(?:^\s*import\s+|Qt\.resolvedUrl\(\s*)["']([^"']+)["']''', re.MULTILINE
)
errors = []
for source in SOURCES:
    for match in references.finditer(source.read_text()):
        target = match[1]
        if ':' in target:
            continue
        if not (source.parent / target).exists():
            errors.append(f'{source.relative_to(ROOT)}: missing {target}')

for entry in ('Bar.qml', 'shell.qml'):
    text = (ROOT / entry).read_text()
    for variant in ('V1', 'V2'):
        if f'import "variants/{variant}" as {variant}Bundle' not in text:
            errors.append(f'{entry}: must register the lazy {variant} bundle')
        if f'Qt.resolvedUrl("variants/{variant}/VariantRoot.qml")' not in text:
            errors.append(f'{entry}: missing {variant} loader source')

assert not errors, '\n'.join(errors)
print(f'SOURCE LAYOUT PASS: {len(SOURCES)} source files; local imports/resources and both entry points')
