//
//  Network+Coroutine.swift
//  DiduNet
//
//  Created by matt on 2023/6/26.
//

import Foundation

extension Network {
  public static func request<API, T>(api: API,
                                     enableLog: Bool = false,
                                     progress: Progress? = nil,
                                     forType type: T.Type) async -> KFResult<T>
  where API: CachableTarget,
        T: Codable {
          return await withCheckedContinuation({ continuation in
            commonRequest(api: api,
                          enableLog: enableLog) { result in
              switch result {
              case .success(let resp):
                do {
                  let model = try JSONDecoder().decode(ResponseModel<T>.self, from: resp.data)
                  switch model {
                  case .success(let f):
                    continuation.resume(returning: .success(f))
                  case .fail(let err):
                    continuation.resume(returning: .failure(err))
                  }
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
}
