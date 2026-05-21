package dev.viethung.skylog

import io.kotest.matchers.shouldBe
import kotlin.test.Test
import kotlin.test.assertTrue

class SeverityTest {

    // Row 1: Verbose < Debug < Info < Warn < Error < Assert
    @Test
    fun orderingIsCorrect() {
        assertTrue(Severity.Verbose < Severity.Debug)
        assertTrue(Severity.Debug   < Severity.Info)
        assertTrue(Severity.Info    < Severity.Warn)
        assertTrue(Severity.Warn    < Severity.Error)
        assertTrue(Severity.Error   < Severity.Assert)
    }

    // Row 2: Severity ordinals stable
    @Test
    fun ordinalsAreStable() {
        Severity.Verbose.ordinal shouldBe 0
        Severity.Debug.ordinal   shouldBe 1
        Severity.Info.ordinal    shouldBe 2
        Severity.Warn.ordinal    shouldBe 3
        Severity.Error.ordinal   shouldBe 4
        Severity.Assert.ordinal  shouldBe 5
    }
}
