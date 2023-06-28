//
//  Network+Coroutine.swift
//  DiduNet
//
//  Created by matt on 2023/6/26.
//

import Foundation

extension Network {
  
  /// 获取原始数据
  public static func requestData<API>(api: API,
                                      enableLog: Bool = false,
                                      progress: Progress? = nil) async -> KFResult<Data>
  where API: CachableTarget {
    
    return await withCheckedContinuation({ continuation in
      commonRequest(api: api,
                    enableLog: enableLog,
                    progress: { pr in
        
        progress?.completedUnitCount = Int64(pr*100)
        
      }) { result in
        
        switch result {
        case .success(let resp):
          continuation.resume(returning: .success(resp.data))
        case .failure(let error):
          continuation.resume(returning: .failure(error))
        }
        
      }
    })
  }
  
  /// 自定义提供Response解析
  public static func request<API,Resp>(api: API,
                                       enableLog: Bool = false,
                                       progress: Progress? = nil,
                                       forResponse type: Resp.Type) async -> KFResult<Resp>
  where API: CachableTarget,
        Resp: Codable {
          
          return await withCheckedContinuation({ continuation in
            commonRequest(api: api,
                          enableLog: enableLog, progress: { pr in
              
              progress?.completedUnitCount = Int64(pr*100)
              
            }) { result in
              switch result {
              case .success(let resp):
                do {
                  let model = try JSONDecoder().decode(Resp.self, from: resp.data)
                  continuation.resume(returning: .success(model))
                } catch {
                  let err = (error as? KFError) ?? KFError.decodeError
                  continuation.resume(returning: .failure(err))
                }
              case .failure(let error):
                continuation.resume(returning: .failure(error))
              }
            }
          })
  }
                    
  /// 使用内置ResponseModel解析
  public static func request<API, T>(api: API,
                                     enableLog: Bool = false,
                                     progress: Progress? = nil,
                                     forType type: T.Type) async -> KFResult<T>
  where API: CachableTarget,
        T: Codable {
          
          let resp = await self.request(api: api,
                                        enableLog: enableLog,
                                        progress: progress,
                                        forResponse: ResponseModel<T>.self)
          switch resp {
          case .success(let model):
            switch model {
            case .success(let t):
              return .success(t)
            case .fail(let error):
              return .failure(error)
            }
          case .failure(let error):
            return .failure(error)
          }
        }
}
