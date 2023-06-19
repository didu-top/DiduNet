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
    func decode(data: Data) -> KFResult<Model>
}

/// 提供解码后回调能力
public protocol RequestCallback {
    associatedtype Model
    /// 提供有缓存时的回调
    var offerCacheIfExist: ((KFResult<Model>) -> Void)? { get }
    /// 请求结束后并将数据解码成对象后的回调
    var completion: (KFResult<Model>) -> Void { get }
}

/// 请求Handler基类
public class RequestHandler<Model>: RequestCallback, DecodeAction {
    
    private(set) public var offerCacheIfExist: ((KFResult<Model>) -> Void)?
    private(set) public var completion: (KFResult<Model>) -> Void
    
    public init(offerCacheIfExist: ((KFResult<Model>) -> Void)? = nil, completion: @escaping (KFResult<Model>) -> Void) {
        self.offerCacheIfExist = offerCacheIfExist
        self.completion = completion
    }
    
    public func decode(data: Data) -> KFResult<Model> {
        return .failure(.decodeError)
    }
}

/// 基于Codable的Handler实现，提供解析实现Codable协议的数据模型
public final class CodableHandler<Model>: RequestHandler<Model> where Model: Codable {
    typealias Model = Model
    
    public override func decode(data: Data) -> KFResult<Model> {
        // 网络数据解析成功
        do {
            let model = try JSONDecoder().decode(ResponseModel<Model>.self, from: data)
            return model.result
        }
        catch let err as KFError { // 无result
            return .failure(err)
        }
        catch { // 数据解析失败
            return .failure(KFError.decodeError)
        }
    }
}


public func handler<T: Codable>(_ type: T.Type, offerCacheIfExist: ((KFResult<T>) -> Void)? = nil, completion: @escaping (KFResult<T>) -> Void) -> CodableHandler<T> {
    return CodableHandler(offerCacheIfExist: nil, completion: completion)
}

