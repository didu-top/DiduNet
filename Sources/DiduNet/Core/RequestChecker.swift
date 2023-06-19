//
//  RequestChecker.swift.swift
//  DiduNet
//
//  Created by zenzz on 2021/12/31.
//

import Foundation
import Moya
import CommonCrypto

fileprivate extension Data {
    var md5: String {
        let arr: [UInt8] = self.map({ return $0 })
        
        var uint8Array = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        
        CC_MD5(arr, CC_LONG(arr.count - 1), &uint8Array)
        
        return uint8Array.reduce("") { $0 + String(format: "%02x", $1)}
    }
}

fileprivate extension String {
    var md5: String {
        
        let ccharArray = self.cString(using: String.Encoding.utf8)
        
        var uint8Array = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        
        CC_MD5(ccharArray, CC_LONG(ccharArray!.count - 1), &uint8Array)
        
        return uint8Array.reduce("") { $0 + String(format: "%02x", $1)}
    }
    
    func concat(_ apppend: String?, sep: String) -> String {
        if let app = apppend, !app.isEmpty {
            return self.appending(sep).appending(app)
        }
        return self
    }
}

fileprivate extension CachableTarget {
    
    var identifier: String {
        let sep = "-|-sep-|-"
        let baseMd5 = (self.method.rawValue + sep + self.fullPath).md5
        switch self.task {
        case .requestPlain:
            break
        case .requestData(let data):
            return baseMd5 + sep + data.md5
        case .requestParameters(parameters: let param, encoding: _):
            if let data = (try? JSONSerialization.data(withJSONObject: param, options: .init())) {
                return baseMd5 + sep + data.md5
            }
            return baseMd5
        case .requestCompositeParameters(bodyParameters: let param, bodyEncoding: _, urlParameters: let urlParam):
            let bodyMd5 = (try? JSONSerialization.data(withJSONObject: param, options: .init()))?.md5
            let urlParamMd5 = (try? JSONSerialization.data(withJSONObject: urlParam, options: .init()))?.md5
            return baseMd5.concat(urlParamMd5, sep: sep).concat(bodyMd5, sep: sep)
        case .requestCompositeData(bodyData: let data, urlParameters: let urlParam):
            let bodyMd5 = data.md5
            let urlParamMd5 = (try? JSONSerialization.data(withJSONObject: urlParam, options: .init()))?.md5
            return baseMd5.concat(urlParamMd5, sep: sep).concat(bodyMd5, sep: sep)
        default:
            break
        }
        return baseMd5
    }
}


/// 重复请求检查器
/// 检查一定时间内是否存在相同的请求
/// 
class RepeatRequestChecker {
    
    /// 缓存一定时间内发起的且未获取到结果的请求
//    var cacheRequestMap: [String: (Int64, CachableTarget)] = [:]

    let cacheRequestMap: NSMutableDictionary = [:]
    
    /// 判断相同请求时间间隔(ms)
    var forbidSameRequestInterval: Int64 = 300
    
//    private var lock = pthread_rwlock_t()
//    private var lock = NSRecursiveLock()
    
    private var timer: DispatchSourceTimer?
    
    private func addToCache(key: String, currentTime: Int64, api: CachableTarget) {
//        pthread_rwlock_trywrlock(&lock)
        cacheRequestMap[key] = (currentTime, api)
//        pthread_rwlock_unlock(&lock)
        
        print("add  \(currentTime) -- \(api)")
        
        if cacheRequestMap.count != 0 {
            if timer == nil {
                DispatchQueue.main.async { [weak self] in
                    self?.timer = DispatchSource.makeTimerSource()
                    self?.timer?.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1))
                    self?.timer?.setEventHandler(handler: {
                        [weak self] in
                        self?.autoRemoveItemOfOverInterval()
                    })
                    self?.timer?.activate()
                }
            }
        }
    }
    
    private func autoRemoveItemOfOverInterval() {
        for key in cacheRequestMap.allKeys {
//            pthread_rwlock_tryrdlock(&lock)
            let val = cacheRequestMap[key] as? (Int64, CachableTarget)
//            pthread_rwlock_unlock(&lock)
            
            if let tup = val, tup.0 > forbidSameRequestInterval {
                self.removeFromCache(key: key)
            }
        }
    }
    
    private func removeFromCache(key: Any) {
//        pthread_rwlock_trywrlock(&lock)
        cacheRequestMap.removeObject(forKey: key)
//        pthread_rwlock_unlock(&lock)
        
        print("remove \(Int64(Date().timeIntervalSince1970 * 1000)) ||  \(key) -")
        
        if cacheRequestMap.count == 0 {
            DispatchQueue.main.async { [weak self] in
                self?.timer?.cancel()
                self?.timer = nil
            }
            
        }
    }
    
    /// 在发送请求之前, 检查请求是否可以发送请求
    func beforeSendRequest(api: CachableTarget) -> Bool {
        // 如果该api豁免检查,则返回true,允许发出请求
        if api.remitRepeatCheck {
            return true
        }
        
        let key = api.identifier
        
        let now = Int64(Date().timeIntervalSince1970 * 1000)
//        pthread_rwlock_tryrdlock(&lock)
        let val = cacheRequestMap[key] as? (Int64, CachableTarget)
//        pthread_rwlock_unlock(&lock)
        
        if let item = val {
            if now - item.0 <= forbidSameRequestInterval {
                return false
            }
        }
        addToCache(key: key, currentTime: now, api: api)
        return true
    }
}
