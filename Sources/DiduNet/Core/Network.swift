//
//  Network.swift
//  DiduNet
//
//  Created by Matt on 2021/3/3.
//  Copyright © 2021 didu.top. All rights reserved.
//

import Foundation
@_exported import Moya
@_exported import Alamofire
@_exported import Reachability
import DiduFoundation

public typealias Callback<T> = (KFResult<T>) -> Void


internal let logger = Logger(lowerLevel: .verbose, prefixMap: [
    .verbose: "􀤆􀤆 - 🗒 => ",
    .warn: "􀤆􀤆 - ⚠️ => ",
    .error: "􀤆􀤆 - ❌ => "
])


// MARK: - 网络请求（返回原始数据）
public struct Network {
    
    /// 全局处理网络请求错误
    /// 返回值确定是否继续执行block回调
    public static var globalCactchNetworkError: ((TargetType, KFError, (() -> Void)?) -> Void)?
    
    /// 处理接口缓存
    private static let cacheWorker = NetworkCache()
    
    /// 是否全局启用日志
    public static var isEnableLog = false
    
    /// 是否开启重复网络请求检查
    public static var isEnableRepeatRequestCheck = true
    
    /// 默认请求超时
    public static var defaultTimeOut: Double = 30
    
    /// 判断相同请求时间间隔
    public static var forbidSameRequestInterval: Int64 = 300 {
        didSet {
            requestChecker.forbidSameRequestInterval = forbidSameRequestInterval
        }
    }
    
    /// 重复请求校验
    static var requestChecker: RepeatRequestChecker = RepeatRequestChecker()
    
    /// 网络联通测试主机地址
    public static var reachableTestHost = "https://www.kfang.com"
    
    private init() {}
    
    fileprivate static var session: Session?
    
    /// 当前moya使用的session
    public static var moyaSession: Session {
        return defaultSession()
    }
    
    private static func defaultSession() -> Session {
        if let session = self.session {
            return session
        }
        let configuration = URLSessionConfiguration.default
        configuration.headers = .default
        
        let new = Session(configuration: configuration, startRequestsImmediately: false)
        self.session = new
        return new
    }
    
