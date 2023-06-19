//
//  Network+Rx.swift
//  DiduNet
//
//  Created by zenzz on 2021/8/5.
//

import Foundation
@_exported import RxSwift

// MARK: - 网络请求（RxSwift,默认返回原始数据）
extension Network {
    
    /// 基于Rx的请求方式, 通过NetworkData区分来自本地接口缓存和实时接口数据，回调的数据到业务层是原始数据，需要业务层调用DataToModel类的方法去解析
    public static func requestNetworkData<API>(api: API,
                                               enableLog: Bool = false) -> Observable<NetworkData<Data>>
    where
        API: CachableTarget {
            
        let seq = Observable<NetworkData<Data>>.create { (observer) -> Disposable in
            
            Network.commonRequest(api: api,
                                  enableLog: enableLog) { (data) in
                observer.onNext(.cache(data))
            } completion: { (res) in
                switch res {
                case .success(let response):
                    observer.onNext(.network(response.data))
                case .failure(let error):
                    observer.onError(error)
                }
                observer.onCompleted()
            }
            
            return Disposables.create()
        }
        return seq
    }
    
    
    /// 基于Rx的请求方式, 通过NetworkData区分来自本地接口缓存和实时接口数据，回调的数据到业务层是原始数据，需要业务层调用DataToModel类的方法去解析
    /// - Returns: 返回两个可监听序列，第一个是请求进度的，第二个是请求结果的
    public static func requestNetworkData<API>(api: API,
                                               enableLog: Bool = false) -> (Observable<Double>,  Observable<NetworkData<Data>>)
    where
        API: CachableTarget {
            
        let progressSub = PublishSubject<Double>()
        let completionSub = PublishSubject<NetworkData<Data>>()
        
        Network.commonRequest(api: api, enableLog: enableLog) { data in
            completionSub.onNext(.cache(data))
            completionSub.onCompleted()
        } progress: { per in
            progressSub.onNext(per)
        } completion: { res in
            progressSub.onCompleted()
            switch res {
            case .success(let response):
                completionSub.onNext(.network(response.data))
            case .failure(let error):
                completionSub.onError(error)
            }
            completionSub.onCompleted()
        }
        return (progressSub, completionSub)

    }
    
    /// 基于Rx的请求方式，回调的数据到业务层是原始数据，需要业务层调用DataToModel类的方法去解析
    public static func requestData<API>(api: API,
                                        enableLog: Bool = false) -> Observable<Data>
    where
        API: CachableTarget {
            
        let seq = Observable<Data>.create { (observer) -> Disposable in
            Network.commonRequest(api: api, enableLog: enableLog) { (res) in
                switch res {
                case .success(let response):
                    observer.onNext(response.data)
                case .failure(let error):
                    observer.onError(error)
                }
                observer.onCompleted()
            }
            return Disposables.create()
        }
        return seq
    }
    
    
    /// 基于Rx的请求方式，回调的数据到业务层是原始数据，需要业务层调用DataToModel类的方法去解析
    /// - Returns: 返回两个可监听序列，第一个是请求进度的，第二个是请求结果的
    public static func requestData<API>(api: API,
                                        enableLog: Bool = false) -> (Observable<Double>,  Observable<Data>)
    where
        API: CachableTarget {
        
        let progressSub = PublishSubject<Double>()
        let completionSub = PublishSubject<Data>()
        
        Network.commonRequest(api: api, offerCacheIfExists: nil) { per in
            progressSub.onNext(per)
        } completion: { res in
            progressSub.onCompleted()
            switch res {
            case .success(let response):
                completionSub.onNext(response.data)
            case .failure(let error):
                completionSub.onError(error)
            }
            completionSub.onCompleted()
        }
        return (progressSub, completionSub)
    }
}
