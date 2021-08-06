//
// YbridControl.swift
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

import Foundation


public protocol SimpleControl {
    var mediaEndpoint:MediaEndpoint { get }
    var mediaProtocol:MediaProtocol? { get }
    
    func play()
    func stop()
    
    var state:PlaybackState { get }
    func close()
}

public protocol PlaybackControl: SimpleControl  {
    var canPause:Bool { get }
    func pause()
}

// MARK: ybrid control

public protocol YbridControl : PlaybackControl {
    
    /// time shifting
    func wind(by:TimeInterval, _ audioComplete: AudioCompleteCallback?)
    func windToLive(_ audioComplete: AudioCompleteCallback?)
    func wind(to:Date, _ audioComplete: AudioCompleteCallback?)
    func skipForward(_ type:ItemType?, _ audioComplete: AudioCompleteCallback?)
    func skipBackward(_ type:ItemType?, _ audioComplete: AudioCompleteCallback?)
    
    /// change content
    func swapItem(_ audioComplete: AudioCompleteCallback?)
    func swapService(to id:String, _ audioComplete: AudioCompleteCallback?)
    
    /// limit bit rate of audio content
    func maxBitRate(to:Int32)
    
    /// refresh all states, all methods of the YbridControlListener are called
    func refresh()
}
public typealias AudioCompleteCallback = ((_ success:Bool) -> ())

// selectable maximum bit rates
//public enum BitRate : Int32, CaseIterable {
//    /// demo app is currently making use of order and values of this enum
//    case low = 32_000
//    case mid = 128_000
//    case high = 192_000
//}

// selectable maximum bit rates in kbps
/// demo app is currently making use of order
public let supportedBitRates:[Int32] = [8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 352, 384, 416, 448]

public extension YbridControl {
    /// allow actions without default or audioComplete parameters
    func wind(by:TimeInterval) { wind(by:by, nil) }
    func windToLive() { windToLive(nil) }
    func wind(to:Date) { wind(to:to, nil) }
    func swapItem() { swapItem(nil) }
    func swapService(to id:String) { swapService(to:id, nil) }
    func skipBackward() { skipBackward(nil, nil) }
    func skipBackward(_ type:ItemType) { skipBackward(type, nil) }
    func skipBackward(_ audioComplete: @escaping AudioCompleteCallback) { skipBackward(nil, audioComplete) }
    func skipForward() { skipForward(nil, nil) }
    func skipForward(_ type:ItemType) { skipForward(type, nil) }
    func skipForward(_ audioComplete: @escaping AudioCompleteCallback) { skipForward(nil, audioComplete) }
}

public protocol YbridControlListener : AudioPlayerListener {
    func offsetToLiveChanged(_ offset:TimeInterval?)
    func servicesChanged(_ services:[Service])
    func swapsChanged(_ swapsLeft:Int)
    func bitRateChanged(_ maxBitRate:Int32)
}

// MARK: open

public extension AudioPlayer {
    static private let controllerQueue = DispatchQueue(label: "io.ybrid.audio.controller")

    typealias PlaybackControlCallback = (PlaybackControl) -> ()
    typealias YbridControlCallback = (YbridControl) -> ()
    
    // Create an audio control matching to the MediaEndpoint.
    //
    // First the MediaProtocol is detected and a session is established
    // to handle audio content and metadata of the stream.
    //
    // One of the callback methods provides the specific controller as soon
    // as available.
    //
    // listener - object to be called back from the player process
    static func open(for endpoint:MediaEndpoint, listener: AudioPlayerListener?,
            playbackControl: PlaybackControlCallback? = nil,
              ybridControl: YbridControlCallback? = nil ) throws {
        
        let session = MediaSession(on: endpoint, playerListener: listener)
        try session.connect()
        
        controllerQueue.async {
            switch session.mediaProtocol {
            case .ybridV2:
                let player = YbridAudioPlayer(session: session)
                ybridControl?(player)
            default:
                let player = AudioPlayer(session: session)
                playbackControl?(player)
            }
        }
    }

    // This is a convenience method for tests. It provides a playback control
    // for all endpoints, regardless of the media protocol.
    //
    // You recieve a PlaybackContol in all cases. You cannot use ybrid specific actions.
    //
    // listener - object to be called back from the player process
    static func open(for endpoint:MediaEndpoint, listener: AudioPlayerListener?,
            control: PlaybackControlCallback? = nil ) throws {
        try AudioPlayer.open(for: endpoint, listener: listener, playbackControl: control, ybridControl: control)
    }
}

// MARK: YbridAudioPlayer

class YbridAudioPlayer : AudioPlayer, YbridControl {

    override init(session:MediaSession) {
        super.init(session: session)
        session.notifyChanged( SubInfo.bouquet )
        session.notifyChanged( SubInfo.timeshift )
        session.notifyChanged( SubInfo.playout )
    }
    
    public func maxBitRate(to maxRate:Int32) {
        playerQueue.async {
            self.session.maxBitRate(to: maxRate * 1000)
        }
    }
    
