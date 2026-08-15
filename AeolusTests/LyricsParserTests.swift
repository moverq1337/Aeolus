import Testing
@testable import Aeolus

struct LyricsParserTests {
    let lrc = """
    [00:12.34] Первая строка
    [00:15.00] Вторая строка
    [01:02.50] Третья строка
    """

    @Test func parsesTimestampedLines() {
        let lines = LyricsParser.parse(lrc)
        #expect(lines.count == 3)
        #expect(abs(lines[0].time - 12.34) < 0.001)
        #expect(lines[0].text == "Первая строка")
        #expect(abs(lines[2].time - 62.5) < 0.001)
    }

    @Test func currentLineByPosition() {
        let lines = LyricsParser.parse(lrc)
        #expect(LyricsParser.currentLine(lines, at: 5) == nil)     // до первой
        #expect(LyricsParser.currentLine(lines, at: 13)?.text == "Первая строка")
        #expect(LyricsParser.currentLine(lines, at: 20)?.text == "Вторая строка")
        #expect(LyricsParser.currentLine(lines, at: 300)?.text == "Третья строка")
    }

    @Test func skipsMalformedLines() {
        let messy = "не строка\n[00:05.00] норм\n[abc] мусор"
        let lines = LyricsParser.parse(messy)
        #expect(lines.count == 1)
        #expect(lines[0].text == "норм")
    }
}
