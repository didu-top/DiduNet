//
//  Switcher.swift
//  DiduNet
//
//  Created by matt on 2021/3/19.
//  Copyright © 2021 didu.top. All rights reserved.
//

import Foundation

/// 二选一类型
/// 给定两种类型, 要么出现this 要么出现that 否则出错
public enum Switcher<This,That>: Codable where This: Codable, That: Codable {
  case this(This)
  case that(That)
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let this = try? container.decode(This.self) {
      self = .this(this)
    } else if let that = try? container.decode(That.self) {
      self = .that(that)
    } else {
      throw KFError.decodeError
    }
  }
}
