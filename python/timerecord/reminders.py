# SPDX-License-Identifier: GPL-3.0-or-later
"""Which reminders are due right now. Pure function; the API remembers what was sent."""
import datetime as dt

from .store import parse


def due(values, now, day, running):
    """Return [{key, kind, ...}] for reminders whose condition holds at `now`.

    day: calc.day_summary of today; running: the running stamp row or None.
    Keys are stable per occasion, so the caller can send each one only once. `kind` and the
    other fields are what the texts need; QML words them (Reminders.qml), so they translate.
    """
    if not values["remind.enabled"]:
        return []
    out = []
    net_plus_credit = day["net_min"] + day["credit_min"]

    after = values["remind.checkout_after_min"]
    if running and after > 0:
        since = parse(running["check_in"])
        length = int((now - since).total_seconds() // 60)
        if length >= after:
            out.append({"key": "checkout:%s" % running["id"], "kind": "checkout",
                        "since": running["check_in"][11:16], "length_min": length})

    if values["remind.target_reached"] and running and day["target_min"] > 0 \
            and net_plus_credit >= day["target_min"]:
        out.append({"key": "target", "kind": "target", "target_min": day["target_min"]})

    checkin = values["remind.checkin_time"]
    if checkin and not running and day["target_min"] > 0 and day["credit_min"] == 0 \
            and not any(l["kind"] != "auto_break" for l in day["lines"]):
        hour, minute = (int(x) for x in checkin.split(":"))
        if now.time() >= dt.time(hour, minute):
            out.append({"key": "checkin", "kind": "checkin", "time": checkin})

    if values["remind.break"] and running:
        for line in day["lines"]:
            if line["kind"] != "auto_break":
                continue
            start, end = parse(line["check_in"]), parse(line["check_out"])
            if start <= now < end:
                out.append({"key": "break:%s" % line["check_in"][11:16], "kind": "break",
                            "start": line["check_in"][11:16], "end": line["check_out"][11:16],
                            "split": values["break.mode"] == "split"})
    return out
