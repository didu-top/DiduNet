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

/// 捕获之后的动作
public enum ActionAfterCatch {
  /// 标记为取消
  case markCancel
  /// 转移请求
  case transferred
  /// 继续执行
  case `continue`
}

public typealias Callback<T> = (DNResult<T>) -> Void
public typealias CatchCallback = (ActionAfterCatch) ->Void

internal let logger = Logger(lowerLevel: .verbose, prefixMap: [
  .verbose: "􀤆􀤆 - 🗒 => ",
  .warn: "􀤆􀤆 - ⚠️ => ",
  .error: "􀤆􀤆 - ❌ => "
])


// MARK: - 网络请求（返回原始数据）
public class Network {
  
  
  /// 需要捕获的HTTP错误码列表
  /// 比如: [404,401]
  public static var golbalCatchHttpCodeList: [Int] = []
  
  /// 设置全局捕获HTTP错误码的动作
  /// 闭包参数为：( API, 状态码，继续执行的回调: 是否将任务标记为取消)
  public static var globalCatchHttpErrorCodeAction: ((CachableTarget, Int, @escaping Callback<Response>, CatchCallback) -> Void)?
  
  
  /// 设置判定领域设计(即服务器接口数据设计)请求成功的设计标记
  public static var domainSucessKeyValePair: (String, DNDomainCode) = ("code", DNDomainCode(stringValue: "C0000"))
  
  public static var domainFailedMessageKey: String = "message"
  
  /// 设置全局捕获领域设计(即服务器接口数据设计)错误码的动作
  /// 闭包参数为：( API, 响应原始数据，需要继续执行的回调: 是否将任务标记为取消)
  public static var domainMiddlewareAction: ((CachableTarget, Data, @escaping Callback<Response>, CatchCallback) -> Void)?
  
//  public 
  /// 是否全局启用日志
  public static var isEnableLog = false
  
  /// 默认请求超时
  public static var defaultTimeOut: Double = 30
  
  /// 网络联通测试主机地址
  public static var reachableTestHost = "https://www.google.com"
  
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
  /// - completion: 回调结果
  @discardableResult
  public static func commonRequest<API>(api: API,
                                        enableLog: Bool = false,
                                        progress: ((Double) -> Void)? = nil,
                                        completion: @escaping Callback<Response>) -> Cancellable?
  where API: CachableTarget {
    
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
        
        if response.statusCode != 200 {
          if golbalCatchHttpCodeList.contains(response.statusCode),
              let catchHandler = globalCatchHttpErrorCodeAction {
            catchHandler(api, response.statusCode, completion) {
              action in
              switch action {
              case .markCancel:
                completion(.failure(.cancel))
              case .continue:
                completion(.failure(.init(code: .init(intValue: response.statusCode), message: response.description)))
              case .transferred:
                break
              }
              if case .markCancel = action  {
                completion(.failure(.cancel))
              } else {
                completion(.failure(.init(code: .init(intValue: response.statusCode), message: response.description)))
              }
            }
          } else {
            completion(.failure(.init(code: .init(intValue: response.statusCode), message: response.description)))
          }
        } else {
          if let domainCodeCatchAction = domainMiddlewareAction {
            domainCodeCatchAction(api, response.data, completion) {
              action in
              switch action {
              case .markCancel:
                completion(.failure(.cancel))
              case .continue:
                completion(.success(response))
              case .transferred:
                break
              }
            }
          } else {
            completion(.success(response))
          }
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
  where API: CachableTarget {
    
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
