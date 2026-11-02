"""Build inert, local copies of shared production QML for runtime fixtures.

Fixtures keep local mock types for processes, surfaces and external services.
Production compilation tests separately exercise the real shared import graph.
"""
from pathlib import Path
import re
import shutil

_ROOT = Path(__file__).resolve().parents[1]


def qml_fixture_source(path):
    source = Path(path)
    if source.exists():
        return source
    # Older fixture lists group variant and common types by their consumer's
    # modules directory. Resolve common types without production adapters.
    if source.suffix == '.qml' and source.resolve().is_relative_to(_ROOT / 'variants'):
        matches = list((_ROOT / 'shared').glob('*/' + source.name))
        if len(matches) == 1:
            return matches[0]
    return source


def qml_fixture_text(path, *args, **kwargs):
    source = qml_fixture_source(path)
    text = source.read_text(*args, **kwargs)
    if source.suffix != '.qml' or source.resolve().is_relative_to(_ROOT / 'tests'):
        return text
    if source.stem == 'WeatherWidget' and 'Shared.WeatherWidget' in text:
        adapter = text
        text = (_ROOT / 'shared/components/WeatherWidget.qml').read_text()
        for field in ['contentColor', 'loadingGlyph']:
            value = re.search(r'    ' + field + r': ([^\n]+)', adapter)[1].replace('widget.', 'rootMod.')
            text = re.sub(r'    (?:required )?property (\w+) ' + field + r'[^\n]*',
                          lambda m: '    property ' + m[1] + ' ' + field + ': ' + value, text)
        source = _ROOT / 'shared/components/WeatherWidget.qml'
    # Older content fixtures need a standalone local type. Materialize the
    # shared content with the real adapter's style bindings in the test copy.
    content_types = {'CpuPanel', 'GpuPanel', 'MemoryPanel', 'PowerProfilePanel',
                     'WorkspacePanel', 'TrayPanel', 'AiUsagePanel', 'CalendarPopup', 'NordVPNPanel', 'WeatherPanel'}
    if source.stem in content_types and re.search(r'^Shared\.' + source.stem + r'\s*\{', text, re.M):
        body = (_ROOT / 'shared/panels' / source.name).read_text()
        ident = re.search(r'    id: (\w+)', body)[1]
        adapter = text
        for field, value in re.findall(r'^    (\w+): (.+)$', adapter, re.M):
            if field in {'id', 'surfaceComponent'}:
                continue
            value = value.replace('panel.', ident + '.')
            body = re.sub(r'    required property (\w+) ' + field + r'\n',
                          lambda m: '    property ' + m[1] + ' ' + field + ': ' + value + '\n', body)
            body = re.sub(r'    property real ' + field + r': [^\n]+',
                          '    property real ' + field + ': ' + value, body)
        surface = adapter.split('    surfaceComponent: Component {', 1)[1].rsplit('\n}', 1)[0]
        surface = surface.rsplit('    }', 1)[0].replace('Native.', '').replace('panel.', ident + '.')
        body = body.replace('    property Component surfaceComponent', '    property Component surfaceComponent: Component {' + surface + '    }')
        body = body.replace('import QtQuick\n', 'import QtQuick\nimport "../modules"\n', 1)
        text = body
        source = _ROOT / 'shared/panels' / source.name
    def shared_method(match):
        name, args, module, owner = match[1], match[2], match[3], match[4]
        js = (_ROOT / 'shared/logic' / (module + '.js')).read_text()
        start = js.index('function ' + name + '(')
        end = js.find('\nfunction ', start + 1)
        body = js[start:end if end >= 0 else None].strip()
        body = re.sub(r'^function \w+\([^\n]*\) \{', lambda m: 'function ' + name + '(' + args + ') {', body)
        body = body.replace('\n    var riseState = riseOwner;', '')
        body = re.sub(r'\b(?:riseState|riseEnvironment)\.', '', body)
        body = re.sub(r'\briseOwner\b', owner, body)
        return '    ' + body
    text = re.sub(r'^    function (\w+)\(([^\n]*)\) \{ return ((?:Theme\w+|\w+Logic))\.\1\((\w+), .* \}$', shared_method, text, flags=re.M)
    text = re.sub(r'^import "[^"\n]+/(?:Theme\w+|\w+Logic)\.js" as \w+\n', '', text, flags=re.M)
    aliases = []
    def local_import(match):
        target = (source.parent / match[1]).resolve()
        if re.search(r'^' + re.escape(match[2]) + r'\.' + re.escape(source.stem) + r'\s*\{', text, re.M):
            return match[0]
        if target.is_relative_to(_ROOT / 'shared') and target.is_dir():
            aliases.append(match[2])
            return ''
        return match[0]
    text = re.sub(r'^import "([^"\n]+)" as (\w+)\s*\n', local_import, text, flags=re.M)
    for alias in aliases:
        text = re.sub(r'\b' + re.escape(alias) + r'\.(\w+)', r'\1', text)
    return text


def qml_fixture_bytes(path):
    source = qml_fixture_source(path)
    return qml_fixture_text(source).encode() if source.suffix == '.qml' else source.read_bytes()


def copy_qml_fixture(source, destination):
    source = qml_fixture_source(source)
    destination = Path(destination)
    if destination.is_dir():
        destination = destination / source.name
    if source.suffix == '.qml':
        destination.write_bytes(qml_fixture_bytes(source))
        return destination
    return Path(shutil.copy2(source, destination))
