//
//  MultipleRequestCancelable.swift
//  DiduNet
//
//  Created by matt on 2021/6/22.
//  Copyright © 2021 didu.top. All rights reserved.
//

import Foundation

/// 请求取消匹配模式
public enum RequestMatchMode {
  /// url完整匹配
  case whole
  /// url匹配前面部分
  case prefix
}

/// 取消网络请求配置
public struct CancelRequestConfig {
  
  public init(target: CachableTarget, mode: RequestMatchMode) {
    self.target = target
    self.mode = mode
  }
  
  
  public  var target: CachableTarget
  
  public var mode: RequestMatchMode
  
  public var fullPath: String {
    switch mode {
    case .prefix:
      return target.baseURL.absoluteString + target.path
    case .whole:
      return target.fullPath
    }
  }
}

/// 提供取消多个网络请求的能力，一般由Controller和ViewModel实现
public protocol MultipleRequestCancelable: AnyObject {
  
  /// 需要取消请求的Api，需要在对象`deinit`被调用之前设置好
  var needCancelRequestConfigs: [CancelRequestConfig] { get  set }
}


extension MultipleRequestCancelable {
  
  /// 根据`needCancelRequestURLs`内容，如果还存在正在请求的网络请求，则会取消
  public func cancelRequests(_ configList: [CancelRequestConfig]) {
    
    let configs = configList.map({ ($0.fullPath, $0.mode) })
    
    Network.moyaSession.session.getAllTasks { taskList in
      
      let runningTaskList =  taskList
        .filter({ $0.state == .running })
      
      let currentTaskList = runningTaskList
        .compactMap({ task -> URLSessionTask? in
          if let urlString = task.originalRequest?.url?.absoluteString {
            if configs.contains(where: { (url, mode) in
              switch mode {
              case .whole:
                return url == urlString
              case .prefix:
                return urlString.hasPrefix(url)
              }
            }) {
              return task
            }
          }
          return nil
        })
      //            logInfo("清理网络请求：共\(currentTaskList.count)个")
      currentTaskList
        .forEach { task in
          //                    logInfo("cancel \(task.originalRequest?.url?.absoluteString ?? "")")
          task.cancel()
        }
    }
  }
}
