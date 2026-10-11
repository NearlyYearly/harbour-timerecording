.pragma library
// SPDX-License-Identifier: GPL-3.0-or-later

// Minutes -> "h:mm" (negative values get a leading minus).
function duration(min) {
    if (min === undefined || min === null) return ""
    var sign = min < 0 ? "-" : ""
    min = Math.abs(Math.round(min))
    var m = min % 60
    return sign + Math.floor(min / 60) + ":" + (m < 10 ? "0" : "") + m
}

function signedDuration(min) {
    return (min > 0 ? "+" : "") + duration(min)
}

// "2026-10-05T08:01" -> "08:01"
function time(iso) {
    return iso ? iso.substr(11, 5) : ""
}

function pad(n) {
    return (n < 10 ? "0" : "") + n
}

function isoDate(d) {
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
}

function isoDateTime(d) {
    return isoDate(d) + "T" + pad(d.getHours()) + ":" + pad(d.getMinutes())
}

// Local date from "YYYY-MM-DD" (Date("YYYY-MM-DD") would be UTC).
function parseDate(s) {
    var p = s.split("-")
    return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]))
}

function parseDateTime(s) {
    var d = parseDate(s.substr(0, 10))
    d.setHours(Number(s.substr(11, 2)), Number(s.substr(14, 2)))
    return d
}

function addDays(s, n) {
    var d = parseDate(s)
    d.setDate(d.getDate() + n)
    return isoDate(d)
}

function daysBetween(a, b) {
    return Math.round((parseDate(b) - parseDate(a)) / 86400000)
}

// "h:mm" or "h" (optionally with a leading minus) -> minutes, NaN when invalid.
function parseDuration(text) {
    var m = String(text).trim().match(/^(-?)(\d{1,3})(?::(\d{2}))?$/)
    if (!m) return NaN
    var mins = m[3] === undefined ? 0 : Number(m[3])
    if (mins > 59) return NaN
    var total = Number(m[2]) * 60 + mins
    return m[1] ? -total : total
}
