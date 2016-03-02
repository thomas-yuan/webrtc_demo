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
    var remoteStream: RTCMediaStream?
    var signaling = SignalingService()
    let iceServer = RTCICEServer(URI: NSURL(string: "stun:207.107.152.149"), username: "testuser", password: "testuser321")
    var localView: RTCEAGLVideoView? = nil
    var remoteView: RTCEAGLVideoView? = nil
    var candidates = String()

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
        let state = toString(signalingStateChanged)
        NSLog("signalingStateChanged: \(state)")
    }
    
    // Triggered when media is received on a new stream from remote peer.
    @objc func peerConnection(peerConnection: RTCPeerConnection, addedStream: RTCMediaStream) {
        NSLog("addedStream")
        for track in addedStream.videoTracks {
            NSLog("video track is: \(track)")
        }
        remoteStream = addedStream
        dispatch_async(dispatch_get_main_queue(), {
            addedStream.videoTracks[0].addRenderer(self.remoteView);
        })
    }

    // Triggered when a remote peer close a stream.
    @objc func peerConnection(peerConnection: RTCPeerConnection, removedStream: RTCMediaStream) {
        NSLog("removedStream")
    }
    
    // Triggered when renegotiation is needed, for example the ICE has restarted.
    @objc func peerConnectionOnRenegotiationNeeded(peerConnection: RTCPeerConnection) {
        NSLog("peerConnectionOnRenegotiationNeeded")
    }
    
    // Called any time the ICEConnectionState changes.
    @objc func peerConnection(peerConnection: RTCPeerConnection, iceConnectionChanged: RTCICEConnectionState) {
        let state = toString(iceConnectionChanged)
        NSLog("iceConnectionChanged: \(state)")
    }
    
    // Called any time the ICEGatheringState changes.
    @objc func peerConnection(peerConnection: RTCPeerConnection, iceGatheringChanged: RTCICEGatheringState) {
        let state = toString(iceGatheringChanged)
        NSLog("iceGatheringChanged: \(state)")
        if iceGatheringChanged == RTCICEGatheringComplete {
            for (peer, pc) in pcs {
                if pc == peerConnection {
                    NSLog("send candidate to peer \(peer)")
                    if let channel = channels[peer] {
                        channel.sendData(candidates)
                    } else {
                        NSLog("Can't find channel to send candidate!")
                    }
                    break;
                }
            }
        }
    }
    
    // New Ice candidate have been found.
    @objc func peerConnection(peerConnection: RTCPeerConnection, gotICECandidate: RTCICECandidate) {
        NSLog("gotICECandidate:")
        NSLog("spdMid: \(gotICECandidate.sdpMid)")
        NSLog("sdpMLineIndex: \(gotICECandidate.sdpMLineIndex)")
        NSLog("sdp: \(gotICECandidate.sdp)")

        if candidates.isEmpty {
            candidates = "\(gotICECandidate)"
        } else {
            candidates += "|\(gotICECandidate)"
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
        NSLog("didCreateSessionDescription for \(peerConnection)")
        NSLog("type: \(didCreateSessionDescription.type)")
        NSLog("sdp: \(didCreateSessionDescription.description)")
        self.sdps[peerConnection] = didCreateSessionDescription
        dispatch_async(dispatch_get_main_queue(), {
            peerConnection.setLocalDescriptionWithDelegate(self, sessionDescription: didCreateSessionDescription)
        })

        // This will be called when we create offer/answer.
        // We need to send offer/answer here
        for (peer, pc) in self.pcs {
            if pc == peerConnection {
                NSLog("send \(didCreateSessionDescription.type) to peer \(peer)")
                if let channel = channels[peer] {
                    channel.sendData("\(didCreateSessionDescription)")
                } else {
                    NSLog("Can't find channel to send sdp!")
                }
                break;
            }
        }
    }
    
    @objc func peerConnection(peerConnection: RTCPeerConnection, didSetSessionDescriptionWithError: NSError)
    {
        let signalingState = toString(peerConnection.signalingState)
        NSLog("didSetSessionDescriptionWithError for peer \(peerConnection),  \(didSetSessionDescriptionWithError.localizedFailureReason), signaling status: \(signalingState)")
 
        if (peerConnection.signalingState == RTCSignalingHaveRemoteOffer){
            // If we have a remote offer we should add it to the peer connection
            NSLog("create answer")
            let constraints = RTCMediaConstraints()
            peerConnection.createAnswerWithDelegate(self, constraints: constraints)
        }
    }
}

