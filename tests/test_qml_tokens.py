"""UI rule (AGENTS.md, D-016): Silica components and Theme.* values only - no hardcoded
colors, sizes or fonts.

Scans the app QML (not the preview stand-ins). Plain 0/1 are allowed where they mean
"none"/"full" (opacity, border off); ratios that split space (width / 4) are layout.
"""
import os
import re

import pytest

QML_DIR = os.path.join(os.path.dirname(__file__), "..", "qml")

SIZE_PROPS = (r"(?:width|height|x|y|z_never|spacing|radius|margins|leftMargin|rightMargin|"
              r"topMargin|bottomMargin|horizontalCenterOffset|verticalCenterOffset|"
              r"pixelSize|pointSize|border\.width|contentHeight|contentWidth|padding\w*)")

CHECKS = [
    ("hex color", re.compile(r'"#[0-9a-fA-F]{3,8}"')),
    ("named color", re.compile(
        r'(?:color|Color)\s*:\s*[^\n]*"(?:white|black|red|green|blue|yellow|gray|grey|orange|'
        r'purple|transparent)"')),
    ("transparent", re.compile(r'"transparent"')),
    ("fractional factor", re.compile(r'(?:opacity|Opacity)\s*:[^\n]*\b0?\.\d+')),
    ("scaled literal", re.compile(r'\*\s*0?\.\d+')),
    ("font family", re.compile(r'font\.family\s*:\s*"')),
]


SIZE_LINE = re.compile(r'\b' + SIZE_PROPS + r'\s*:(.*)')
FACTOR = re.compile(r'\d+(?:\.\d+)?\s*\*|[*/]\s*\d+(?:\.\d+)?')
NUMBER = re.compile(r'(?<![\w.])(\d+(?:\.\d+)?)(?![\w.])')


def literal_size(code):
    """A size property with a standalone number other than 0/1 (2 * x and w / 4 are ratios)."""
    m = SIZE_LINE.search(code)
    if not m:
        return False
    rest = FACTOR.sub(" ", m.group(1))
    return any(float(n) not in (0, 1) for n in NUMBER.findall(rest))


def qml_files():
    for root, _, files in os.walk(QML_DIR):
        for name in files:
            if name.endswith(".qml"):
                yield os.path.join(root, name)


def violations(path):
    found = []
    with open(path, encoding="utf-8") as f:
        for number, line in enumerate(f, 1):
            code = line.split("//", 1)[0]
            labels = [label for label, pattern in CHECKS if pattern.search(code)]
            if literal_size(code):
                labels.append("literal size")
            for label in labels:
                found.append("%s:%d: %s: %s" % (os.path.relpath(path, QML_DIR), number, label, line.strip()))
    return found


def test_patterns_catch_examples():
    for code in ['border.width: 2', 'anchors.margins: 2', 'width: 117', 'height: cond ? 40 : Theme.itemSizeSmall']:
        assert literal_size(code), code
    for code in ['width: parent.width - 2 * x', 'width: parent.width / 3', 'radius: width / 2',
                 'height: Theme.itemSizeSmall', 'border.width: 0', 'width: 1']:
        assert not literal_size(code), code
    samples = {
        'color: "#c62828"': "hex color",
        'color: "white"': "named color",
        'opacity: 0.35': "fractional factor",
        'width: parent.width * 0.5': "scaled literal",
        'font.family: "Sans"': "font family",
    }
    for code, label in samples.items():
        assert any(l == label and p.search(code) for l, p in CHECKS), code
    for ok in ['width: parent.width / 4', 'opacity: enabled ? 1 : 0', 'height: Theme.itemSizeSmall',
               'radius: width / 2', 'border.width: 0', 'color: Theme.rgba(Theme.highlightColor, Theme.opacityLow)']:
        assert not any(p.search(ok) for _, p in CHECKS), ok


@pytest.mark.parametrize("path", sorted(qml_files()), ids=lambda p: os.path.relpath(p, QML_DIR))
def test_qml_uses_platform_tokens(path):
    assert violations(path) == []
