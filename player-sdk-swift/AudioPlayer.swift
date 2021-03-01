//
// AudioPlayer.swift
// player-sdk-swift
//
// Copyright (c) 2020 nacamar GmbH - Ybrid®, a Hybrid Dynamic Live Audio Technology
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

// Playing audio.

import AVFoundation

// called back while processing
public protocol AudioPlayerListener : class {
    // the playback state has changed
    func stateChanged(_ state: PlaybackState)
    // metadata to the content currently playing has changed
    func displayTitleChanged(_ title: String?)
    // message text concerning failures
    func currentProblem(_ text: String?)
    // duration of audio presented already, called every 0.2 seconds
    func playingSince(_ seconds: TimeInterval?)
    // duration between triggering play and first audio presented
    func durationReadyToPlay(_ seconds: TimeInterval?)
    // duration between triggering play and first response from the media url
    func durationConnected(_ seconds: TimeInterval?)
    // duration of playback cached, currently and averaged over the last 3 seconds. Called every 0.2 seconds.
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?)
}

public enum PlaybackState {
    case buffering // audio will play (preparing or stalling)
    case playing // audio is playing
    case stopped // no audio will play
}

public class AudioPlayer: BufferListener, PipelineListener {

    public static var versionString:String {
        get {
            let bundleId = "io.ybrid.player-sdk-swift"
            guard let info = Bundle(identifier: bundleId)?.infoDictionary else {
                Logger.shared.error("bundle \(bundleId) not found")
                return "bundle \(bundleId) not found"
            }
            Logger.shared.debug("bundle \(bundleId) info \(info)")
            let version = info["CFBundleShortVersionString"] ?? "(unknown)"
            let name = info["CFBundleName"] ?? "(unknown)"
            let build = info["CFBundleVersion"]  ?? "(unknown)"
            return "\(name) version \(version) (build \(build))"
        }
    }

    public var state: PlaybackState = .stopped {
        didSet {
            Logger.shared.notice("\(state)")
            playerListener?.stateChanged(state)
        }
    }
    
    
    let streamUrl: URL
    let icyMetadata: Bool = true
    
    private let playerQueue = DispatchQueue(label: "io.ybrid.playing")
    
    var loader: AudioDataLoader?
    var pipeline: AudioPipeline?
    var playback: Playback?
    
    private weak var playerListener:AudioPlayerListener?
    
    // get ready for playing
    // mediaUrl - the provided audio. Supports mp3, aac and opus.
    // listener - object to be called back from the player process
    public init(mediaUrl: URL, listener: AudioPlayerListener?) {
        self.playerListener = listener
        self.streamUrl = mediaUrl
        PlayerContext.setupAudioSession()
    }
    
    deinit {
        Logger.shared.debug()
        PlayerContext.deactivate()
    }
    
    // MARK: actions
    
    // Asynchronously start playback of audio of the given media url as soon as possible.
    public func play() {
        guard state == .stopped  else {
            Logger.shared.notice("already running")
            return
        }
        state = .buffering
        playerQueue.async {
            self.playWhenReady()
        }
    }
    
    // Stop playback immediatly and clean up asychronously.
    public func stop() {
        pipeline?.stopProcessing()
        playerQueue.async {
            self.stopPlaying()
            self.state = .stopped
        }
    }
    
    private func playWhenReady() {
        pipeline = AudioPipeline(pipelineListener: self, playerListener:                                     playerListener)
        loader = AudioDataLoader(mediaUrl: streamUrl, pipeline: pipeline!, inclMetadata: icyMetadata)
        loader?.requestData(from: streamUrl)
    }
    
    private func stopPlaying() {
        playback?.stop()
        loader?.stopRequestData()
        pipeline?.dispose()
    }
    
    // MARK: pipeline listener
    
    func ready(playback: Playback) {
        switch state {
        case .stopped:
            Logger.shared.debug("should not begin playing.")
            pipeline?.stopProcessing()
            playback.stop()
            loader?.stopRequestData()
            pipeline?.dispose()
            return
        case .playing:
            Logger.shared.error("should not play already.")
        case .buffering:
            self.playback = playback
            playback.setListener(listener: self)
        }
    }
    
    func problem(_ type: ProblemType, _ message: String) {
        
        playerListener?.currentProblem(message)
        switch type {
        case .solved:
            DispatchQueue.global().async {
                sleep(5) ; self.playerListener?.currentProblem(nil)
            }
        case .notice:
            Logger.shared.notice(message)
        case .stalled:
            Logger.shared.notice(message)
        case .fatal:
            Logger.shared.error(message)
            stop()
        case .unknown:
            Logger.shared.notice(message)
        }
    }
    
    // MARK: BufferListener
    
    func stateChanged(_ bufferState: PlaybackBuffer.BufferState) {
        
        if state == .buffering && bufferState == .ready {
            state = .playing
        }
        
        if state == .playing && bufferState == .empty {
            state = .buffering
        }
    }
}