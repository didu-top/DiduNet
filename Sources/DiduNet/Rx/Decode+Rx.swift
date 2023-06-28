//
//  Modelable.swift
//  DiduNet
//
//  Created by matt on 2021/3/17.
//  Copyright © 2021 didu.top. All rights reserved.
//

import Foundation
@_exported import RxSwift

extension Observable where Element == Data {
  
  /// 使用内置ResponeModel解析
  public func decodeTo<U>(_ type: U.Type) -> Observable<KFResult<U>>
  where U: Codable {
    return self.map { (data) -> KFResult<U> in
      do {
          let model = try JSONDecoder().decode(ResponseModel<U>.self, from: data)
        switch model {
        case .success(let f):
          return .success(f)
        case .fail(let err):
          return .failure(err)
        }
      } catch let err as KFError {
        return .failure(err)
      }
    }
  }
  /// 自定义ResonseModel解析
  public func decodeTo<Resp>(customeResponse type: Resp.Type) -> Observable<KFResult<Resp>>
  where Resp: Codable {
    return self.map { (data) -> KFResult<Resp> in
      do {
        let model = try JSONDecoder().decode(Resp.self, from: data)
        return .success(model)
      } catch {
        let err = (error as? KFError) ?? .requestError
        return .failure(err)
      }
    }
  }
}
