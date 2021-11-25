//
// Metadata.swift
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

// Metadata contains data corresponding to a time period or a single instance of a stream.
// The data can origin from different sources. In general it is up to the purpose
// which of the data is relevant.

import Foundation

public protocol Metadata {

    var displayTitle: String { get }
    
    var current: Item { get }
    var next: Item? { get }
    
    var service: Service { get }
}

public struct Item {
    public let displayTitle: String
    public let identifier: String?
    public let type: ItemType?
    public let title: String?
    public let artist: String?
    public let album: String?
    public let version: String?
    public let description: String?
    public let playbackLength: TimeInterval?
    public let genre: String?
    public let infoUri: String?
    public let companions: [String]?
    
    init(displayTitle: String, identifier: String? = nil, type: ItemType? = nil,
         title: String? = nil, artist: String? = nil, album: String? = nil, version: String? = nil,
         description: String? = nil, playbackLength: TimeInterval? = nil, genre: String? = nil,
         infoUri: String? = nil, companions: [String]? = nil) {
        self.displayTitle = displayTitle
        self.identifier = identifier
        self.type = type
        self.title = title
        self.artist = artist
        self.album = album
        self.version  = version
        self.description = description
        self.playbackLength = playbackLength
        self.genre = genre
        self.infoUri = infoUri
        self.companions = companions
      }
}

public enum ItemType : String  {
    case ADVERTISEMENT = "ADVERTISEMENT"
    case COMEDY = "COMEDY"
    case JINGLE = "JINGLE"
    case MUSIC = "MUSIC"
    case NEWS = "NEWS"
    case TRAFFIC = "TRAFFIC"
    case VOICE = "VOICE"
    case WEATHER = "WEATHER"
    case UNKNOWN
}

public struct Service : Equatable {
    public let identifier:String
    public var displayName:String? = nil
    public var iconUri:String? = nil
    public var genre: String? = nil
    public var description: String? = nil
    public var infoUri:String? = nil
}

class AbstractMetadata : Metadata {
    
    internal var currentInfo:Item? { get { return nil }}
    internal var nextInfo:Item? { get { return nil }}
    internal var serviceInfo: Service? { get { return nil }}

    internal var delegate:AbstractMetadata? { didSet {
        if streamUrl == nil, let _ = oldValue?.streamUrl {
            // TODO keep streamUrl
        }
    }}
    
    private var superiorService: Service?
    
    internal var eligible:Bool { get {
        return currentInfo != nil || nextInfo != nil || serviceInfo != nil
        || streamUrl != nil || delegate?.eligible == true
    }}
    internal var description:String { get { return "\(type(of: self))" } }
    
    init() {}
    
    func delegate(to other: AbstractMetadata) {
        self.delegate = other
    }
    
    var streamUrl:String? { get {
        if let icyStreamUrl = (delegate as? IcyMetadata)?.streamUrl {
            return icyStreamUrl
        }
        return nil
    }}
    
    func setService( _ service:Service) {
        if let delegate = delegate {
            delegate.setService(service)
            return
        }
        superiorService = service
    }
    
    public final var displayTitle: String {
        if let delegate = delegate {
            return delegate.displayTitle
        }
        return currentInfo?.displayTitle ?? AbstractMetadata.dummyItem.displayTitle
    }
    
    private static let dummyItem = Item(displayTitle: "")
    public final var current: Item {
        return delegate?.currentInfo ?? currentInfo ?? AbstractMetadata.dummyItem
    }
    
    public final var next: Item?  {
        return delegate?.nextInfo ?? nextInfo
    }
    
    private static let defaultService = Service(identifier: "default", displayName: "")
    public final var service: Service {
        return delegate?.superiorService ?? delegate?.serviceInfo ?? superiorService ?? serviceInfo ?? AbstractMetadata.defaultService
    }
    
}

