import Foundation
import SwiftSignalKit
import MtProtoKit

public class ProxyManager {

    public static func fetchProxyServers(completion: @escaping ([ProxyServer]?, Error?) -> Void) {
        let url = URL(string: "https://api.currytech.cn/servers")!
        var request = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: Double.infinity)
        let headers = ["Content-Type": "application/json"]
        request.allHTTPHeaderFields = headers
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(nil, nil)
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Handle server error
                completion(nil, nil)
                return
            }

            guard let data = data else {
                completion(nil, nil)
                return
            }

            do {
                let decoder = JSONDecoder()
                let proxyServers = try decoder.decode([ProxyServer].self, from: data)
                completion(proxyServers, nil)
            } catch {
                completion(nil, error)
            }
        }

        task.resume()
    }

    public static func fetechServerList(completion: @escaping (Data?, Error?) -> Void) {
        let url = URL(string: "https://api.currytech.cn/servers")!
        var request = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: Double.infinity)
        let headers = ["Content-Type": "application/json"]
        request.allHTTPHeaderFields = headers
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(nil, nil)
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Handle server error
                completion(nil, nil)
                return
            }

            guard let data = data else {
                completion(nil, nil)
                return
            }

            completion(data, nil)
            // do {
            //     let decoder = JSONDecoder()
            //     let proxyServers = try decoder.decode([ProxyServer].self, from: data)
            //     completion(proxyServers, nil)
            // } catch {
            //     completion(nil, error)
            // }
        }

        task.resume()
    }


    public static func setProxyServers(accountManager: AccountManager<TelegramAccountManagerTypes>, proxyServerList: [ProxyServer]) {
        let accountManager = accountManager
        debugPrint("accountManager:", accountManager)
        // clear proxy list in settings
        // let _ = updateProxySettingsInteractively(accountManager: accountManager, { settings in
        //     var settings = settings
        //     settings.servers.removeAll(keepingCapacity: true)
        //     return settings
        // }).start()

        // add to proxy list
        let _ = (updateProxySettingsInteractively(accountManager: accountManager, { settings in
            var settings = settings
            for server in proxyServerList {
                var proxyServerSetting: ProxyServerSettings?
                // tg://proxy?server=xxx&port=xxx&secret=xxx
                // tg://socks?server=xxxx&port=xxx&username=&password=
                switch server.proto {
                case "MTProto":
                    print("You're using MTProto type proxy")
                    let secret = server.secret ?? ""
                    if let secretData = secret.data(using: .utf8, allowLossyConversion: true) {
                        let conn = ProxyServerConnection.mtp(secret: secretData)
                        // let tgUrl = "tg://proxy?server=\(server.host)&port=\(server.port)&secret=\(secret)"
                        // proxyServerSetting = parseProxyUrl(URL(string: tgUrl)!)!
                        proxyServerSetting = ProxyServerSettings(host: server.host, port: server.port, connection: conn)                    
                    }
                case "SOCKS5":
                    print("You're using SOCKS5 type proxy")
                    let conn = ProxyServerConnection.socks5(username: server.username, password: server.password)
                    proxyServerSetting = ProxyServerSettings(host: server.host, port: server.port, connection: conn)
                    // let tgUrl = "tg://socks?server=\(server.host)&port=\(server.port)&username=\(server.username!)&password=\(server.password!)"
                    // proxyServerSetting = parseProxyUrl(URL(string: tgUrl)!)!
                default:
                    debugPrint("please check server.proto?")
                }
                
                if proxyServerSetting == nil || settings.servers.contains(proxyServerSetting!) {
                    debugPrint("proxy server exist in list, skip adding ...")
                } else {
                    settings.servers.append(proxyServerSetting!)
                }
            }

            if settings.activeServer == nil || settings.servers.count > 0 {
                settings.enabled = true
                settings.activeServer = settings.servers[0]
            }

            return settings
        }) |> deliverOnMainQueue).start(completed: {
            debugPrint("proxy list updated")
        })
    }
}

public struct ProxyServer: Decodable {
    let host: String
    let port: Int32
    let username: String?
    let password: String?
    let secret: String?
    let proto: String
}