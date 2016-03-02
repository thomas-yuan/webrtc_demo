//
//  webrtcUtility.swift
//  webrtc_ios
//
//  Created by Topology Beijing on 3/2/16.
//  Copyright © 2016 thomas. All rights reserved.
//

import Foundation

func toString(state: RTCSignalingState)->String {
    switch(state) {
    case RTCSignalingStable: return "RTCSignalingStable"
    case RTCSignalingHaveLocalOffer: return "RTCSignalingHaveLocalOffer"
    case RTCSignalingHaveLocalPrAnswer: return "RTCSignalingHaveLocalPrAnswer"
    case RTCSignalingHaveRemoteOffer: return "RTCSignalingHaveRemoteOffer"
    case RTCSignalingHaveRemotePrAnswer: return "RTCSignalingHaveRemotePrAnswer"
    case RTCSignalingClosed: return "RTCSignalingClosed"
    default: return "unknown"
    }
}

func toString(state: RTCICEConnectionState)->String {
    switch (state) {
    case RTCICEConnectionNew: return "RTCICEConnectionNew"
    case RTCICEConnectionChecking: return "RTCICEConnectionChecking"
    case RTCICEConnectionConnected: return "RTCICEConnectionConnected"
    case RTCICEConnectionCompleted: return "RTCICEConnectionCompleted"
    case RTCICEConnectionFailed: return "RTCICEConnectionFailed"
    case RTCICEConnectionDisconnected: return "RTCICEConnectionDisconnected"
    case RTCICEConnectionClosed: return "RTCICEConnectionClosed"
    case RTCICEConnectionMax: return "RTCICEConnectionMax"
    default: return "unkown"
    }
}

func toString(state: RTCICEGatheringState)->String {
    switch (state) {
    case RTCICEGatheringNew: return "RTCICEGatheringNew"
    case RTCICEGatheringGathering: return "RTCICEGatheringGathering"
    case RTCICEGatheringComplete: return "RTCICEGatheringComplete"
    default: return "unknown"
    }
}
