//
//  CodableDefaultValue.swift
//  DiduNet
//
//  Created by matt on 2022/10/20.
//

import Foundation


public protocol DefaultValueProvidable {
  associatedtype Value: Codable
  static var defaultValue: Value { get }
}

/// 对于自定义类或结构体，需要有必要的默认初始化方法
public protocol Initializer {
  init()
}

public typealias CustomDefaultValue = DefaultValueProvidable & Initializer

/// 针对Bool类型，需要设置默认值为true的情况
public typealias True = Wrapper<Default.ValueImpl.True>

/// 针对Bool类型，需要设置默认值为false的情况
public typealias False = Wrapper<Default.ValueImpl.False>

/// 针对整数类型(Int/Int32/Int64/UInt/UInt32/UInt64)，需要设置默认值为0的情况
/// 针对浮点数类型(Float/Float32/Float64/Double),需要设置默认值为0.0的情况
public typealias Zero<T: Default.Number> = Wrapper<Default.ValueImpl.Zero<T>>

/// 针对集合类型(Array/Dictionary)，需要设置默认值为空集合的情况。
/// 针对字符串，需要设置为""的情况。
public typealias Empty<T: Default.Seq> = Wrapper<Default.ValueImpl.Empty<T>>

/// 针对自定义结构体需要设置默认值的情况
public typealias CustomValue<T: Default.Struct> = Wrapper<Default.ValueImpl.CustomValue<T>>

/// 
public struct Default {
  
  public typealias Number = Codable & Numeric
  
  public typealias Seq = Codable & Sequence
  
  public typealias Struct = Codable & Initializer
  
  /// 默认值实现
  public struct ValueImpl {
    
    /// 默认值为true
    public struct True: DefaultValueProvidable {
      public static var defaultValue: Bool = true
    }
    
    /// 默认值为false
    public struct False: DefaultValueProvidable {
      public static var defaultValue = false
    }
    
    /// 默认值为0
    public struct Zero<T: Number> { }
    
    /// 默认为空
    public struct Empty<T: Seq> { }
    
    /// 自定义结构体使用defaultValue
    public struct CustomValue<T: Struct> {}
    
  }
  
}

/// 实际工作的包装器
@propertyWrapper
public struct Wrapper<T>: Codable where T: DefaultValueProvidable {
  public var wrappedValue: T.Value
  
  public init(from decoder: Decoder) throws {
    let container = try? decoder.singleValueContainer()
    let value = try? container?.decode(T.Value.self)
    self.wrappedValue = value ?? T.defaultValue
  }
  
  public init() {
    wrappedValue = T.defaultValue
  }
}

/// 针对基本数值类型提供默认实现 0
extension Default.ValueImpl.Zero: DefaultValueProvidable where T: Default.Number {
  public static var defaultValue: T {
    if (0 as? T) != nil {
      return 0 as! T
    } else if Int32(0) is T {
      return Int32(0) as! T
    } else if Int64(0) is T {
      return Int64(0) as! T
    } else if UInt(0) is T {
      return UInt(0) as! T
    } else if UInt32(0) is T {
      return UInt32(0) as! T
    } else if UInt64(0) is T {
      return UInt64(0) as! T
    }  else if (0.0 as? T) != nil {
      return 0.0 as! T
    } else if Float(0.0) is T {
      return Float(0.0) as! T
    }  else {
      
    }
    
    fatalError("需要实现 defaultValue ")
  }
}

/// 针对集合类型提供默认实现
extension Default.ValueImpl.Empty: DefaultValueProvidable where T: Default.Seq {
  public static var defaultValue: T {
    if ("" as? T) != nil {
      return "" as! T
    } else if ([] as? T) != nil {
      return [] as! T
    } else if ([:] as? T) != nil {
      return [:] as! T
    }
    fatalError("需要实现 defaultValue")
  }
}

extension Default.ValueImpl.CustomValue : DefaultValueProvidable where T: Default.Struct {
  public static var defaultValue: T {
    return T.init()
  }
  
  public typealias Value = T
}



/// 如果json中key不存在 正常初始化采用默认值
public extension KeyedDecodingContainer {
  func decode<T>(_ type: Wrapper<T>.Type,
                 forKey key: Key) throws -> Wrapper<T> {
    try decodeIfPresent(type, forKey: key) ?? .init()
  }
}
