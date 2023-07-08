import XCTest
@testable import DiduNet
import RxSwift

enum Api {
  case test1
  case test2
  case test3
  case token
}

extension Api: CachableTarget {
  var baseURL: URL {
    URL(string: "http://192.168.194.52:8000")!
  }
  
  var path: String {
    switch self {
    case .test1:
      return "/test1.json"
    case .test2:
      return "/test2.json"
    case .test3:
      return "/test3.json"
    case .token:
      return "/token.json"
    }
  }
  
  var method: Moya.Method {
    return .get
  }
  
  var task: Moya.Task {
    return .requestPlain
  }
  
  var headers: [String : String]? {
    return [:]
  }
  
  
}

//extension Api: CachableTarget {
//  var baseURL: URL = URL(string: "http://192.168.194.52:8000")!
//
//  var path: String = "/test3.json"
//
//  var method: Moya.Method = .get
//
//  var task: Moya.Task = .requestPlain
//
//  var headers: [String : String]? = nil
//
//
//}
//struct ResponseModel<T>: Codable where T: Codable {
//  var code: Int
//  var message: String?
//  var result: T?
//}

class RefreshTokenManager {
  static let `default` = RefreshTokenManager()
  
  private var isRefreshing: Bool = false
  
  private var queue = DispatchQueue(label: "com.xxx.refreshToken")
  
  private var list: [(CachableTarget, Callback<Response>)] = []
  
  
  
  func checkRefreshingToken(api: CachableTarget, callback: @escaping Callback<Response> ) {
    queue.async {
      self.list.append((api, callback))
      
      if !self.isRefreshing {
        self.requestRefreshToken()
      }
    }
  }
  
  
  private func requestRefreshToken() {
    self.isRefreshing = true
    _Concurrency.Task {
      let tokenResult = await DiduNet.Network.request(api: Api.test3, forType: String.self)
      
      switch tokenResult {
      case .success(let token):
        // TODO: 保存新token
        print("---- \(token)")
        self.queue.async {
          self.isRefreshing = false
          for it in self.list {
            Network.commonRequest(api: Api.test3, completion: it.1)
          }
          self.list.removeAll(keepingCapacity: true)
        }
      case .failure(let error):
        // TODO: 刷新token失败
        print(error)
        break
      }
      
    }
  }
  
  
  
}


final class DiduNetTests: XCTestCase {
  func testExample() throws {
    
  }
  
  func testRefreshTokenRequest() async {
    Network.domainMiddlewareAction =  {
      (api, data, comp, callback) in
      do {
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let isRefreshTokenCode = dict?["status"] as? String == "E0001"
        if isRefreshTokenCode && api.path != Api.token.path {
          callback(.transferred)
          RefreshTokenManager.default.checkRefreshingToken(api: api, callback: comp)
          return
        } else {
          callback(.continue)
        }
        
      } catch {
        callback(.continue)
      }
    }
    
    
    async let t1 = Network.request(api: Api.test1, forType: String.self)
    async let t2 = Network.request(api: Api.test2, forType: String.self)
    
    let c = await (t1,t2)
    print("========================")
    print(c)
    print("++++++++++++++++++++++++")
  }
  
  func testDefaultValue() {
    struct T: Codable {
      struct UserInfo: Codable, CustomDefaultValue {
        static var defaultValue = T.UserInfo()
        typealias Value = Self
        
        @Empty var id: String
        @Empty var list: [String]
        @Zero var age: Int
        @Zero var score: Double
        
      }
      
      @Empty var desc: String
      @False var isVip: Bool
      @CustomValue var userInfo: UserInfo
    }
    
    let json = """
    {
    "desc": null,
    "isVip": true,
    "userInfo": {
    "id": "xxxx",
    "list": ["xxx"]
    }
    }
    """
    let data = json.data(using: .utf8)!
    do {
      let model = try JSONDecoder().decode(T.self, from: data)
      print(model)
    } catch {
      XCTFail("\(error)")
    }
  }
}
