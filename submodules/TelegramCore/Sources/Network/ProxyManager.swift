import Foundation
import SwiftSignalKit
import MtProtoKit

public class ProxyManager {

    // 同步版本
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
    public static func fetchProxyServersAsSignal() -> Signal<[ProxyServer], Error> {
        return Signal { subscriber in
            let url = URL(string: "https://api.currytech.cn/servers")!
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
                
                do {
                    let decoder = JSONDecoder()
                    let proxyServers = try decoder.decode([ProxyServer].self, from: data)
                    subscriber.putNext(proxyServers)
                    subscriber.putCompletion()
                } catch {
                    subscriber.putError(error)
                }
            }
            
            task.resume()
            
            return ActionDisposable {
                task.cancel()
            }
        }
    }

    // 
    // returns a Promise that resolves with an array of ProxyServer objects
    // fetchProxyServers().done { proxyServers in
    //     // Do something with the proxy servers
    // }.catch { error in
    //     // Handle the error
    // }
    // public static func fetchProxyServersAsPromise() -> Promise<[ProxyServer]> {
    //     return Promise { seal in
    //         let url = URL(string: "https://example.com/servers")!
    //         var request = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalCacheData, timeoutInterval: Double.infinity)
    //         let headers = ["Content-Type": "application/json"]
    //         request.allHTTPHeaderFields = headers
    //         request.httpMethod = "GET"
    //         let task = URLSession.shared.dataTask(with: request) { data, response, error in
    //             if let error = error {
    //                 seal.reject(error)
    //                 return
    //             }

    //             guard let httpResponse = response as? HTTPURLResponse else {
    //                 seal.reject(nil)
    //                 return
    //             }

    //             guard (200...299).contains(httpResponse.statusCode) else {
    //                 // Handle server error
    //                 seal.reject(nil)
    //                 return
    //             }

    //             guard let data = data else {
    //                 seal.reject(nil)
    //                 return
    //             }

    //             do {
    //                 let decoder = JSONDecoder()
    //                 let proxyServers = try decoder.decode([ProxyServer].self, from: data)
    //                 seal.fulfill(proxyServers)
    //             } catch {
    //                 seal.reject(error)
    //             }
    //         }

    //         task.resume()
    //     }
    // }


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

            // if settings.activeServer == nil || settings.servers.count > 0 {
            //     settings.enabled = true
            //     settings.activeServer = settings.servers[0]
            // }
            if settings.effectiveActiveServer == nil || settings.servers.count > 0 {
                settings.enabled = true
                settings.activeServer = settings.servers.randomElement()
            }

            return settings
        }) |> deliverOnMainQueue).start(completed: {
            debugPrint("proxy list updated")
        })
    }

    // Signal版本
    public static func setProxyServersAsync(accountManager: AccountManager<TelegramAccountManagerTypes>, proxyServerList: [ProxyServer]) -> Signal<Bool, NoError> {
        let accountManager = accountManager
        debugPrint("accountManager:", accountManager)
        // add to proxy list
        return (updateProxySettingsInteractively(accountManager: accountManager, { settings in
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

                // if settings.activeServer == nil || settings.servers.count > 0 {
                //     settings.enabled = true
                //     settings.activeServer = settings.servers[0]
                // }
                if settings.effectiveActiveServer == nil || settings.servers.count > 0 {
                    settings.enabled = true
                    settings.activeServer = settings.servers.randomElement()
                }

                return settings
            })
        )
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