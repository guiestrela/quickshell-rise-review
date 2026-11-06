// Extract one QML/JavaScript method body for an isolated Node fixture.
// A string-slice through the next method also captures sibling QML methods,
// which are declarations (not a single JavaScript expression).
export function extractQmlFunction(source, name) {
  if (!/^[A-Za-z_$][\w$]*$/.test(name))
    throw new TypeError(`invalid QML method name: ${name}`);

  const marker = `function ${name}(`;
  const start = source.indexOf(marker);
  if (start < 0) throw new Error(`missing QML method ${name}`);
  const open = source.indexOf('{', start + marker.length);
  if (open < 0) throw new Error(`missing body for QML method ${name}`);

  let depth = 0;
  let quote = '';
  let lineComment = false;
  let blockComment = false;
  for (let i = open; i < source.length; i++) {
    const ch = source[i];
    const next = source[i + 1];

    if (lineComment) {
      if (ch === '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (ch === '*' && next === '/') { blockComment = false; i++; }
      continue;
    }
    if (quote) {
      if (ch === '\\') { i++; continue; }
      if (ch === quote) quote = '';
      continue;
    }
    if (ch === '/' && next === '/') { lineComment = true; i++; continue; }
    if (ch === '/' && next === '*') { blockComment = true; i++; continue; }
    if (ch === '"' || ch === "'" || ch === '`') { quote = ch; continue; }
    if (ch === '{') depth++;
    else if (ch === '}' && --depth === 0) return source.slice(start, i + 1);
  }
  throw new Error(`unterminated QML method ${name}`);
}
