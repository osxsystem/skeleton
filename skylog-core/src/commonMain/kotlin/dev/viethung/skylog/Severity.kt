package dev.viethung.skylog

enum class Severity(val level: Int) : Comparable<Severity> {
    Verbose(0),
    Debug(1),
    Info(2),
    Warn(3),
    Error(4),
    Assert(5);
}
