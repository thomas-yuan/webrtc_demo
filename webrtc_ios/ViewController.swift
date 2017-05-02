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
        // FIXME.
        signaling.discovery = self
        signaling.addDelegate(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    var peerConnFactory: RTCPeerConnectionFactory = RTCPeerConnectionFactory()
    var peers = [String]()
    var channels = [String: Channel]()
    var pcs = [String: RTCPeerConnection]()
    var sdps = [RTCPeerConnection: RTCSessionDescription]()
    var localStream: RTCMediaStream?
    var remoteStream: RTCMediaStream?
    var signaling = SignalingService()
    let iceServer = RTCICEServer(uri: URL(string: "stun:207.107.152.149"), username: "testuser", password: "testuser321")
    var localView: RTCEAGLVideoView? = nil
    var remoteView: RTCEAGLVideoView? = nil

    @IBOutlet weak var discovery: UILabel!
    @IBOutlet var btn1: UIButton!
    @IBAction func onClick(_ sender: UIButton) {
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

extension ViewController: RTCPeerConnectionDelegate {

    // Triggered when the SignalingState changed.
    @objc func peerConnection(_ peerConnection: RTCPeerConnection, signalingStateChanged: RTCSignalingState) {
        let state = toString(signalingStateChanged)
        NSLog("signalingStateChanged: \(state)")
    }

    // Triggered when media is received on a new stream from remote peer.
    @objc func peerConnection(_ peerConnection: RTCPeerConnection, addedStream: RTCMediaStream) {
        NSLog("addedStream \(addedStream)")
        remoteStream = addedStream
        DispatchQueue.main.async(execute: {
            (addedStream.videoTracks[0] as AnyObject).add(self.remoteView);
        })
    }

    // Triggered when a remote peer close a stream.
    @objc func peerConnection(_ peerConnection: RTCPeerConnection, removedStream: RTCMediaStream) {
        NSLog("removedStream \(removedStream)")
    }

    // Triggered when renegotiation is needed, for example the ICE has restarted.
    @objc func peerConnection(onRenegotiationNeeded peerConnection: RTCPeerConnection) {
        NSLog("peerConnectionOnRenegotiationNeeded \(peerConnection)")
    }

    // Called any time the ICEConnectionState changes.
    @objc func peerConnection(_ peerConnection: RTCPeerConnection, iceConnectionChanged: RTCICEConnectionState) {
        let state = toString(iceConnectionChanged)
        NSLog("iceConnectionChanged: \(state)")
    }

    // Called any time the ICEGatheringState changes.
    @objc func peerConnection(_ peerConnection: RTCPeerConnection, iceGatheringChanged: RTCICEGatheringState) {
        let state = toString(iceGatheringChanged)
        NSLog("iceGatheringChanged: \(state)")
    }

    // New Ice candidate have been found.
    @objc func peerConnection(_ peerConnection: RTCPeerConnection, gotICECandidate: RTCICECandidate) {
        NSLog("gotICECandidate:")
        NSLog("spdMid: \(gotICECandidate.sdpMid)")
        NSLog("sdpMLineIndex: \(gotICECandidate.sdpMLineIndex)")
        NSLog("sdp: \(gotICECandidate.sdp)")

        for (peer, pc) in pcs {
            if pc == peerConnection {
                NSLog("send candidate to peer \(peer)")
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
    @objc func peerConnection(_ peerConnection: RTCPeerConnection, didOpen didOpenDataChannel: RTCDataChannel) {
        NSLog("didOpenDataChannel")
    }
}

extension ViewController: RTCSessionDescriptionDelegate {

    // Called when creating a session.
    @objc func peerConnection(_ peerConnection: RTCPeerConnection, didCreateSessionDescription: RTCSessionDescription, error: Error) {
        NSLog("didCreateSessionDescription for \(peerConnection)")
        NSLog("type: \(didCreateSessionDescription.type)")
        NSLog("sdp: \(didCreateSessionDescription.description)")

        self.sdps[peerConnection] = didCreateSessionDescription
        DispatchQueue.main.async(execute: {
            peerConnection.setLocalDescriptionWith(self, sessionDescription: didCreateSessionDescription)
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
    // Called when setting a local or remote description.

    @objc func peerConnection(_ peerConnection: RTCPeerConnection, didSetSessionDescriptionWithError: Error)
    {
        let signalingState = toString(peerConnection.signalingState)
//        NSLog("didSetSessionDescriptionWithError for peer \(peerConnection), error: \(didSetSessionDescriptionWithError.localizedFailureReason), signaling status: \(signalingState)")

        if (peerConnection.signalingState == RTCSignalingHaveRemoteOffer){
            NSLog("create answer")
            peerConnection.createAnswer(with: self, constraints: RTCMediaConstraints())
        }
    }
}

extension ViewController: SignalingServiceDelegate {

    func createSession(_ peer: String, withOffer: Bool) {
        let constraints = RTCMediaConstraints(mandatoryConstraints: [RTCPair(key: "OfferToReceiveAudio", value: "true"), RTCPair(key: "OfferToReceiveVideo", value: "true")], optionalConstraints: [])
        let peerConnection = self.peerConnFactory.peerConnection(withICEServers: [iceServer!], constraints:constraints, delegate:self)
        pcs[peer] = peerConnection

        if (localStream == nil) {
            localStream = self.peerConnFactory.mediaStream(withLabel: "media")
            let audioTrack = self.peerConnFactory.audioTrack(withID: "audio")
            localStream!.addAudioTrack(audioTrack)

            let videoDevices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
            var captureDevice:AVCaptureDevice?

            for device in videoDevices!{
                let device = device as! AVCaptureDevice
                if device.position == AVCaptureDevicePosition.front {
                    captureDevice = device
                    break
                }
            }

            if (captureDevice != nil) {
                let capturer = RTCVideoCapturer(deviceName: captureDevice!.localizedName)
                let videoSource = self.peerConnFactory.videoSource(with: capturer, constraints:nil);
                let videoTrack = self.peerConnFactory.videoTrack(withID: "vedio", source:videoSource)
                localStream!.addVideoTrack(videoTrack)
            }

            let frame = view.frame
            if (localView == nil) {
                localView = RTCEAGLVideoView(frame:CGRect(x: 0, y: 0, width: frame.width, height: frame.height/2))
            }
            if (remoteView == nil) {
                remoteView = RTCEAGLVideoView(frame:CGRect(x: 0, y: frame.height/2, width: frame.width, height: frame.height/2))
            }

            (localStream!.videoTracks[0] as AnyObject).add(localView)
            view.addSubview(localView!)
            view.addSubview(remoteView!)
        }

        peerConnection?.add(localStream)
        NSLog("Create Peer Connection and add mediastream")

        if (withOffer) {
            NSLog("Start to Create Offer...")
            peerConnection?.createOffer(with: self, constraints: constraints)
        }
    }

    func onChannelChanged(_ channel: Channel, status: String) {
        NSLog("onChannelChanged: \(status)")

        // FIXME. channel status should be simple.
        switch (status) {
            case "created":
                channels[channel.peer.displayName] = channel
                DispatchQueue.main.async(execute: {
                    NSLog("outbound channel. create session with offer")
                    self.createSession(channel.peer.displayName, withOffer: true)
                })
                break

            case "received":
                channels[channel.peer.displayName] = channel
                DispatchQueue.main.async(execute: {
                    NSLog("inbound channel, create session, will create answer when receive remote offer")
                    self.createSession(channel.peer.displayName, withOffer: false)
                })
                break;

            case "closed": break
            default: break
        }
    }

    func onDataReceived(_ channel: Channel, data: String) {
        NSLog("onDataReceived: \(data)")

        // FIXME. message type should be part of data.
        switch (channel.status) {
            case "received":
                NSLog("first message, should be session offer")
                channel.status = "established"
                DispatchQueue.main.async(execute: {
                    NSLog("add remote sdp as offer")
                    self.pcs[channel.peer.displayName]?.setRemoteDescriptionWith(self, sessionDescription: RTCSessionDescription(type: "offer", sdp: data))
                })
                break;

            case "created":
                NSLog("first message for sender, should be session answer")
                channel.status = "established"
                DispatchQueue.main.async(execute: {
                    NSLog("add remote sdp as answer")
                    self.pcs[channel.peer.displayName]?.setRemoteDescriptionWith(self, sessionDescription: RTCSessionDescription(type: "answer", sdp: data))
                })
                break;

            default:
                DispatchQueue.main.async(execute: {
                    if let s = self.pcs[channel.peer.displayName] {
                        NSLog("received condidate for \(s)")
                        var parts = data.components(separatedBy: ":")
                        if parts.count == 4 {
                            NSLog("spdMid: \(parts[0])")
                            NSLog("sdpMLineIndex: \(parts[1])")
                            NSLog("sdp: \(parts[2]):\(parts[3])")
                            s.add(RTCICECandidate(mid: parts[0], index: Int(parts[1])! , sdp: parts[2] + ":" + parts[3]))
                        } else {
                            NSLog("Can't convert message to candidate!!")
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

    func onPeerChanged(_ peers: [String]) {
        NSLog("onPeerChanged: \(peers)")
        self.peers = peers
        self.discovery.text = "Dsicovery: \(peers)"
    }
}

