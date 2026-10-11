"""Which reminders are due right now. Pure function; the API remembers what was sent."""
import datetime as dt

from .store import parse


def _hm(minutes):
    return "%d:%02d" % (minutes // 60, minutes % 60)


def due(values, now, day, running):
    """Return [{key, summary, body}] for reminders whose condition holds at `now`.

    day: calc.day_summary of today; running: the running stamp row or None.
    Keys are stable per occasion, so the caller can send each one only once.
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
            out.append({
                "key": "checkout:%s" % running["id"],
                "summary": "Still checked in?",
                "body": "Checked in since %s (%s h). Did you forget to check out?" % (
                    running["check_in"][11:16], _hm(length)),
            })

    if values["remind.target_reached"] and running and day["target_min"] > 0 \
            and net_plus_credit >= day["target_min"]:
        out.append({
            "key": "target",
            "summary": "Target reached",
            "body": "You have worked today's %s h." % _hm(day["target_min"]),
        })

    checkin = values["remind.checkin_time"]
    if checkin and not running and day["target_min"] > 0 and day["credit_min"] == 0 \
            and not any(l["kind"] != "auto_break" for l in day["lines"]):
        hour, minute = (int(x) for x in checkin.split(":"))
        if now.time() >= dt.time(hour, minute):
            out.append({
                "key": "checkin",
                "summary": "Not checked in yet",
                "body": "It is after %s and you have not checked in today." % checkin,
            })

    if values["remind.break"] and running:
        for line in day["lines"]:
            if line["kind"] != "auto_break":
                continue
            start, end = parse(line["check_in"]), parse(line["check_out"])
            if start <= now < end:
                booked = ("It is booked as check-out and check-in when you check out."
                          if values["break.mode"] == "split" else "It is deducted automatically.")
                out.append({
                    "key": "break:%s" % line["check_in"][11:16],
                    "summary": "Break time",
                    "body": "Break %s–%s. %s" % (line["check_in"][11:16], line["check_out"][11:16], booked),
                })
    return out
