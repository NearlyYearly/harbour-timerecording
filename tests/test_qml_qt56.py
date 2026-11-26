# SPDX-License-Identifier: GPL-3.0-or-later
"""Qt 5.6 rule (AGENTS.md rule 7): Sailfish OS runs Qt 5.6 with an ES5 JavaScript engine.

The desktop preview runs Qt 5.15, which accepts ES6 and newer Qt syntax, so code that works
there can fail on the phone. This scans the app QML and JS (not the preview stand-ins) for
ES6 syntax, ES6 library functions and Qt features newer than 5.6. Comments and string
contents are ignored. A method name that the same file defines itself (dialog.find) is not
the ES6 one.
"""
import os
import re

import pytest

QML_DIR = os.path.join(os.path.dirname(__file__), "..", "qml")

SYNTAX = [
    ("let", re.compile(r'\blet\s+[A-Za-z_$\[{]')),
    ("const", re.compile(r'\bconst\s+[A-Za-z_$\[{]')),
    ("arrow function", re.compile(r'=>')),
    ("template string", re.compile(r'`')),
    ("class", re.compile(r'\bclass\s+[A-Za-z_$]')),
    ("spread", re.compile(r'\.\.\.\s*[A-Za-z_$\[(]')),
    ("for-of", re.compile(r'\bfor\s*\(\s*(?:var\s+)?[\w$]+\s+of\b')),
    ("async", re.compile(r'\basync\s+function\b|\bawait\s')),
    ("Qt 6 handler", re.compile(r'\bfunction\s+on[A-Z]\w*\s*\(')),
    ("required property", re.compile(r'^\s*required\s+property\b', re.M)),
    ("inline component", re.compile(r'^\s*component\s+\w+\s*:', re.M)),
    ("versionless import", re.compile(r'^\s*import\s+[A-Za-z][\w.]*\s*$', re.M)),
]

METHOD = re.compile(r'\.(padStart|padEnd|includes|startsWith|endsWith|repeat|find|findIndex|fill|'
                    r'copyWithin|flat|flatMap|codePointAt|normalize|trimStart|trimEnd)\s*\(')

STATIC = re.compile(r'\b(?:Object\.(?:assign|entries|values|fromEntries|is|getOwnPropertySymbols|'
                    r'setPrototypeOf)|Array\.(?:from|of)|Number\.(?:isNaN|isFinite|isInteger|'
                    r'isSafeInteger|parseFloat|parseInt|EPSILON)|Math\.(?:sign|trunc|cbrt|hypot|log10|'
                    r'log2|log1p|expm1|fround|imul|clz32|sinh|cosh|tanh|asinh|acosh|atanh)|'
                    r'Qt\.callLater|new\s+(?:Map|Set|WeakMap|WeakSet|Promise|Proxy)|'
                    r'(?:Promise|Symbol|Reflect)\.)')

QTQUICK_IMPORT = re.compile(r'^\s*import\s+QtQuick(?:\.\w+)*\s+2\.(\d+)', re.M)


def code_only(text):
    """The source with comments removed and string contents emptied; newlines are kept."""
    out = []
    i, n = 0, len(text)
    while i < n:
        if text.startswith("//", i):
            end = text.find("\n", i)
            i = n if end < 0 else end
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            end = n if end < 0 else end + 2
            out.append("\n" * text.count("\n", i, end))
            i = end
        elif text[i] in "\"'`":
            quote, j = text[i], i + 1
            while j < n and text[j] != quote:
                j += 2 if text[j] == "\\" else 1
            # A template string stays visible as one backtick.
            out.append(quote + "\n" * text.count("\n", i, j) + ("" if quote == "`" else quote))
            i = j + 1
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def violations(text):
    code = code_only(text)
    own = set(re.findall(r'\bfunction\s+(\w+)\s*\(', code))
    found = []
    for label, pattern in SYNTAX:
        found += [(code.count("\n", 0, m.start()) + 1, label) for m in pattern.finditer(code)]
    found += [(code.count("\n", 0, m.start()) + 1, "ES6 method ." + m.group(1))
              for m in METHOD.finditer(code) if m.group(1) not in own]
    found += [(code.count("\n", 0, m.start()) + 1, "newer API " + m.group(0))
              for m in STATIC.finditer(code)]
    found += [(code.count("\n", 0, m.start()) + 1, "QtQuick 2." + m.group(1))
              for m in QTQUICK_IMPORT.finditer(code) if int(m.group(1)) > 6]
    return sorted(found)


def app_files():
    for root, _, files in os.walk(QML_DIR):
        for name in files:
            if name.endswith((".qml", ".js")):
                yield os.path.join(root, name)


def test_patterns_catch_examples():
    bad = {
        'let x = 1': "let",
        'const y = 2': "const",
        'var f = (a) => a': "arrow function",
        'var s = `a ${b}`': "template string",
        'f(...args)': "spread",
        'for (var x of list) {}': "for-of",
        'function onClicked() {}': "Qt 6 handler",
        '    required property int n': "required property",
        'import QtQuick': "versionless import",
        'import QtQuick 2.15': "QtQuick 2.15",
        'var i = list.findIndex(function(x) { return x })': "ES6 method .findIndex",
        'var p = String(n).padStart(2, "0")': "ES6 method .padStart",
        'if (s.startsWith("a")) {}': "ES6 method .startsWith",
        'Qt.callLater(f)': "newer API Qt.callLater",
        'var s = Math.sign(d)': "newer API Math.sign",
        'var o = Object.assign({}, a)': "newer API Object.assign",
        'var m = new Map()': "newer API new Map",
    }
    for code, label in bad.items():
        assert [l for _, l in violations(code)] == [label], code
    for ok in ['var x = 1', 'import QtQuick 2.6', 'import Sailfish.Silica 1.0', 'import "../components"',
               'text: qsTr("let it be => `quoted`")', '// let x = 1 => ...', '/* const */ var y',
               'Repeater { model: 3 }', 'repeat: true', 'function find(y) {}\nvar e = dialog.find(2026)',
               'var r = /^\\d{1,2}(:\\d{0,2})?$/', 'var parts = list.concat(more)']:
        assert violations(ok) == [], ok


@pytest.mark.parametrize("path", sorted(app_files()), ids=lambda p: os.path.relpath(p, QML_DIR))
def test_qml_runs_on_qt56(path):
    with open(path, encoding="utf-8") as f:
        found = violations(f.read())
    assert ["%d: %s" % hit for hit in found] == []
