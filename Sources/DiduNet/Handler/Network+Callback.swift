//
//  Network+Callback.swift
//  DiduNet
//
//  Created by zenzz on 2021/8/5.
//

import Foundation


extension Network {
    
    @discardableResult
    public static func requestData<API, Handler>(api: API,
                                                 enableLog: Bool = false,
                                                 progress: ((Double) -> Void)? = nil,
                                                 handler: Handler) -> Cancellable?
    where
        API: CachableTarget,
        Handler: DecodeAction & RequestCallback {
            
        return commonRequest(api: api, enableLog: enableLog) { data in
            let result = handler.decode(data: data)
            handler.offerCacheIfExist?(result)
        } progress: { per in
            progress?(per)
        } completion: { (result) in
            switch result {
            case .success(let response):
                let decodeResult = handler.decode(data: response.data)
                
                handler.completion(decodeResult)
            case .failure(let error):
                handler.completion(.failure(error))
            }
        }
        
    }
}
