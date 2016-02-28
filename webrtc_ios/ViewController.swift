//
//  ViewController.swift
//  webrtc_ios
//
//  Created by thomas on 2016-02-25.
//  Copyright © 2016 thomas. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // FIXME.
        signaling.discovery = self
        signaling.addDelegate(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var peerConnFactory: RTCPeerConnectionFactory = RTCPeerConnectionFactory()
    var peers = [String]()
    var channels = [String: Channel]()
    var pcs = [String: RTCPeerConnection]()
    var sdps = [RTCPeerConnection: RTCSessionDescription]()
    var localStream: RTCMediaStream?
    var signaling = SignalingService()
    let iceServer = RTCICEServer(URI: NSURL(string: "stun:207.107.152.149"), username: "testuser", password: "testuser321")

    @IBOutlet weak var discovery: UILabel!
    @IBOutlet var btn1: UIButton!
    
    @IBAction func onClick(sender: UIButton) {

        if (peers.isEmpty) {
            NSLog("No peer to connect")
            return
        }
        
        for peer in peers {
            if (channels[peer] != nil) {
                continue
            }
            
            let channel = signaling.createChannel(peer)
            if (channel == nil) {
                NSLog("Can't create signaling channel to \(peer)")
                continue
            }
        }
    }
}

// RTCPeerConnectionDelegate Protocol
extension ViewController: RTCPeerConnectionDelegate {
    
    // Triggered when the SignalingState changed.
    @objc func peerConnection(peerConnection: RTCPeerConnection, signalingStateChanged: RTCSignalingState) {
        NSLog("signalingStateChanged: \(signalingStateChanged)")
    }
    
    // Triggered when media is received on a new stream from remote peer.
    @objc func peerConnection(peerConnection: RTCPeerConnection, addedStream: RTCMediaStream) {
        NSLog("addedStream")
    }
    
    // Triggered when a remote peer close a stream.
    @objc func peerConnection(peerConnection: RTCPeerConnection, removedStream: RTCMediaStream) {
        NSLog("removedStream")
    }
    
    // Triggered when renegotiation is needed, for example the ICE has restarted.
    @objc func peerConnectionOnRenegotiationNeeded(peerConnection: RTCPeerConnection) {
        NSLog("peerConnectionOnRenegotiationNeeded")
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: [RTCPair(key: "OfferToReceiveAudio", value: "true"), RTCPair(key: "OfferToReceiveVideo", value: "true")], optionalConstraints: [])
        peerConnection.createOfferWithDelegate(self, constraints: constraints)
    }
    
    // Called any time the ICEConnectionState changes.
    @objc func peerConnection(peerConnection: RTCPeerConnection, iceConnectionChanged: RTCICEConnectionState) {
        NSLog("iceConnectionChanged: \(iceConnectionChanged)")
    }
    
    // Called any time the ICEGatheringState changes.
    @objc func peerConnection(peerConnection: RTCPeerConnection, iceGatheringChanged: RTCICEGatheringState) {
        NSLog("iceGatheringChanged: \(iceGatheringChanged)")
    }
    
    // New Ice candidate have been found.
    @objc func peerConnection(peerConnection: RTCPeerConnection, gotICECandidate: RTCICECandidate) {
        NSLog("gotICECandidate")
        //NSLog("FIXME: We need signaling here to send candidate to peer")
        print("Local ICE candidate: \(gotICECandidate)")
        for (peer, pc) in pcs {
            if pc == peerConnection {
                NSLog("send candidate to peer")
                if let channel = channels[peer] {
                    channel.sendData("\(gotICECandidate)")
                } else {
                    NSLog("Can't find channel to send candidate!")
                }
                break;
            }
        }
    }
    
    // New data channel has been opened.
    @objc func peerConnection(peerConnection: RTCPeerConnection, didOpenDataChannel: RTCDataChannel)
    {
        NSLog("didOpenDataChannel")
    }
}

// RTCSessionDescriptionDelegate Protocol:
extension ViewController: RTCSessionDescriptionDelegate {

    @objc func peerConnection(peerConnection: RTCPeerConnection, didCreateSessionDescription: RTCSessionDescription, error: NSError) {
        NSLog("didCreateSessionDescription")
        peerConnection.setLocalDescriptionWithDelegate(self, sessionDescription: didCreateSessionDescription)
        sdps[peerConnection] = didCreateSessionDescription
    }
    
    @objc func peerConnection(peerConnection: RTCPeerConnection, didSetSessionDescriptionWithError: NSError)
    {
        NSLog("didSetSessionDescriptionWithError")
        // If we have a local offer OR answer we should signal it
        if (peerConnection.signalingState == RTCSignalingHaveLocalOffer || peerConnection.signalingState == RTCSignalingHaveLocalPrAnswer ) {
            // Send offer/answer through the signaling channel of our application
            NSLog("Send offer")
            if let sdp = sdps[peerConnection] {
                NSLog("FIXME: We need signaling here to send offer to peer")
                for (peer, pc) in pcs {
                    if pc == peerConnection {
                        NSLog("send offer to peer")
                        if let channel = channels[peer] {
                            channel.sendData("\(sdp)")
                        } else {
                            NSLog("Can't find channel to send sdp!")
                        }
                        break;
                    }
                }
            }
        } else {
            // If we have a remote offer we should add it to the peer connection
            NSLog("create answer")
            let constraints = RTCMediaConstraints(mandatoryConstraints: [RTCPair(key: "OfferToReceiveAudio", value: "true"), RTCPair(key: "OfferToReceiveVideo", value: "true")], optionalConstraints: [])
            peerConnection.createAnswerWithDelegate(self, constraints: constraints)
        }
    }
}

