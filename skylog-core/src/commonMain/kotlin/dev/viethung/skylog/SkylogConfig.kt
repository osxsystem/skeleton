package dev.viethung.skylog

class SkylogConfig(
    var minSeverity: Severity = Severity.Verbose,
    val writers: MutableList<LogWriter> = mutableListOf(),
) {
    internal fun copy(): SkylogConfig = SkylogConfig(minSeverity, writers.toMutableList())
}
