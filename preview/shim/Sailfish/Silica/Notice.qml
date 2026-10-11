import QtQuick 2.10

// Preview stand-in for Silica's Notice enums (used with Notices.show).
QtObject {
    enum Duration { Short = 3000, Long = 5000 }
    enum Anchor { Center = 0, Left = 1, Right = 2, Top = 4, Bottom = 8 }
}