extension ViewController: SignalingServiceDelegate {
    func createSession(peer: String) {
        pcs[peer] = self.peerConnFactory.peerConnectionWithICEServers([iceServer], constraints:nil, delegate:self)
        
        if (localStream == nil) {
            // create localstream
            localStream = self.peerConnFactory.mediaStreamWithLabel("webrtc_demo_ios_media")
            let audioTrack = self.peerConnFactory.audioTrackWithID("webrtc_demo_ios_audio")
            localStream!.addAudioTrack(audioTrack)
            
            let videoDevices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
            var captureDevice:AVCaptureDevice?
            
            for device in videoDevices{
                let device = device as! AVCaptureDevice
                if device.position == AVCaptureDevicePosition.Front {
                    captureDevice = device
                    break
                }
            }
            
            // Create a video track and add it to the media stream
            if (captureDevice != nil) {
                let capturer = RTCVideoCapturer(deviceName: captureDevice!.localizedName)
                let videoSource = self.peerConnFactory.videoSourceWithCapturer(capturer, constraints:nil);
                let videoTrack = self.peerConnFactory.videoTrackWithID("webrtc_demo_ios_vedio", source:videoSource)
                localStream!.addVideoTrack(videoTrack)
            }
            
            let frame = view.frame
            let renderView = RTCEAGLVideoView(frame:CGRectMake(0, 0, frame.width, frame.height/2))
            localStream!.videoTracks[0].addRenderer(renderView);
            view.addSubview(renderView)
        }
        pcs[peer]!.addStream(localStream)
    }
    
    func onChannelChanged(channel: Channel, status: String) {
        NSLog("onChannelChanged: \(status)")
        
        switch (status) {
        case "created":
            channels[channel.peer.displayName] = channel
            dispatch_async(dispatch_get_main_queue(), {
                self.createSession(channel.peer.displayName)
            })
            break
            
            // outbound
        case "received":
            channels[channel.peer.displayName] = channel
            break
        
        case "closed": break
            
        default: break
            
        }
        
    }
    
    func onDataReceived(channel: Channel, data: String) {
        NSLog("onDataReceived: \(data)")
        if channel.status == "received" {
            NSLog("first message, should be session offer")
            channel.status = "established"
            dispatch_async(dispatch_get_main_queue(), {
                let peer = channel.peer.displayName
                self.pcs[peer] = self.peerConnFactory.peerConnectionWithICEServers([self.iceServer], constraints:nil, delegate:self)
                
                if (self.localStream == nil) {
                    // create localstream
                    self.localStream = self.peerConnFactory.mediaStreamWithLabel("webrtc_demo_ios_media")
                    let audioTrack = self.peerConnFactory.audioTrackWithID("webrtc_demo_ios_audio")
                    self.localStream!.addAudioTrack(audioTrack)
                    
                    let videoDevices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
                    var captureDevice:AVCaptureDevice?
                    
                    for device in videoDevices{
                        let device = device as! AVCaptureDevice
                        if device.position == AVCaptureDevicePosition.Front {
                            captureDevice = device
                            break
                        }
                    }
                    
                    // Create a video track and add it to the media stream
                    if (captureDevice != nil) {
                        let capturer = RTCVideoCapturer(deviceName: captureDevice!.localizedName)
                        let videoSource = self.peerConnFactory.videoSourceWithCapturer(capturer, constraints:nil);
                        let videoTrack = self.peerConnFactory.videoTrackWithID("webrtc_demo_ios_vedio", source:videoSource)
                        self.localStream!.addVideoTrack(videoTrack)
                    }
                    
                    let frame = self.view.frame
                    let renderView = RTCEAGLVideoView(frame:CGRectMake(0, 0, frame.width, frame.height/2))
                    self.localStream!.videoTracks[0].addRenderer(renderView);
                    self.view.addSubview(renderView)
                }
                //self.pcs[peer]!.addStream(self.localStream)
                self.pcs[peer]!.setRemoteDescriptionWithDelegate(self, sessionDescription: RTCSessionDescription(type: "Offer", sdp: data))
                
            })
        } else {
            // candidate
            dispatch_async(dispatch_get_main_queue(), {
                if let s = self.pcs[channel.peer.displayName] {
                    s.addICECandidate(RTCICECandidate(mid: "SDP", index: 1, sdp: data))
                }
            })
        }

    }
    
    func name() -> String {
        return "VideoCall"
    }

}

extension ViewController: DiscoveryServiceDelegate {
    func onPeerChanged(peers: [String]) {
        NSLog("onPeerChanged: \(peers)")
        self.peers = peers
        self.discovery.text = "Dsicovery: \(peers)"
    }
}

