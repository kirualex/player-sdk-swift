//
// YbridControlTests.swift
// player-sdk-swiftUITests
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

class YbridControlTests: XCTestCase {

    let liveOffsetRange_LostSign = TimeInterval(0.0) ..< TimeInterval(10.0)
    let maxWindResponseS = 2
    
    var player:YbridControl?
    let allListener = TestYbridPlayerListener()
    var semaphore:DispatchSemaphore?
    override func setUpWithError() throws {
        // don't log additional debug information in this tests
        Logger.verbose = false
        allListener.reset()
        semaphore = DispatchSemaphore(value: 0)
    }
    
    override func tearDownWithError() throws {
        print( "offsets were \(allListener.offsets)")
    }
    
    func test01_YbridControl_GettingOffset_NoListener() throws {
        
        try AudioPlayer.initialize(for: ybridStageSwr3Endpoint, listener: allListener,
               ybridControl: { [self] (ybridControl) in
                
                let offset = ybridControl.offsetToLiveS
                Logger.testing.notice("offset to live is \(offset.S)")
                XCTAssertTrue(liveOffsetRange_LostSign.contains(-offset))
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertEqual(allListener.offsetChanges, 0)
    }
    
    func test02_YbridControl_ListeningToOffsetChanges() throws {
        
        try AudioPlayer.initialize(for: ybridStageSwr3Endpoint, listener: nil,
               ybridControl: { [self] (ybridControl) in
                var control = ybridControl
                
                allListener.control = ybridControl
                control.listener = allListener
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertGreaterThanOrEqual(allListener.offsetChanges, 1)
        allListener.offsets.forEach{
            XCTAssertTrue(liveOffsetRange_LostSign.contains(-$0))
        }
    }
    
    func test03_YbridControl_WindBack() throws {
        try AudioPlayer.initialize(for: ybridStageSwr3Endpoint, listener: allListener,
               ybridControl: { [self] (ybridControl) in
                var control = ybridControl
                
                allListener.control = ybridControl
                control.listener = allListener
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                ybridControl.wind(by: -20.0)
                wait(ybridControl, shifted: -20.0, maxSeconds: 2)
                sleep(4)
                
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertGreaterThanOrEqual(allListener.offsetChanges, 2, "expected to be at least the initial and one more change of offset")
        guard let lastOffset = allListener.offsets.last else {
            XCTFail(); return
        }
        let shiftedRangeNegated = shift(liveOffsetRange_LostSign, by: +20.0)
        XCTAssertTrue(shiftedRangeNegated.contains(-lastOffset), "\(-lastOffset) not within \(shiftedRangeNegated)")
    }
    
    func test04_YbridControl_WindToLive() throws {
        try AudioPlayer.initialize(for: ybridStageSwr3Endpoint, listener: allListener,
               ybridControl: { [self] (ybridControl) in
                var control = ybridControl
                
                allListener.control = ybridControl
                control.listener = allListener
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
                ybridControl.wind(by:-20.0)
                wait(ybridControl, shifted: -20.0, maxSeconds: maxWindResponseS)
                sleep(4)
                ybridControl.windToLive()
                wait(ybridControl, shifted: 0.0, maxSeconds: maxWindResponseS)
                sleep(4)
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: maxWindResponseS)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertGreaterThanOrEqual(allListener.offsetChanges, 3, "expected to be at least the initial and two more changes of offset")
        guard let lastOffset = allListener.offsets.last else {
            XCTFail(); return
        }
        XCTAssertTrue(liveOffsetRange_LostSign.contains(-lastOffset), "\(-lastOffset) not within \(liveOffsetRange_LostSign)")
        
    }
    
    
    private func shift( _ range:Range<TimeInterval>, by:TimeInterval ) -> Range<TimeInterval> {
        let shiftedRange = range.lowerBound+by ..< range.upperBound+by
        return shiftedRange
    }

    private func wait(_ control:YbridControl, shifted: TimeInterval, maxSeconds:Int) {
        let shiftedRange_LostSign = shift(liveOffsetRange_LostSign, by: -shifted)
        let took = wait(max: maxSeconds) {
            return isOffset(control.offsetToLiveS, shifted: shifted)
        }
        XCTAssertLessThanOrEqual(took, maxSeconds, "offset to live not \((-shiftedRange_LostSign.lowerBound).S) ..< \((-shiftedRange_LostSign.upperBound).S) within \(maxSeconds) s")
    }
    
    private func wait(_ control:YbridControl, until:PlaybackState, maxSeconds:Int) {
        let took = wait(max: maxSeconds) {
            return control.state == until
        }
        XCTAssertLessThanOrEqual(took, maxSeconds, "not \(until) within \(maxSeconds) s")
    }
    
    private func wait(max maxSeconds:Int, until:() -> (Bool)) -> Int {
        var seconds = 0
        while !until() && seconds <= maxSeconds {
            sleep(1)
            seconds += 1
        }
        XCTAssertTrue(until(), "condition not satisfied within \(maxSeconds) s")
        return seconds
    }
    
    func isOffset(_ offset:TimeInterval, shifted:TimeInterval) -> Bool {
        let shiftedRange_LostSign = shift(liveOffsetRange_LostSign, by: -shifted)
        return shiftedRange_LostSign.contains(-offset)
    }
    
}

class TestYbridPlayerListener : AbstractAudioPlayerListener, YbridControlListener {
    
    var control:YbridControl?
    
    var offsetChanges:Int { get {
        return offsets.count
    }}
    
    var offsets:[TimeInterval] = []
    func offsetToLiveChanged() {
        guard let offset = control?.offsetToLiveS else { XCTFail(); return }
        offsets.append(offset)
    }
    
    func reset() {
        offsets.removeAll()
    }
}