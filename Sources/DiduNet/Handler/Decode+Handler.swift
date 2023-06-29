//
//  RequestHandler.swift
//  DiduNet
//
//  Created by matt on 2021/3/22.
//  Copyright © 2021 didu.top. All rights reserved.
//

import Foundation
import DiduFoundation

/// 解码动作，提供解码能力
public protocol DecodeAction {
  associatedtype Model
  func decode(data: Data) -> DNResult<Model>
}

/// 提供解码后回调能力
public protocol RequestCallback {
  associatedtype Model
  /// 请求结束后并将数据解码成对象后的回调
  var completion: (DNResult<Model>) -> Void { get }
}

/// 请求Handler基类
public class RequestHandler<Model>: RequestCallback, DecodeAction {
  private(set) public var completion: (DNResult<Model>) -> Void
  
  public init(completion: @escaping (DNResult<Model>) -> Void) {
    self.completion = completion
  }
  
  public func decode(data: Data) -> DNResult<Model> {
    return .failure(.decodeError)
  }
}

/// 基于Codable的Handler实现，提供解析实现Codable协议的数据模型
public final class CodableHandler<Model>: RequestHandler<Model> where Model: Codable {
  typealias Model = Model
  
  public override func decode(data: Data) -> DNResult<Model> {
    // 网络数据解析成功
    do {
      let model = try JSONDecoder().decode(ResponseModel<Model>.self, from: data)
      switch model {
      case .pass(let field):
        return .success(field)
      case .error(let error):
        return .failure(error)
      }
    }
    catch let err as DNError { // 无result
      return .failure(err)
    }
    catch { // 数据解析失败
      return .failure(.decodeError)
    }
  }
}

/// 基于Codable的Handler实现，自定义ResponseModel解析
public final class ResponseHandler<Resp>: RequestHandler<Resp>

where Resp: Codable {
  typealias Resp = Model
  
  public override func decode(data: Data) -> DNResult<Resp> {
    // 网络数据解析成功
    do {
      let resp = try JSONDecoder().decode(Resp.self, from: data)
      return .success(resp)
    }
    catch let err as DNError { // 无result
      return .failure(err)
    }
    catch { // 数据解析失败
      return .failure(.decodeError)
    }
  }
}


public func handler<T: Codable>(_ type: T.Type,
                                completion: @escaping (DNResult<T>) -> Void) -> CodableHandler<T> {
  return CodableHandler(completion: completion)
}

public func handler<T: Codable>(customResponse type: T.Type,
                                completion: @escaping (DNResult<T>) -> Void) -> ResponseHandler<T> {
  return ResponseHandler(completion: completion)
}

