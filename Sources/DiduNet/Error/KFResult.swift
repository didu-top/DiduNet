//
//  ApiDriverData.swift
//  DiduNet
//
//  Created by Matt on 2021/3/3.
//  Copyright © 2021 didu.top. All rights reserved.
//

import Foundation

public typealias KFResult<T> = Result<T, KFError>

extension KFResult {
  
  /// 获取成功状态的值
  var value: Success? {
    if case .success(let val) = self {
      return val
    }
    return nil
  }
}
