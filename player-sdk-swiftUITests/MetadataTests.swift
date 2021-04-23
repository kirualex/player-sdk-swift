//
// MetadataTests.swift
// player-sdk-swift
//
// Copyright (c) 2021 nacamar GmbH - Ybrid®, a Hybrid Dynamic Live Audio Technology
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import XCTest
import YbridPlayerSDK

class MetadataTests: XCTestCase {

    let metadataListener = TestMetadataListener()
    override func setUpWithError() throws {
        metadataListener.displayTitleCalled = 0
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test01_YbridMetadata_OnEachPlayAndIcy() throws {
        let uri = "https://stagecast.ybrid.io/adaptive-demo"
        //        let uri = "https://stagecast.ybrid.io/swr3/mp3/mid"
        let endpoint = MediaEndpoint(mediaUri: uri)
        let session = endpoint.createSession()
        let player = AudioPlayer(session: session, listener: metadataListener)
        self.playSleepCheckStopPlaySleepCheck(on: player,
                            fistCheck: { self.checkMinimumMetadataCalls(2) },
                            secondCheck: { self.checkMinimumMetadataCalls(3) }
        )
    }
    
    func test02_YbridMetadata_OnPlayAndIcyTriggered() throws {
        let uri = "https://stagecast.ybrid.io/adaptive-demo"
//        let uri = "https://stagecast.ybrid.io/swr3/mp3/mid"
        let endpoint = MediaEndpoint(mediaUri: uri)
        let session = endpoint.createSession()
        let player = AudioPlayer(session: session, listener: metadataListener)
        self.playCheckSleepCheck(on: player,
                            fistCheck: { self.checkMetadataCalls(1) },
                            secondCheck: { self.checkMinimumMetadataCalls(2) }
        )
    }
    
    
    
    func test03_IcyMetadata_OnIcyTriggerred() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3")
        let session = endpoint.createSession()
        let player = AudioPlayer(session: session, listener: metadataListener)
        self.playSleepCheckStopPlaySleepCheck(on: player,
                            fistCheck: { self.checkMinimumMetadataCalls(1) },
                            secondCheck: { self.checkMinimumMetadataCalls(2) }
        )
    }
    
    func test04_IcyMetadata_NotEarly() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3")
        let session = endpoint.createSession()
        let player = AudioPlayer(session: session, listener: metadataListener)
        self.playCheckSleepCheck(on: player,
                            fistCheck: { self.checkMetadataCalls(0) },
                            secondCheck: { self.checkMinimumMetadataCalls(1) }
        )
    }

    func test05_OpusMetadata_OnVoribisCommentTriggered() throws {
        let endpoint = MediaEndpoint(mediaUri: "http://theradio.cc:8000/trcc-stream.opus")
        let session = endpoint.createSession()
        let player = AudioPlayer(session: session, listener: metadataListener)
        self.playSleepCheckStopPlaySleepCheck(on: player,
                            fistCheck: { self.checkMinimumMetadataCalls(1) },
                            secondCheck: { self.checkMinimumMetadataCalls(2) }
        )
    }
    
    func test06_OpusNoMetadata_NoneOnPlay() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")
        let session = endpoint.createSession()
        let player = AudioPlayer(session: session, listener: metadataListener)
        self.playSleepCheckStopPlaySleepCheck(on: player,
                            fistCheck: { self.checkMetadataCalls(0) },
                            secondCheck: { self.checkMetadataCalls(0) }
        )
    }
    
    private func playSleepCheckStopPlaySleepCheck(on player: AudioPlayer, fistCheck: () -> (), secondCheck: () -> () ) {
        player.play()
        sleep(5)
        XCTAssertEqual(PlaybackState.playing, player.state)
        fistCheck()
        player.stop()
        sleep(1)
        XCTAssertEqual(PlaybackState.stopped, player.state)
        
        player.play()
        sleep(3)
        XCTAssertEqual(PlaybackState.playing, player.state)
        secondCheck()
        player.stop()
        sleep(1)
    }

    private func playCheckSleepCheck(on player: AudioPlayer, fistCheck: () -> (), secondCheck: () -> () ) {
        player.play()
        fistCheck()
        sleep(4)
        XCTAssertEqual(PlaybackState.playing, player.state)
        secondCheck()
        player.stop()
        sleep(1)
    }
    
    private func checkMinimumMetadataCalls(_ expectedMinCalls: Int) {
        let called = metadataListener.displayTitleCalled
        XCTAssertTrue( called >= expectedMinCalls, "expected >=\(expectedMinCalls)  calls, but was \(called)")
    }
    
    private func checkMetadataCalls(_ expectedCalls: Int) {
        let called = metadataListener.displayTitleCalled
        XCTAssertTrue( called == expectedCalls,  "expected == \(expectedCalls)  calls, but was \(called)")
    }
    
     
    class TestMetadataListener : AbstractAudioPlayerListener {
        
        var displayTitleCalled = 0
        
        override func displayTitleChanged(_ title: String?) {
            displayTitleCalled += 1
            Logger.testing.info("-- combined display title is \(title ?? "(nil)")")
            XCTAssertNotNil(title)
        }
    }
}


