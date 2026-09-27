"""Every key the code will ask the dictionary for.

Finds the literals carrying `.tr` / `.trf`, plus both arms of every
`Tr.plural(...)`. That is exactly the set a translation has to cover.

Run alone to list them:

    python tool/i18n/keys.py
"""

import io, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dartlex


def scan(lib):
    """The set of dictionary keys used anywhere under `lib`."""
    keys = set()
    for dp, _, names in os.walk(lib):
        for n in sorted(names):
            if not n.endswith(".dart"):
                continue
            path = os.path.join(dp, n)
            rel = os.path.relpath(path, lib).replace("\\", "/")
            if rel.startswith("core/i18n/"):
                continue
            src = io.open(path, encoding="utf-8",
                          newline="").read().replace("\r\n", "\n")

            for lit in dartlex.literals(src):
                if not lit.is_simple:
                    continue
                # `.tr` and `.trf` both consume the literal as a key. A plain
                # `\b` after "tr" does not fire before the "f", so both
                # spellings have to be named.
                if re.match(r"\.trf?(?![A-Za-z0-9_])", src[lit.end:lit.end + 5]):
                    keys.add(lit.text)

            # Tr.plural(count, 'one', 'many'[, [...]]) — both arms are keys.
            for m in re.finditer(r"Tr\.plural\(", src):
                for lit in dartlex.literals(src[m.end():m.end() + 400])[:2]:
                    keys.add(lit.text)
    return keys


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    found = sorted(scan(os.path.join(root, "lib")))
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "keys.txt")
    io.open(out, "w", encoding="utf-8").write("\n".join(found) + "\n")
    print("%d keys -> tool/i18n/keys.txt" % len(found))
