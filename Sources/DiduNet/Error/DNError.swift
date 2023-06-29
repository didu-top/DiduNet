//
//  DNResult.swift
//  DiduNet
//
//  Created by Matt on 2021/3/3.
//  Copyright © 2021 didu.top. All rights reserved.
//

import Foundation

/// 自定义错误码
public struct DNDomainCode: Equatable {
  var raw: String
  
  public init(intValue: Int) {
    raw = String(intValue)
  }
  
  public init(stringValue: String) {
    raw = stringValue
  }
  
  public init?(_ val: Any) {
    if let v = val as? String {
      raw = String(v)
    } else if let v = val as? Int {
      raw = String(v)
    } else {
      return nil
    }
  }
  
  /// 请求失败
  static let requestError = DNDomainCode(stringValue: "L10001")
  
  /// 解析失败
  static let decodeError = DNDomainCode(stringValue: "L10002")
  
  /// 任务取消
  static let cancel = DNDomainCode(stringValue: "L10003")
}

/// 自定义Error
public struct DNError: Error {
  
  public init(code: DNDomainCode, message: String) {
    
    self.code = code
    
    self.message = message
  }
  
  /// 错误码
  public var code: DNDomainCode
  
  /// 错误信息
  public var message: String
  
  static var requestError: Self {
    return .init(code: .requestError, message: "请求失败")
  }
  
  static var decodeError: Self {
    return .init(code: .decodeError, message: "数据解析失败")
  }
  
  static var noResultFieldError: Self {
    return .init(code: .requestError, message: "无result字段")
  }
  
  static var cancel: Self {
    return .init(code: .cancel, message: "任务取消")
  }
}