    /// 发起网络请求
    /// - api: 业务层自定义网络请求API
    /// - enableLog: 针对当前请求的日志是否启用
    /// - CachableTarget: 为业务层API扩展了缓存能力
    /// - offerCacheIfExists：是否需要缓存
    /// - completion: 回调结果
    @discardableResult
    public static func commonRequest<API>(api: API,
                                          enableLog: Bool = false,
                                          offerCacheIfExists: ( (Data) -> Void )? = nil,
                                          progress: ((Double) -> Void)? = nil,
                                          completion: @escaping Callback<Response>) -> Cancellable?
    where
        API: CachableTarget {
        // 读取本地缓存的接口数据
        var fileName = ""
        if offerCacheIfExists != nil,
           case .key(let key) = api.cacheMethod,
            !key.isEmpty {
            
            let path = api.baseURL.absoluteString.replacingOccurrences(of: ":", with: "-") + api.path
            fileName = path.replacingOccurrences(of: "/", with: "|") + "_" + key
            
            cacheWorker.readCache(by: fileName) { (result) in
                if case .success(let data) = result {
                    offerCacheIfExists?(data)
                }
            }
        }
        
        /// 监听网络请求，自定义NetworkActivityPlugin 插件
//        let netWorkPlugin = NetworkActivityPlugin { (state, _) in
//            DispatchQueue.main.async {
//                switch state {
//                case .began:
//                    UIApplication.shared.isNetworkActivityIndicatorVisible = true
//                case .ended:
//                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
//                }
//            }
//        }
        
        /// 网络请求公共设置：设置请求时长，打印请求参数和数据返回
        let requestCloure: MoyaProvider<API>.RequestClosure = { (endPoint, done) in
            do {
                var request = try endPoint.urlRequest()
                // 设置请求时长
                request.timeoutInterval = api.timeout ?? defaultTimeOut
                if let cachePolicy = api.cachePolicy {
                    request.cachePolicy = cachePolicy
                }
                done(.success(request))
            } catch {
                if isEnableLog && enableLog {
                    logger.log(.error, args: error)
                }
                done(.failure(MoyaError.underlying(error, nil)))
            }
        }
        
        if let reach = try? Reachability.init(hostname: reachableTestHost),
           reach.connection == .unavailable {
            completion(.failure(.requestError))
            return nil
        }
        
        let provider = MoyaProvider<API>(requestClosure: requestCloure,
                                         session: defaultSession(),
                                         plugins: [])
        // 获取发送时间
        let beginTime = Date().timeIntervalSince1970
        
        // 处理相同请求
        if isEnableRepeatRequestCheck {
            if !requestChecker.beforeSendRequest(api: api) {
                if isEnableLog && enableLog {
                    logger.log(.warn, args: "发现相同请求 -- \(api.fullPath)")
                }
                return nil
            }
        }
        
        return provider.request(api, callbackQueue: DispatchQueue.main) { resp in
            progress?(resp.progress)
        } completion: { result in
            // 获取请求耗时
            let useTime = Int((Date().timeIntervalSince1970 - beginTime) * 1000)
            
            switch result {
            case .success(let response):
                
                if enableLog {
                    if api.method.rawValue == "GET" {
                        log(api:api,
                            param: "\(response.request?.url?.parametersFromQueryString ?? [:])",
                            response: response.data,
                            useTime: useTime)
                    } else {
                        let params = "\(String(data: response.request?.httpBody ?? Data(), encoding: String.Encoding.utf8) ?? "")"
                        log(api:api,
                            param: params,
                            response: response.data,
                            useTime: useTime)
                    }
                }
                
                let dict = try? JSONSerialization.jsonObject(with: response.data,
                                                             options: .allowFragments) as? [String: Any]
                if let status = dict?["status"] as? String,
                   status != StatusCode.success.rawValue {
                    
                    let message = dict?["message"] as? String
                    
                    if let handler = globalCactchNetworkError {
                        
                        handler( api, KFError(code: status, message: message ?? "请求失败")) {
                            if response.statusCode == 200 || response.statusCode == 403 {
                                completion(.success(response))
                            } else {
                                completion(.failure(.requestError))
                            }
                        }
                    } else {
                        
                        if response.statusCode == 200 || response.statusCode == 403 {
                            completion(.success(response))
                        } else {
                            completion(.failure(.requestError))
                        }
                    }
                    
                } else {
                    
                    if response.statusCode == 200 || response.statusCode == 403 {
                        completion(.success(response))
                    } else {
                        completion(.failure(.requestError))
                    }
                }
                
                
                if !fileName.isEmpty {
                    self.cacheWorker.save(data: response.data, for: fileName)
                }
                
                
            case .failure(let error):
                
                if case .underlying(let err, _) = error {
                    if let afErr = err.asAFError,
                       case .explicitlyCancelled = afErr {
                        
                        log(api:api,
                            param: nil,
                            response: nil,
                            useTime: nil)
                        return
                    }
                }
               
                log(api:api,
                    param: nil,
                    response: nil,
                    useTime: useTime,
                    error: error.errorDescription)
                
                completion(.failure(.requestError))
            }
        }
    }
    
    private static func log<API>(api: API,
                                 param: String?,
                                 response: Data?,
                                 useTime: Int?,
                                 error: String? = nil)
    where
        API: CachableTarget {
        if !isEnableLog {
            return
        }
        let requestMethod = api.method.rawValue
        let url = api.baseURL.absoluteString.appending(api.path)
        logger.log(.verbose, args: "⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️")
        if let time = useTime {
            logger.log(.verbose, args: "\(requestMethod): \(url) ( \(time) ms )")
            if let paramString = param {
                logger.log(.verbose, args: "请求参数： \n\(paramString)")
            }
            if let headers = api.headers, let xSid = headers["x-sid"] {
                logger.log(.verbose, args: "登录人信息x-sid：\n\(xSid)")
            }
            if let err = error {
                logger.log(.verbose, args: "请求失败\n原因：\(err)")
            } else {
                let res = String(data: response ?? Data(), encoding: .utf8) ?? " ()"
                logger.log(.verbose, args: "响应参数：\n\(res)")
            }
        } else {
            if let err = error {
                logger.log(.error, args: "请求失败 \(requestMethod): \(url)")
                logger.log(.error, args: "失败原因：\(err)")
            } else {
                logger.log(.warn, args: "取消请求 \(requestMethod): \(url) ")
            }
        }
        
        logger.log(.verbose, args: "⬆️⬆️⬆️⬆️⬆️⬆️⬆️⬆️⬆️⬆️\n")
    }
}

extension URL {
    fileprivate var parametersFromQueryString: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else { return nil }
        return queryItems.reduce(into: [String: String]()) { (result, item) in
            result[item.name] = item.value
        }
    }
}
