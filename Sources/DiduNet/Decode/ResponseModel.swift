//
//  Response.swift
//  DiduNet
//
//  Created by Matt on 2021/3/3.
//  Copyright © 2021 didu.top. All rights reserved.
//

import Foundation

/// 自定义一个公共网络请求的Model，根据didu.top接口返回数据格式（didu.top接口格式如：status、message、result）
public enum ResponseModel<T> {
  /// 存在Data为空的情况，所以T泛型可能为空
  case pass(T)
  
  /// 返回自定义Error
  case error(DNError)
  
  /// 自定义字段属性，使用Codable解析需要
  /// 注意 1.需要遵守Codingkey  2.每个字段都要枚举
  enum CodingKeys: String, CodingKey {
    case code = "status"
    case message = "message"
    case data = "result"
  }
  
  /// 构造方法，参数是泛型T，代表业务层传递进来的Model
  public init(result: T) {
    self = .pass(result)
  }
}


/// 业务层传递的Model是基于Codable解析使用该方法
extension ResponseModel: Codable where T: Codable {
  
  /// 编码
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    
    switch self {
    case .pass(let result):
      try container.encode(Network.domainSucessKeyValePair.1.raw, forKey: .code)
      try container.encode("", forKey: .message)
      if !(NoResult() is T) {
        try container.encode(result, forKey: .data)
      }
    case .error(let error):
      let status = error.code
      try container.encode(status.raw, forKey: .code)
      try container.encode(error.message, forKey: .message)
    }
  }
  
  /// 解码
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    do {
      // 获取状态码
      let code = try container.decode(String.self, forKey: .code)
      // 检查状态是否是成功状态码
      if code == Network.domainSucessKeyValePair.1.raw {
        // 如果传入的是NoResult
        if NoResult() is T {
          self = .pass(NoResult() as! T) // swiftlint:disable:this force_cast
        } else {
          // 检查result字段是否存在,如果存在是否是null值
          let resultFieldIsNil = try? container.decodeNil(forKey: .data)
          if resultFieldIsNil == nil || resultFieldIsNil == true {
            if Optional<Any>.none is T {
              self = .pass(Optional<Any>.none as! T)
            } else {
              throw DNError.noResultFieldError
            }
          } else {
            let res = try container.decode(T.self, forKey: .data)
            self = .pass(res)
          }
        }
      } else { // 非成功状态码处理
        let msg = (try? container.decode(String.self, forKey: .message)) ?? "请求失败"
        throw DNError(code: DNDomainCode(stringValue: code), message: msg)
      }
    } catch {
      throw error
    }
  }
}

/// 当业务层只需要关心接口成功，不关心接口返回数据，使用该类型（当传入NoResult时，不会检查result字段，是基于Codable协议）
public struct NoResult: Codable {
  public init() {}
}

