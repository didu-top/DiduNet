import XCTest
@testable import DiduNet

struct Api: CachableTarget {
  var baseURL: URL = URL(string: "http://192.168.194.52:8000")!
  
  var path: String = "/test2.json"
  
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

//      let t = await Network.request(api: Api(), forType: Int.self)
      let t = await Network.request(api: Api(), forResponse: ResponseModel<String>.self)
      print(t)
      if case .failure(let failure) = t {
        XCTFail()
      }
    }
}
