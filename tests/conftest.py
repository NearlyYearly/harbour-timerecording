# SPDX-License-Identifier: GPL-3.0-or-later
import datetime as dt
import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "python"))

from timerecord import db, settings  # noqa: E402
from timerecord.store import Store  # noqa: E402


class Clock:
    def __init__(self, t):
        self.t = t

    def __call__(self):
        return self.t

    def set(self, s):
        self.t = dt.datetime.fromisoformat(s)


@pytest.fixture
def clock():
    return Clock(dt.datetime(2026, 10, 5, 8, 0))  # a Monday


@pytest.fixture
def conn(tmp_path):
    c = db.connect(str(tmp_path / "t.sqlite"))
    yield c
    c.close()


@pytest.fixture
def store(conn, clock):
    return Store(conn, clock)


@pytest.fixture
def values(conn):
    return settings.get_all(conn)
