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

public typealias NetworkCallback<T> = (DNResult<T>) -> Void
public typealias CatchCallback = (ActionAfterCatch) ->Void

internal let logger = Logger(lowerLevel: .verbose, prefixMap: [
  .verbose: "􀤆􀤆 - 🗒 => ",
  .warn: "􀤆􀤆 - ⚠️ => ",
  .error: "􀤆􀤆 - ❌ => "
])


// MARK: - 网络请求（返回原始数据）
public class Network {
  
  /// 需要捕获的HTTP错误码列表，比如: [404,401]
  public static var globalCatchHttpCodeList: [Int] = []
  
  /// 设置全局捕获HTTP错误码的动作， 闭包参数为：( API, 状态码，继续执行的回调: 是否将任务标记为取消)
  public static var globalCatchHttpErrorCodeAction: ((CachableTarget, Int, @escaping NetworkCallback<Response>, CatchCallback) -> Void)?
  
  /// 设置判定领域设计(即服务器接口数据设计)请求成功的设计标记
  public static var domainSucessKeyValePair: (String, DNDomainCode) = ("code", DNDomainCode(stringValue: "C0000"))
  
  public static var domainFailedMessageKey: String = "message"
  
  /// 设置全局捕获领域设计(即服务器接口数据设计)错误码的动作，闭包参数为：( API, 响应原始数据，需要继续执行的回调: 是否将任务标记为取消)
  public static var domainMiddlewareAction: ((CachableTarget, Data, @escaping NetworkCallback<Response>, CatchCallback) -> Void)?
  
  /// 是否全局启用日志
  public static var isEnableLog = false
  
  /// 默认请求超时
  public static var defaultTimeOut: Double = 30
  
  /// 网络联通测试主机地址
  public static var reachableTestHost = "https://www.google.com"
  
  private static var session: Session?
  
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
  
  private init() {}
  
  
  
  /// 发起网络请求
  /// - api: 业务层自定义网络请求API
  /// - enableLog: 针对当前请求的日志是否启用
  /// - CachableTarget: 为业务层API扩展了缓存能力
  /// - completion: 回调结果
  @discardableResult
  public static func commonRequest<API>(
    api: API,
    enableLog: Bool = false,
    progress: ((Double) -> Void)? = nil,
    completion: @escaping NetworkCallback<Response>
  ) -> Cancellable?
  where API: CachableTarget {
    
    guard let reach = try? Reachability(hostname: reachableTestHost),
          reach.connection != .unavailable else {
      completion(.failure(.requestError))
      return nil
    }
    
    let provider = MoyaProvider<API>(
      requestClosure: { (endPoint, done) in
        do {
          // 配置超时时间、缓存策略
          var request = try endPoint.urlRequest()
          request.timeoutInterval = api.timeout ?? defaultTimeOut
          if let cachePolicy = api.cachePolicy {
            request.cachePolicy = cachePolicy
          }
          done(.success(request))
        } catch {
          if isEnableLog && enableLog {
            logger.log(.error, args: error)
          }
          completion(.failure(.requestError))
        }
      },
      session: defaultSession(),
      plugins: []
    )
    
    // 获取发送时间
    let beginTime = Date().timeIntervalSince1970
    
    return provider.request(api, callbackQueue: DispatchQueue.main) { resp in
      progress?(resp.progress)
    } completion: { result in
      switch result {
      case .success(let response):
        // 获取请求耗时
        let useTime = Int((Date().timeIntervalSince1970 - beginTime) * 1000)
        logResponse(api: api, response: response, useTime: useTime, enableLog: enableLog)
        handleResponse(api: api, response: response, completion: completion)
      case .failure(let error):
        
        // 请求被取消
        guard case let .underlying(afError as AFError, _) = error,
              case .explicitlyCancelled = afError else {
          logError(api: api, error: nil, enableLog: enableLog)
          return
        }
        logError(api: api, error: error, enableLog: enableLog)
        
        completion(.failure(.requestError))
      }
    }
  }
}

// MARK: - 处理成功
extension Network {
  private static func handleResponse<API>(api: API,
                                          response: Response,
                                          completion: @escaping NetworkCallback<Response>)
  where API: CachableTarget {
    
    let code = response.statusCode
    if code != 200 {
      guard globalCatchHttpCodeList.contains(code),
            let catchHandler = globalCatchHttpErrorCodeAction else {
        completion(.failure(.init(code: .init(intValue: response.statusCode), message: response.description)))
        return
      }
      
      catchHandler(api, code, completion) {
        action in
        switch action {
        case .markCancel:
          completion(.failure(.cancel))
        case .continue:
          completion(.failure(.init(code: .init(intValue: code), message: response.description)))
        case .transferred:
          break
        }
      }
      return
    }
    
    
    // 全局捕获
    guard let domainCodeCatchAction = domainMiddlewareAction else {
      completion(.success(response))
      return
    }
    
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
  }
}

// MARK: - 日志打印
extension Network {
  private static func logResponse<API>(api: API, response: Response, useTime: Int?, enableLog: Bool)
  where API: CachableTarget {
    
    guard isEnableLog && enableLog else { return }
    
    let method = api.method.rawValue
    let url = api.baseURL.absoluteString.appending(api.path)
    var paramStr = ""
    if api.method.rawValue == "GET" {
      paramStr = "\(response.request?.url?.parametersFromQueryString ?? [:])"
    } else {
      paramStr = "\(String(data: response.request?.httpBody ?? Data(), encoding: String.Encoding.utf8) ?? "")"
    }
    
    let time = "\(useTime ?? 0) ms"
    let res = String(data: response.data, encoding: .utf8) ?? ""
    logger.log(.verbose, args: "⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️⬇️")
    logger.log(.verbose, args: "\(method): \(url) ( \(time) )")
    logger.log(.verbose, args: "请求参数： \n\(paramStr)")
    logger.log(.verbose, args: "响应参数：\n\(res)")
    logger.log(.verbose, args: "⬆️⬆️⬆️⬆️⬆️⬆️⬆️⬆️⬆️⬆️\n")
  }
  
  private static func logError<API>(api: API, error: Error?, enableLog: Bool)
  where API: CachableTarget {
    guard isEnableLog && enableLog else { return }
    let method = api.method.rawValue
    let url = api.baseURL.absoluteString.appending(api.path)
    if let err = error {
      logger.log(.error, args: "请求失败 \(method): \(url)")
      logger.log(.error, args: "失败原因：\(err.localizedDescription)")
    } else {
      logger.log(.warn, args: "取消请求 \(method): \(url) ")
    }
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
