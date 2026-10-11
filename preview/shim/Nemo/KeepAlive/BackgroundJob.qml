import QtQuick 2.10

// Preview stand-in: a plain timer (no wake-ups from suspend on the desktop).
QtObject {
    id: job

    enum Frequency {
        Range = 0, ThirtySeconds = 30, TwoAndHalfMinutes = 150, FiveMinutes = 300,
        TenMinutes = 600, FifteenMinutes = 900, ThirtyMinutes = 1800, OneHour = 3600
    }

    property bool enabled: false
    property int frequency: 150
    property bool triggeredOnEnable: false
    property bool running: false

    signal triggered()

    function begin() { running = true }
    function finished() { running = false }

    property Timer _timer: Timer {
        interval: Math.max(1, job.frequency) * 1000
        repeat: true
        running: job.enabled
        triggeredOnStart: job.triggeredOnEnable
        onTriggered: { job.running = true; job.triggered() }
    }
}