extension ViewController: SignalingServiceDelegate {
    func createSession(peer: String, withOffer: Bool) {
        let constraints = RTCMediaConstraints(mandatoryConstraints:
                [RTCPair(key: "OfferToReceiveAudio", value: "true"), RTCPair(key: "OfferToReceiveVideo", value: "true")],
                optionalConstraints: [])
        let peerConnection = self.peerConnFactory.peerConnectionWithICEServers([iceServer], constraints:constraints, delegate:self)
        pcs[peer] = peerConnection

        if (localStream == nil) {
            // create localstream
            localStream = self.peerConnFactory.mediaStreamWithLabel("media")
            let audioTrack = self.peerConnFactory.audioTrackWithID("audio")
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
                let videoTrack = self.peerConnFactory.videoTrackWithID("vedio", source:videoSource)
                localStream!.addVideoTrack(videoTrack)
            }

            let frame = view.frame
            if (localView == nil) {
                localView = RTCEAGLVideoView(frame:CGRectMake(0, 0, frame.width, frame.height/2))
            }
            if (remoteView == nil) {
                remoteView = RTCEAGLVideoView(frame:CGRectMake(0, frame.height/2, frame.width, frame.height/2))
            }
            localStream!.videoTracks[0].addRenderer(localView)
            view.addSubview(localView!)
            view.addSubview(remoteView!)
        }
        peerConnection.addStream(localStream)
        NSLog("Create Peer Connection and add mediastream")

        if (withOffer) {
            NSLog("Start to Create Offer...")
            peerConnection.createOfferWithDelegate(self, constraints: constraints)
        }
    }
    
    func onChannelChanged(channel: Channel, status: String) {
        NSLog("onChannelChanged: \(status)")
        
        switch (status) {
        case "created":
            channels[channel.peer.displayName] = channel
            dispatch_async(dispatch_get_main_queue(), {
                NSLog("outbound channel. create session with offer")
                self.createSession(channel.peer.displayName, withOffer: true)
            })
            break
            
        case "received":
            channels[channel.peer.displayName] = channel
            dispatch_async(dispatch_get_main_queue(), {
                NSLog("inbound channel, create session, will create answer when receive remote offer")
                self.createSession(channel.peer.displayName, withOffer: false)
            })
            break;
            
        case "closed": break
            
        default: break
            
        }
        
    }
    
    func onDataReceived(channel: Channel, data: String) {
        NSLog("onDataReceived: \(data)")
//        assert(pcs[channel.peer.displayName] != nil)
        
        if channel.status == "received" {
            NSLog("first message, should be session offer")
            channel.status = "established"
            dispatch_async(dispatch_get_main_queue(), {
                NSLog("add remote sdp as offer")
                self.pcs[channel.peer.displayName]?.setRemoteDescriptionWithDelegate(self, sessionDescription: RTCSessionDescription(type: "offer", sdp: data))
            })
        } else if channel.status == "created" {
            NSLog("first message for sender, should be session answer")
            channel.status = "established"
            dispatch_async(dispatch_get_main_queue(), {
                NSLog("add remote sdp as answer")
                self.pcs[channel.peer.displayName]?.setRemoteDescriptionWithDelegate(self, sessionDescription: RTCSessionDescription(type: "answer", sdp: data))
            })
            
        } else {
            // candidate
            
            dispatch_async(dispatch_get_main_queue(), {
                if let s = self.pcs[channel.peer.displayName] {
                    NSLog("received condidate for \(s)")
                    let candidates = data.componentsSeparatedByString("|")
                    for candidate in candidates {
                        var parts = candidate.componentsSeparatedByString(":")
                        if parts.count == 4 {
                            NSLog("spdMid: \(parts[0])")
                            NSLog("sdpMLineIndex: \(parts[1])")
                            NSLog("sdp: \(parts[2]):\(parts[3])")
                            s.addICECandidate(RTCICECandidate(mid: parts[0], index: Int(parts[1])! , sdp: parts[2] + ":" + parts[3]))
                        } else {
                        NSLog("Can't convert candidate!!")
                        }
                    }
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

