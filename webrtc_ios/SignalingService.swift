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

    func sendData(data : String) -> Bool {
        if session.connectedPeers.contains(peer) {
            do {
                try self.session.sendData(data.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!, toPeers: [peer], withMode: MCSessionSendDataMode.Reliable)
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
    func onPeerChanged(peers:[String])
}

protocol SignalingServiceDelegate {
    func onChannelChanged(channel: Channel, status: String)
    func onDataReceived(channel: Channel, data: String)
    func name() -> String
}

class SignalingService : NSObject {
    private let ServiceType = "ts"
    private let myPeerId = MCPeerID(displayName: UIDevice.currentDevice().name)
    private let serviceAdvertiser : MCNearbyServiceAdvertiser
    private let serviceBrowser : MCNearbyServiceBrowser
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
        let session = MCSession(peer: self.myPeerId, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.Required)
        session.delegate = self
        return session
    }()

    func createChannel(peer: String) -> Channel? {
        NSLog("createChannel to \(peer)")
        if let p = peers[peer] {
            let channel = Channel(session: self.session, peer: p)
            channels[p] = channel
            serviceBrowser.invitePeer(p, toSession: self.session, withContext: nil, timeout: 10)
            
            return channel
        }
        
        NSLog("don't know who is \(peer)")
        return nil
    }

    func addDelegate(delegate: SignalingServiceDelegate) {
        // FIXME. right now, it's set, not add.
        self.delegate = delegate
    }
}

extension SignalingService : MCNearbyServiceAdvertiserDelegate {

    func advertiser(advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: NSError) {
        NSLog("didNotStartAdvertisingPeer: \(error)")
    }

    func advertiser(advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: NSData?, invitationHandler: ((Bool, MCSession) -> Void)) {
        
        NSLog("didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, self.session)
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

    func browser(browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: NSError) {
        NSLog("didNotStartBrowsingForPeers: \(error)")
    }

    func browser(browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("foundPeer: \(peerID)")
        peers[peerID.displayName] = peerID
        updateDiscoveryDelegate()
    }

    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("lostPeer: \(peerID)")
        peers.removeValueForKey(peerID.displayName)
        updateDiscoveryDelegate()
    }
}

extension MCSessionState {

    func stringValue() -> String {
        switch(self) {
        case .NotConnected: return "NotConnected"
        case .Connecting: return "Connecting"
        case .Connected: return "Connected"
        }
    }
    
}

extension SignalingService : MCSessionDelegate {

    func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        NSLog("peer \(peerID) didChangeState: \(state.stringValue())")

        switch (state) {
        case .Connected:
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
        case .Connecting:
            return
        case .NotConnected:
            peers.removeValueForKey(peerID.displayName)
            channels.removeValueForKey(peerID)
            return
        }
    }

    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
        NSLog("didReceiveData: \(data.length) bytes")
        let str = NSString(data: data, encoding: NSUTF8StringEncoding) as! String
        
        if let channel = channels[peerID] {
            self.delegate?.onDataReceived(channel, data: str)
        } else {
            NSLog("Can't find channel!")
        }
    }

    func session(session: MCSession, didReceiveStream stream: NSInputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("didReceiveStream")
    }

    func session(session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, atURL localURL: NSURL, withError error: NSError?) {
        NSLog("didFinishReceivingResourceWithName")
    }

    func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress) {
        NSLog("didStartReceivingResourceWithName")
    }
}
