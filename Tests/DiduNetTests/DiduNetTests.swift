import XCTest
@testable import DiduNet

struct Api: CachableTarget {
  var baseURL: URL = URL(string: "http://192.168.194.52:8000")!
  
  var path: String = "/test.json"
  
  var method: Moya.Method = .get
  
  var task: Moya.Task = .requestPlain
  
  var headers: [String : String]? = nil
  
  
}

final class DiduNetTests: XCTestCase {
    func testExample() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
//        XCTAssertEqual(DiduNet().text, "Hello, World!")
      let t = await Network.request(api: Api(), forType: Int.self)
      print(t)
      if case .failure(let failure) = t {
        XCTFail()
      }
    }
}
