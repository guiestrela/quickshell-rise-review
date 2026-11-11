import QtQuick
import QtTest
import "../shared/integrations/elsewhen" as Elsewhen

Item {
    id: testRoot
    width: 260
    height: 40
    property real scrubStart: -1
    property real scrubMove: -1
    property int scrubEndCount: 0

    Elsewhen.DaylightStrip {
        id: strip
        x: 10
        y: 10
        width: 240
        height: 18
        ready: true
        place: ({ lat: 0, lon: 0 })
        offsetMinutes: 0
        nowMs: Date.UTC(2024, 2, 20, 12, 0, 0)
        progress: 0.5
        onScrubStarted: function(fraction) { testRoot.scrubStart = fraction }
        onScrubMoved: function(fraction) { testRoot.scrubMove = fraction }
        onScrubEnded: testRoot.scrubEndCount++
    }

    TestCase {
        name: "ElsewhenDaylightStrip"
        when: windowShown

        function init() {
            testRoot.scrubStart = -1
            testRoot.scrubMove = -1
            testRoot.scrubEndCount = 0
        }

        function test_equatorial_day_has_solar_band_and_event_marks() {
            compare(strip.sun.kind, "normal")
            compare(strip.sunMarks.length, 2)
            verify(strip.sunMarks[0].rising)
            verify(!strip.sunMarks[1].rising)
            verify(strip.sunMarks[0].minutes < strip.sunMarks[1].minutes)
            verify(strip.litNow)
        }

        function test_drag_scrubs_and_emits_end() {
            mouseDrag(strip.scrubArea, 32, 8, 120, 0, Qt.LeftButton)
            compare(Math.round(testRoot.scrubStart * 100), Math.round((32 / 240) * 100))
            verify(testRoot.scrubMove > testRoot.scrubStart)
            compare(testRoot.scrubEndCount, 1)
        }
    }
}
