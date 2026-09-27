"""A small Dart lexer — enough to find string literals correctly.

Regex cannot do this. A Dart literal may contain `${ ... }` holding an
arbitrary expression, and that expression may hold more string literals,
which may themselves interpolate. `'$n item${n == 1 ? '' : 's'}'` is a
*single* literal, and every regex-only pass over this codebase mis-split it.
"""

import re


class Lit:
    __slots__ = ("start", "end", "quote", "raw", "triple", "parts")

    def __init__(self, start, end, quote, raw, triple, parts):
        self.start = start      # offset of the opening quote (after r/ prefix)
        self.end = end          # offset just past the closing quote
        self.quote = quote      # "'" or '"'
        self.raw = raw          # r'...'
        self.triple = triple    # '''...'''
        self.parts = parts      # [('text', s)] / [('expr', src)] in order

    @property
    def is_simple(self):
        return not self.raw and not self.triple

    @property
    def has_interp(self):
        return any(k == "expr" for k, _ in self.parts)

    @property
    def text(self):
        """Literal contents with escapes intact, interpolations included."""
        return "".join(s for _, s in self.parts)


def _scan_string(src, i):
    """Scan the literal starting at `i` (which may be `r` or a quote)."""
    start = i
    raw = False
    if src[i] == "r" and i + 1 < len(src) and src[i + 1] in "'\"":
        raw = True
        i += 1
    if src[i] not in "'\"":
        return None
    q = src[i]
    triple = src.startswith(q * 3, i)
    closer = q * 3 if triple else q
    i += len(closer)
    parts, buf = [], []

    def flush():
        if buf:
            parts.append(("text", "".join(buf)))
            del buf[:]

    while i < len(src):
        c = src[i]
        if not raw and c == "\\":
            buf.append(src[i:i + 2]); i += 2; continue
        if src.startswith(closer, i):
            flush()
            return Lit(start, i + len(closer), q, raw, triple, parts)
        if not triple and c == "\n":
            return None                      # unterminated single-line literal
        if not raw and c == "$":
            if i + 1 < len(src) and src[i + 1] == "{":
                j, depth = i + 2, 1
                while j < len(src) and depth:
                    if src[j] in "'\"" or (src[j] == "r" and j + 1 < len(src)
                                           and src[j + 1] in "'\""):
                        inner = _scan_string(src, j)
                        if inner:
                            j = inner.end
                            continue
                    if src[j] == "{":
                        depth += 1
                    elif src[j] == "}":
                        depth -= 1
                    j += 1
                flush()
                parts.append(("expr", src[i:j]))
                i = j
                continue
            m = re.match(r"\$[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*",
                         src[i:])
            if m:
                flush()
                parts.append(("expr", m.group(0)))
                i += m.end()
                continue
        buf.append(c)
        i += 1
    return None


def literals(src):
    """Every top-level string literal, in order, skipping comments."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == "/" and i + 1 < n:
            if src[i + 1] == "/":
                i = src.find("\n", i)
                if i < 0:
                    break
                continue
            if src[i + 1] == "*":
                j = src.find("*/", i + 2)
                i = (j + 2) if j > 0 else n
                continue
        if c in "'\"" or (c == "r" and i + 1 < n and src[i + 1] in "'\""):
            # `r` must not be the tail of an identifier (e.g. `color'...`)
            if c == "r" and i > 0 and re.match(r"[\w$]", src[i - 1]):
                i += 1
                continue
            lit = _scan_string(src, i)
            if lit:
                out.append(lit)
                i = lit.end
                continue
        i += 1
    return out
