# SPDX-License-Identifier: GPL-3.0-or-later
"""Translation rule (AGENTS.md rule 6, D-031): user-visible text uses qsTrId with a //% source.

Every qsTrId call in the app QML needs a //% or /*% */ source text before it, as lupdate reads
it; one id always has the same text; and translations/harbour-timerecord.ts lists exactly those
ids with those texts, so the committed catalogue is current (`docker compose run --rm i18n`).
"""
import ast
import os
import re
import xml.etree.ElementTree as ET

import pytest

ROOT = os.path.join(os.path.dirname(__file__), "..")
QML_DIR = os.path.join(ROOT, "qml")
TS_FILE = os.path.join(ROOT, "translations", "harbour-timerecord.ts")

# A //% or /*% */ source text, or a qsTrId call, in source order.
TOKEN = re.compile(r'//%\s*"((?:[^"\\]|\\.)*)"|/\*%\s*"((?:[^"\\]|\\.)*)"\s*\*/|\bqsTrId\(\s*"([^"]+)"')


def app_files():
    for root, _, files in os.walk(QML_DIR):
        for name in files:
            if name.endswith((".qml", ".js")):
                yield os.path.join(root, name)


def unescape(text):
    return text.replace('\\"', '"').replace("\\\\", "\\")


def calls(text):
    """[(id, source or None)] in order, pairing each qsTrId with the source text before it."""
    found, pending = [], None
    for m in TOKEN.finditer(text):
        if m.group(3) is None:
            pending = unescape(m.group(1) if m.group(1) is not None else m.group(2))
        else:
            found.append((m.group(3), pending))
            pending = None
    return found


def app_calls():
    found = []
    for path in sorted(app_files()):
        with open(path, encoding="utf-8") as f:
            found += [(os.path.relpath(path, QML_DIR), i, s) for i, s in calls(f.read())]
    return found


def catalogue():
    return {m.get("id"): m.findtext("source") for m in ET.parse(TS_FILE).getroot().iter("message")}


def test_pairing_reads_like_lupdate():
    code = ('//% "Settings"\ntext: qsTrId("a")\n'
            'x ? /*% "Yes" */ qsTrId("b") : /*% "No" */ qsTrId("c")\n'
            'qsTrId("d")\n//% "Say \\"hi\\""\nqsTrId("e", n)')
    assert calls(code) == [("a", "Settings"), ("b", "Yes"), ("c", "No"), ("d", None), ("e", 'Say "hi"')]


@pytest.mark.parametrize("path", sorted(app_files()), ids=lambda p: os.path.relpath(p, QML_DIR))
def test_no_plain_qstr(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    assert re.findall(r'\bqsTr(?:NoOp)?\s*\(', text) == []


def test_every_call_has_one_source_text():
    texts = {}
    for path, ident, source in app_calls():
        assert source is not None, "%s: qsTrId(%r) has no //%% source text" % (path, ident)
        assert texts.setdefault(ident, source) == source, "%s: %r has two texts" % (path, ident)


def test_catalogue_is_current():
    expected = {ident: source for _, ident, source in app_calls()}
    assert catalogue() == expected, "run: docker compose run --rm i18n"


# Texts built in Python arrive in English and are translated in QML (D-031).

PY_DIR = os.path.join(ROOT, "python", "timerecord")


def python_texts():
    """Undo names (first argument of _run) and constant ValueError messages, as written."""
    names, errors = set(), set()
    for name in sorted(os.listdir(PY_DIR)):
        if not name.endswith(".py"):
            continue
        with open(os.path.join(PY_DIR, name), encoding="utf-8") as f:
            tree = ast.parse(f.read())
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) \
                    and node.func.attr == "_run" and node.args:
                names |= {c.value for c in ast.walk(node.args[0])
                          if isinstance(c, ast.Constant) and isinstance(c.value, str)}
            if isinstance(node, ast.Raise) and isinstance(node.exc, ast.Call) \
                    and getattr(node.exc.func, "id", None) == "ValueError" and node.exc.args \
                    and isinstance(node.exc.args[0], ast.Constant):
                errors.add(node.exc.args[0].value)
    return names, errors


def qml_keys(path, prefix):
    with open(os.path.join(QML_DIR, path), encoding="utf-8") as f:
        return set(re.findall(r'"([^"]+)":\s*qsTrId\("timerecord-%s-' % prefix, f.read()))


def test_python_texts_are_found():
    names, errors = python_texts()
    assert {"Check in", "Vacation %d", "Archive task", "Restore task"} <= names
    assert "the time is in the future" in errors


def test_undo_names_are_translated():
    assert qml_keys("components/Backend.qml", "undo") == python_texts()[0]


def test_error_messages_are_translated():
    assert qml_keys("components/Backend.qml", "error") == python_texts()[1]


def test_reminder_kinds_are_worded():
    with open(os.path.join(PY_DIR, "reminders.py"), encoding="utf-8") as f:
        kinds = set(re.findall(r'"kind":\s*"(\w+)"', f.read()))
    with open(os.path.join(QML_DIR, "components", "Reminders.qml"), encoding="utf-8") as f:
        cases = set(re.findall(r'case\s+"(\w+)":', f.read()))
    assert kinds == {"checkout", "target", "checkin", "break"} and cases == kinds
