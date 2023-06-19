//
//  NetworkCache.swift
//  DiduNet
//
//  Created by matt on 2021/3/22.
//  Copyright © 2021 didu.top. All rights reserved.
//

import Foundation
import DiduFoundation

/// 网络请求数据缓存操作
public protocol NetworkCacheAction {
    
    
    /// 保存接口数据
    /// - Parameters:
    ///   - data: 数据内容
    ///   - key: 文件名
    func save(data: Data, for key: String)
    
    
    /// 读取缓存的数据
    /// - Parameters:
    ///   - key: 文件名
    ///   - completion: 完成读取或者遇到错误的回调
    func readCache(by key: String, completion: @escaping (KFResult<Data>) -> Void)
}

public final class NetworkCache {
    
    let requestDir = "request"
    
    var cachePath: String? {
        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        return path.first
    }
}

extension NetworkCache: NetworkCacheAction {
    
    
    public func save(data: Data, for key: String) {
        if let cachePath = cachePath {
            let targetDir = cachePath + "/" + requestDir
            
//            if !FileManager.default.fileExists(atPath: targetDir) {
//                do {
//                    try FileManager.default.createDirectory(atPath: targetDir, withIntermediateDirectories: false, attributes: nil)
//                } catch {
//                    logError("\(#function) -- \(error)")
//                    return
//                }
//            }
            let fileUrl = URL(fileURLWithPath: targetDir + "/" + key)
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try data.write(to: fileUrl)
                } catch {
                    logError("\(#function) -- \(error)")
                }
            }
        }
    }
    
    public func readCache(by key: String, completion: @escaping (KFResult<Data>) -> Void) {
        if let cachePath = cachePath {
            let filePath = cachePath + "/" + requestDir + "/" + key
            let fileUrl = URL(fileURLWithPath: filePath)
            if FileManager.default.fileExists(atPath: filePath) {
                completion(.failure(KFError(code: .status(.clientError), message: "缓存文件不存在")))
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try Data(contentsOf: fileUrl)
                    DispatchQueue.main.async {
                        completion(.success(data))
                    }
                } catch {
//                    logError("\(#function) -- \(error)")
                    completion(.failure(KFError(code: .status(.clientError), message: "读取缓存失败")))
                }
            }
        } else {
            completion(.failure(KFError(code: .status(.clientError), message: "获取缓存路径失败")))
        }
        
    }
    
    
}
