//
//  KfangError.swift
//  DiduNet
//
//  Created by Matt on 2021/3/3.
//  Copyright © 2021 didu.top. All rights reserved.
//

import Foundation

/// 自定义Error
public struct KFError: Error {
  /// 错误码
  public var code: String
  
  /// 错误信息
  public var message: String
  
  public init(code: String, message: String) {
    self.code = code
    self.message = message
  }
}

/// 统一管理状态码，内部使用
public enum StatusCode: String {
  
  /// 默认客户端产生的错误状态码
  case clientError = "L0001"
  
  /// 参数错误
  case paramError = "L0002"
  
  /// 无权限
  case noPermisssonError = "L0003"
  
  /// 服务器请求成功的状态码
  case success = "C0000"
  
  
  /// 网络状态导致的请求错误
  case networkError = "KF0001"
  
  /// 无result字段或接口result为null时出现
  case noResultFieldError = "KF1000"
}

/// 拓展一个status属性，方便KfangError这个类
extension String {
  
  /// 获取状态码
  public static func status(_ code: StatusCode) -> Self {
    return code.rawValue
  }
}

extension KFError {
  
  /// 数据解析失败
#if DEBUG
  public static var decodeError = KFError(code: .status(.clientError), message: "数据解析异常")
#else
  public static var decodeError = KFError(code: .status(.clientError), message: "数据异常")
#endif
  
  public static var noResultFieldError = KFError(code: .status(.noResultFieldError), message: "系统异常，请稍后再试")
  
  /// 请求失败
  public static var requestError = KFError(code: .status(.networkError), message: "网络不给力，请刷新试试")
  
  /// 是否是网络请求失败
  public var isNetworkError: Bool {
    return code == .status(.networkError)
  }
}
