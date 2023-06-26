//
//  CachableTarget.swift
//  DiduNet
//
//  Created by matt on 2021/3/19.
//  Copyright © 2021 didu.top. All rights reserved.
//

import Foundation
@_exported import Moya


/// 扩展Moya 接口API协议，提供接口缓存能力
public protocol CachableTarget: TargetType {
    
    /// 使用URLRequest缓存策略
    var cachePolicy: URLRequest.CachePolicy? { get }
    
    /// 请求超时
    var timeout: Double? { get }
    
    /// 是否豁免重复请求判断策略, 默认不豁免
    var remitRepeatCheck: Bool { get }
}

public extension CachableTarget {
    
    var cachePolicy: URLRequest.CachePolicy? {
        return nil
    }
    
    var timeout: Double? {
        return nil
    }
    
    var remitRepeatCheck: Bool {
        return false
    }
    
    /// 清除接口缓存
    func cleanCache() {
        URLCache.shared.removeAllCachedResponses()
    }
    
    /// 请求完整路径
    var fullPath: String {
        let url = MoyaProvider.defaultEndpointMapping(for: self).url
        return url
    }
}
