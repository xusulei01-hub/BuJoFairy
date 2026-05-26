import XCTest
@testable import TravelJournal

final class JournalPromptBuilderTests: XCTestCase {

    func testExtractJSONFromMarkdownCodeBlock() {
        let input = """
        ```json
        {"pages": [{"type": "cover", "title": "My Trip"}]}
        ```
        """
        let result = JournalPromptBuilder.extractJSON(from: input)
        XCTAssertNotNil(result)
        let json = String(data: result!, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"pages\""))
    }

    func testExtractJSONFromPlainJSON() {
        let input = #"{"pages": [{"type": "cover", "title": "My Trip"}]}"#
        let result = JournalPromptBuilder.extractJSON(from: input)
        XCTAssertNotNil(result)
        let json = String(data: result!, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"pages\""))
    }

    func testExtractJSONFromMixedText() {
        let input = """
        Here is the journal content:
        {"pages": [{"type": "daily", "text": "Day 1 notes"}]}
        Hope you like it!
        """
        let result = JournalPromptBuilder.extractJSON(from: input)
        XCTAssertNotNil(result)
        let json = String(data: result!, encoding: .utf8)!
        XCTAssertTrue(json.contains("Day 1 notes"))
    }

    func testExtractJSONFromCodeBlockWithoutLanguage() {
        let input = """
        ```
        {"pages": [{"type": "gallery", "photoIndices": [0, 1, 2]}]}
        ```
        """
        let result = JournalPromptBuilder.extractJSON(from: input)
        XCTAssertNotNil(result)
        let json = String(data: result!, encoding: .utf8)!
        XCTAssertTrue(json.contains("photoIndices"))
    }

    func testExtractJSONTrimsWhitespace() {
        let input = """

          {"pages": []}

        """
        let result = JournalPromptBuilder.extractJSON(from: input)
        XCTAssertNotNil(result)
        let json = String(data: result!, encoding: .utf8)!
        XCTAssertTrue(json.contains("pages"))
    }
}
