//
//  SignalingService.swift
//  webrtc_ios
//
//  Created by thomas on 2016-02-26.
//  Copyright © 2016 thomas. All rights reserved.
//


import Foundation
import MultipeerConnectivity

class Channel {
    var session: MCSession
    var peer: MCPeerID
    var status: String

    init(session: MCSession, peer: MCPeerID) {
        self.session = session
        self.peer = peer
        self.status = "new"
    }

    func sendData(_ data : String) -> Bool {
        if session.connectedPeers.contains(peer) {
            do {
                try self.session.send(data.data(using: String.Encoding.utf8, allowLossyConversion: false)!, toPeers: [peer], with: MCSessionSendDataMode.reliable)
                return true
            } catch let error as NSError {
                NSLog("\(error)")
                return false
            }
        } else {
            return false
        }
    }

    func close() {
        // FIXME.
    }
}

protocol DiscoveryServiceDelegate {
    func onPeerChanged(_ peers:[String])
}

protocol SignalingServiceDelegate {
    func onChannelChanged(_ channel: Channel, status: String)
    func onDataReceived(_ channel: Channel, data: String)
    func name() -> String
}

class SignalingService : NSObject {
    fileprivate let ServiceType = "ts"
    fileprivate let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    fileprivate let serviceAdvertiser : MCNearbyServiceAdvertiser
    fileprivate let serviceBrowser : MCNearbyServiceBrowser
    var peers = [String: MCPeerID]()
    var channels = [MCPeerID: Channel]()
    var delegate : SignalingServiceDelegate?
    var discovery: DiscoveryServiceDelegate?

    override init() {
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: ServiceType)

        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: ServiceType)

        super.init()
        
        self.serviceAdvertiser.delegate = self
        self.serviceAdvertiser.startAdvertisingPeer()
        
        self.serviceBrowser.delegate = self
        self.serviceBrowser.startBrowsingForPeers()
    }

    deinit {
        self.serviceAdvertiser.stopAdvertisingPeer()
        self.serviceBrowser.stopBrowsingForPeers()
    }
    
    lazy var session: MCSession = {
        let session = MCSession(peer: self.myPeerId, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.required)
        session.delegate = self
        return session
    }()

    func createChannel(_ peer: String) -> Channel? {
        NSLog("createChannel to \(peer)")
        if let p = peers[peer] {
            let channel = Channel(session: self.session, peer: p)
            channels[p] = channel
            serviceBrowser.invitePeer(p, to: self.session, withContext: nil, timeout: 10)
            
            return channel
        }
        
        NSLog("don't know who is \(peer)")
        return nil
    }

    func addDelegate(_ delegate: SignalingServiceDelegate) {
        // FIXME. right now, it's set, not add.
        self.delegate = delegate
    }
}

extension SignalingService : MCNearbyServiceAdvertiserDelegate {
    @available(iOS 7.0, *)
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        NSLog("didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, self.session)

    }


    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("didNotStartAdvertisingPeer: \(error)")
    }

}

extension SignalingService : MCNearbyServiceBrowserDelegate {

    func updateDiscoveryDelegate() {
        var ps = [String]()
        for (name, _) in peers {
            ps.append(name)
        }
        self.discovery?.onPeerChanged(ps)
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        NSLog("didNotStartBrowsingForPeers: \(error)")
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("foundPeer: \(peerID)")
        peers[peerID.displayName] = peerID
        updateDiscoveryDelegate()
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("lostPeer: \(peerID)")
        peers.removeValue(forKey: peerID.displayName)
        updateDiscoveryDelegate()
    }
}

extension MCSessionState {

    func stringValue() -> String {
        switch(self) {
        case .notConnected: return "NotConnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        }
    }
    
}

extension SignalingService : MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        NSLog("peer \(peerID) didChangeState: \(state.stringValue())")

        switch (state) {
        case .connected:
            if let channel = channels[peerID] {
                channel.status = "created"
                self.delegate?.onChannelChanged(channel, status: "created")
            } else {
                let newChannel = Channel(session: session, peer: peerID)
                channels[peerID] = newChannel
                newChannel.status = "received"
                self.delegate?.onChannelChanged(newChannel, status: "received")
            }
            return
        case .connecting:
            return
        case .notConnected:
            peers.removeValue(forKey: peerID.displayName)
            channels.removeValue(forKey: peerID)
            return
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        NSLog("didReceiveData: \(data.count) bytes")
        let str = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
        
        if let channel = channels[peerID] {
            self.delegate?.onDataReceived(channel, data: str)
        } else {
            NSLog("Can't find channel!")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("didReceiveStream")
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?) {
        NSLog("didFinishReceivingResourceWithName")
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        NSLog("didStartReceivingResourceWithName")
    }
}
