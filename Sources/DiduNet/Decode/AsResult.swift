//
//  File.swift
//  DiduNet
//
//  Created by matt on 2021/3/19.
//  Copyright © 2021 didu.top. All rights reserved.
//

import Foundation


public protocol AsResult {
    associatedtype Model
    var result: KFResult<Model> { get }
}

/// 量子力学类型 - 薛定谔的猫
/// 给定两种类型, 要么出现live 要么出现dead 否则出错
public enum SchrodingersCat<Live,Dead>: Codable where Live: Codable, Dead: Codable {
    case live(Live)
    case dead(Dead)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let live = try? container.decode(Live.self) {
            self = .live(live)
        } else if let dead = try? container.decode(Dead.self) {
            self = .dead(dead)
        } else {
            throw KFError.decodeError
        }
    }
}
