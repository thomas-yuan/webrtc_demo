//
//  ViewController.swift
//  webrtc_ios
//
//  Created by thomas on 2016-02-25.
//  Copyright © 2016 thomas. All rights reserved.
//

import UIKit
import AVFoundation


class ViewController: UIViewController, RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var peerConnFactory: RTCPeerConnectionFactory = RTCPeerConnectionFactory()
    var pc: RTCPeerConnection?
    
    @IBAction func onClick(sender: UIButton) {
        let iceServer = RTCICEServer(URI: NSURL(string: "stun:207.107.152.149"), username: "testuser", password: "testuser321")
       
        pc = self.peerConnFactory.peerConnectionWithICEServers([iceServer], constraints:nil, delegate:self)
        
        let localStream = self.peerConnFactory.mediaStreamWithLabel("webrtc_demo_ios_media")
        if (localStream == nil) {
            NSLog("create local stream failed")
        }
        let audioTrack = self.peerConnFactory.audioTrackWithID("webrtc_demo_ios_audio")
        if (audioTrack == nil) {
            NSLog("No audio Track")
        }
        localStream.addAudioTrack(audioTrack)
        
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
            localStream.addVideoTrack(videoTrack)
            
        }

        let frame = view.frame
        let renderView = RTCEAGLVideoView(frame:CGRectMake(0, 0, frame.width, frame.height/2))
        localStream.videoTracks[0].addRenderer(renderView);
        view.addSubview(renderView)

        pc!.addStream(localStream)
    }
    
    
    // RTCPeerConnectionDelegate Protocol
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
        pc!.createOfferWithDelegate(self, constraints: constraints)
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
        NSLog("FIXME: We need signaling here to send candidate to peer")
        print("Local ICE candidate: \(gotICECandidate)")
    }
    
    // New data channel has been opened.
    @objc func peerConnection(peerConnection: RTCPeerConnection, didOpenDataChannel: RTCDataChannel)
    {
        NSLog("didOpenDataChannel")
    }
    
    // RTCSessionDescriptionDelegate Protocol:
    @objc func peerConnection(peerConnection: RTCPeerConnection, didCreateSessionDescription: RTCSessionDescription, error: NSError) {
        NSLog("didCreateSessionDescription")
        peerConnection.setLocalDescriptionWithDelegate(self, sessionDescription: didCreateSessionDescription)
    }
    
    @objc func peerConnection(peerConnection: RTCPeerConnection, didSetSessionDescriptionWithError: NSError)
    {
        NSLog("didSetSessionDescriptionWithError")
        // If we have a local offer OR answer we should signal it
        if (peerConnection.signalingState == RTCSignalingHaveLocalOffer || peerConnection.signalingState == RTCSignalingHaveLocalPrAnswer ) {
            // Send offer/answer through the signaling channel of our application
            NSLog("FIXME: We need signaling here to send offer to peer")
        } else if (peerConnection.signalingState == RTCSignalingHaveRemoteOffer) {
            // If we have a remote offer we should add it to the peer connection
            let constraints = RTCMediaConstraints(mandatoryConstraints: [RTCPair(key: "OfferToReceiveAudio", value: "true"), RTCPair(key: "OfferToReceiveVideo", value: "true")], optionalConstraints: [])
            peerConnection.createAnswerWithDelegate(self, constraints: constraints)
        }
    }
}