    func refresh() {
        
        DispatchQueue.global().async {
            if let metadata = self.session.metadata {
                super.playerListener?.metadataChanged(metadata)
            }
            if let ybridListener = super.playerListener as? YbridControlListener {
                ybridListener.offsetToLiveChanged(self.session.offset)
                ybridListener.servicesChanged(self.session.services)
                ybridListener.swapsChanged(self.session.swaps)
                ybridListener.bitRateChanged(self.session.maxBitRate)
            }
        }
    }
    
    func wind(by:TimeInterval, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete, SubInfo.timeshift)
            changeover.inProgress(self.session.wind(by:by))
        }
    }
    
    func windToLive( _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete, SubInfo.timeshift)
            changeover.inProgress(self.session.windToLive())
        }
    }
    
    func wind(to:Date, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete, SubInfo.timeshift)
            changeover.inProgress(self.session.wind(to:to))
        }
    }

    func skipForward(_ type:ItemType?, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete, SubInfo.timeshift)
            changeover.inProgress(self.session.skipForward(type))
        }
    }

    func skipBackward(_ type:ItemType?, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete, SubInfo.timeshift)
            changeover.inProgress(self.session.skipBackward(type))
        }
    }
    
    public func swapItem(_ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete, SubInfo.metadata)
            changeover.inProgress(self.session.swapItem())
        }
    }
    public func swapService(to id:String, _ audioComplete: AudioCompleteCallback?) {
        playerQueue.async {
            let changeover = self.newChangeOver(audioComplete, SubInfo.bouquet)
            changeover.inProgress(self.session.swapService(id:id))
        }
    }
        
    // MARK: change over
    
    private func newChangeOver(_ userAudioComplete: AudioCompleteCallback?, _ subtype:SubInfo ) -> ChangeOver {
        
        let audioComplete:AudioCompleteCallback? = { (success) in
            DispatchQueue.global().async {
                userAudioComplete?(success)
            }
        }
        
        switch subtype {
        case .timeshift:
            let wrappedComplete:AudioCompleteCallback = { (success) in
                self.session.notifyChanged(SubInfo.timeshift)
                
                Logger.playing.debug("timeshift complete (success:\(success))")
                audioComplete?(success)
            }
            return ChangeOver(player: self, subtype,
                              ctrlComplete: { self.session.notifyChanged(SubInfo.timeshift, clear: false) },
                              audioComplete: wrappedComplete )
        case .metadata:
            let wrappedComplete:AudioCompleteCallback = { (success) in
                self.session.notifyChanged(SubInfo.metadata)
                
                Logger.playing.debug("swap item complete (success:\(success))")
                audioComplete?(success)
            }
            return ChangeOver(player: self, subtype, audioComplete: wrappedComplete)
        case .bouquet:
            let wrappedComplete:AudioCompleteCallback = { (success) in
                self.session.notifyChanged(SubInfo.bouquet)
                
                Logger.playing.debug("swap service complete (success:\(success))")
                audioComplete?(success)
            }
            return ChangeOver(player: self, subtype, audioComplete: wrappedComplete)

        default:
            let wrappedComplete:AudioCompleteCallback = { (success) in
                self.session.notifyChanged(subtype)
                
                Logger.playing.debug("\(subtype) change complete (success:\(success))")
                audioComplete?(success)
            }
            return ChangeOver(player: self, subtype, audioComplete: wrappedComplete)
        }
    }

    
    class ChangeOver {
        
        private let player:AudioPlayer
        let subInfo:SubInfo
        var ctrlComplete: (() -> ())?
        var audioComplete: AudioCompleteCallback?
        
        init(player:YbridAudioPlayer,_ subInfo:SubInfo, ctrlComplete: (()->())? = nil, audioComplete: AudioCompleteCallback? ) {
            self.player = player
            self.subInfo = subInfo
            self.ctrlComplete = ctrlComplete
            self.audioComplete = audioComplete
        }
        
        fileprivate func inProgress(_ inProgress:Bool) {
            guard let audioComplete = audioComplete else {
                return
            }
            
            if !inProgress {
                audioComplete(false)
                return
            }
            
            ctrlComplete?()
            
            if player.state == .buffering || player.state == .playing {
                player.session.changingOver = self
                player.pipeline?.changeOverInProgress()
            } else {
                audioComplete(true)
            }
        }
        
        func matches(to state:MediaState) -> AudioCompleteCallback? {
            let changed = state.hasChanged(subInfo)
            switch subInfo {
            case .metadata:
                Logger.session.notice("change over \(subInfo), metadata did \(changed ? "":"not ")change")
            case .timeshift:
                 Logger.session.notice("change over \(subInfo), offset did \(changed ? "":"not ")change")
            case .bouquet:
                Logger.session.notice("change over \(subInfo), active service did \(changed ? "":"not ")change")
            default:
                Logger.session.error("change over \(subInfo) doesn't match to media state \(state)")
            }  
            
            if changed {
                return self.audioComplete
            }
            return nil
        }
    }

}



