//
//  NetworkReachabilityManager.swift
//  DiduNet
//
//  Created by xzx on 2021/5/31.
//  Copyright © 2021 didu.top. All rights reserved.
//

import Foundation
import Reachability

public final class NetworkReachabilityManager {
    
    public static let shared = NetworkReachabilityManager()
    public private(set) var reachability: Reachability?
    public private(set) var currentState: NetworkState = .connect
    
    public static let networkReachabilityChanged = Notification.Name("networkReachabilityChanged")
    
    public enum NetworkState {
        case connect
        case noNetwork
    }
    
    deinit {
        reachability?.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: nil)
    }
    
    private init() {
        reachability = try! Reachability()
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityStateChange(_:)), name: .reachabilityChanged, object: reachability)
        try? reachability?.startNotifier()
    }
    
    @objc public func reachabilityStateChange(_ notify: Notification) {
        let reachability = notify.object as! Reachability
        switch reachability.connection {
        case .wifi, .cellular:
            if self.currentState != .connect {
                self.currentState = .connect
                NotificationCenter.default.post(name: NetworkReachabilityManager.networkReachabilityChanged, object: self.currentState)
            }
        case .unavailable, .none:
            if self.currentState != .noNetwork {
                self.currentState = .noNetwork
                NotificationCenter.default.post(name: NetworkReachabilityManager.networkReachabilityChanged, object: self.currentState)
            }
        }
    }
    
}
