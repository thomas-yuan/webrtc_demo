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
    
    init(session: MCSession, peer: MCPeerID) {
        self.session = session
        self.peer = peer
    }
    
    func sendData(data : String) -> Bool {
        NSLog("%@", "sendData: \(data)")
        
        if session.connectedPeers.contains(peer) {
            do {
                try self.session.sendData(data.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!, toPeers: [peer], withMode: MCSessionSendDataMode.Reliable)
                return true
            } catch let error as NSError {
                NSLog("%@", "\(error)")
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

protocol SignalingServiceDelegate {
    
//    func connectedDevicesChanged(manager : SignalingService, connectedDevices: [String])
//    func colorChanged(manager : SignalingService, colorString: String)
    func onChannelChanged(channel: Channel, status: String)
    func onDataReceived(channel: Channel, data: String)
    func name() -> String
}

class SignalingService : NSObject {
    
    private let ServiceType = "tplgy_signaling"
    private let myPeerId = MCPeerID(displayName: UIDevice.currentDevice().name)
    private let serviceAdvertiser : MCNearbyServiceAdvertiser
    private let serviceBrowser : MCNearbyServiceBrowser
    
    var peers = [String: MCPeerID]()
    var channels = [MCPeerID: Channel]()
    
    var delegate : SignalingServiceDelegate?
    
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

    func createChannel(peerID: MCPeerID) {
        NSLog("invitePeer: \(peerID)")
        serviceBrowser.invitePeer(peerID, toSession: self.session, withContext: nil, timeout: 10)
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
    
    
    func browser(browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: NSError) {
        NSLog("didNotStartBrowsingForPeers: \(error)")
    }
    
    func browser(browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("foundPeer: \(peerID)")
        peers[peerID.displayName] = peerID
    }
    
    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("lostPeer: \(peerID)")
    }
    
}

extension MCSessionState {
    
    func stringValue() -> String {
        switch(self) {
        case .NotConnected: return "NotConnected"
        case .Connecting: return "Connecting"
        case .Connected: return "Connected"
        default: return "Unknown"
        }
    }
    
}

extension SignalingService : MCSessionDelegate {
    
    func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        NSLog("peer \(peerID) didChangeState: \(state.stringValue())")
        
        switch (state) {
        case .Connected:
            let channel = Channel(session: session, peer: peerID)
            channels[peerID] = channel
            self.delegate?.onChannelChanged(channel, status: "created")
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
            // outbound channel?
            self.delegate?.onDataReceived(channel, data: str)
        } else {
            let newChannel = Channel(session: session, peer: peerID)
            channels[peerID] = newChannel
            self.delegate?.onChannelChanged(newChannel, status: "received")
            self.delegate?.onDataReceived(newChannel, data: str)
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
