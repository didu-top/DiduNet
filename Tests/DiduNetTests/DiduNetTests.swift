import XCTest
@testable import DiduNet
import RxSwift

class TokenRefreshManager {
  
  var que = DispatchQueue(label: "com.didunet.token-refresh")
  
  var list: [Any] = []
  
  func refreshToken() {
    
  }

  
}

struct Api: CachableTarget {
  var baseURL: URL = URL(string: "http://192.168.194.52:8000")!
  
  var path: String = "/test3.json"
  
  var method: Moya.Method = .get
  
  var task: Moya.Task = .requestPlain
  
  var headers: [String : String]? = nil
  
  
}
struct ResponseModel<T>: Codable where T: Codable {
  var code: Int
  var message: String?
  var result: T?
}


final class DiduNetTests: XCTestCase {
    func testExample() async throws {
      Network.golbalCatchHttpCodeList = [401, 404]
      Network.globalCatchHttpErrorCodeAction =  {
        (api, code, callback) in
        print("--- \(code)")
//        callback(false)
      }
//      let t = await Network.request(api: Api(), forType: Int.self)
      let t = await Network.request(api: Api(), forResponse: ResponseModel<String>.self)
      print(t)
      if case .failure(let err) = t {
        
        if err.code != .cancel {
          XCTFail()
        }
      }
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
