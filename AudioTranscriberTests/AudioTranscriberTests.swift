//
//  AudioTranscriberTests.swift
//  AudioTranscriberTests
//
//  Created by user281756 on 7/2/25.
//

import Testing
import XCTest
@testable import AudioTranscriber

struct AudioTranscriberTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

final class AudioTranscriberModelTests: XCTestCase {
    func testRecordingSessionAndSegmentRelationship() {
        let session = RecordingSession(baseFileName: "TestSession")
        let segment = TranscriptionSegment(
            segmentIndex: 1,
            startTime: 0,
            duration: 30,
            fileURL: URL(fileURLWithPath: "/tmp/test.caf"),
            session: session
        )
        session.segments.append(segment)
        XCTAssertEqual(session.segments.count, 1)
        XCTAssertEqual(session.segments.first?.segmentIndex, 1)
        XCTAssertEqual(segment.session?.baseFileName, "TestSession")
    }
}

@MainActor
final class AudioServiceStateTests: XCTestCase {
    func testRecordingStateTransitions() async {
        let service = AudioService()
        XCTAssertFalse(service.isRecording)
        // The following calls are placeholders; actual audio recording cannot be tested in unit tests without mocks.
        // service.startRecording()
        // XCTAssertTrue(service.isRecording)
        // service.pauseRecording()
        // XCTAssertTrue(service.isPaused)
        // service.resumeRecording()
        // XCTAssertFalse(service.isPaused)
        // service.stopRecording()
        // XCTAssertFalse(service.isRecording)
    }
}
