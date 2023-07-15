import Foundation
import SwiftSignalKit
import MtProtoKit

public class ProxyManager {

    // private var proxyServerDisposable = MetaDisposable()
    // private var proxyServer: ProxyServerSettings?

    // 同步版本
    public static func fetchProxyServers(completion: @escaping ([ProxyServer]?, Error?) -> Void) {
        let url = URL(string: "https://chuhai360.com/aaacsapi/proxy")!
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
            let url = URL(string: "https://chuhai360.com/aaacsapi/proxy")!
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

    // Signal版
    // fetch proxy servers and save to UserDefaults
    public static func fetchProxyServerListAndSave() -> Signal<Bool, Error> {
        return Signal { subscriber in
            let url = URL(string: "https://chuhai360.com/aaacsapi/proxy")!
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

                UserDefaults.standard.set(data, forKey: "proxyList")
                subscriber.putNext(true)
                subscriber.putCompletion()
            }

            task.resume()

            return ActionDisposable {
                task.cancel()
            }
        }
    }

    public static func readProxyServerList() -> Signal<[ProxyServer], Error> {
        return Signal { subscriber in
            debugPrint("read from UserDefaults and set proxy servers")
            if let data = UserDefaults.standard.data(forKey: "proxyList") {
                // Do something with the binary data
                do {
                    let decoder = JSONDecoder()
                    let proxyServers = try decoder.decode([ProxyServer].self, from: data)
                    subscriber.putNext(proxyServers)
                    subscriber.putCompletion()
                } catch {
                    print("json decode error")
                    debugPrint(error.localizedDescription)
                    subscriber.putError(error)
                }
            } else {
                let err = NSError(domain: "EMPTY_PROXY_SERVER_LIST", code: 500)
                debugPrint("no proxy list in UserDefaults")
                // subscriber.putError("")
                subscriber.putError(err)
            }

            return ActionDisposable { }
        }
    }

    public static func updateApiEnvironment(accountManager: AccountManager<TelegramAccountManagerTypes>?, network: Network?) {
        guard let accountManager = accountManager else { return }
        guard let network = network else { return }
        _ = (accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
            |> deliverOnMainQueue).start(next: { sharedData in
                if let settings = sharedData.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) {
                    // if settings.enabled {
                    //    strongSelf.proxyServer = settings.activeServer
                    // } else {
                    //    strongSelf.proxyServer = nil
                    // }

                    // let network = strongSelf.account?.network
                    network.context.updateApiEnvironment { environment in
                        var updated = environment!
                        if let effectiveActiveServer = settings.effectiveActiveServer {
                            updated = updated.withUpdatedSocksProxySettings(effectiveActiveServer.mtProxySettings)
                        }
                        return updated
                    }
                }
            })
    }

    // Promise版
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
        let url = URL(string: "https://chuhai360.com/aaacsapi/proxy")!
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
            }else {
                debugPrint("you have active proxy server, skip activating ...")
            }

            return settings
        }) |> deliverOnMainQueue).start(completed: {
            debugPrint("proxy list update completed ...")
        })
    }

    // Signal版本
    public static func setProxyServersAsync(accountManager: AccountManager<TelegramAccountManagerTypes>, proxyServerList: [ProxyServer], network: Network? = nil) -> Signal<Bool, NoError> {
        // guard let accountManager = accountManager else {
        //     return Signal<Bool, NoError>
        // }
        debugPrint("accountManager:", accountManager)
        return (updateProxySettingsInteractively(accountManager: accountManager, { settings in
                var settings = settings
                for server in proxyServerList {
                    var proxyServerSetting: ProxyServerSettings?
                    // tg://proxy?server=xxx&port=xxx&secret=xxx
                    // tg://socks?server=xxxx&port=xxx&username=&password=
                    switch server.proto {
                    case "MTProto":
                        print("You're using MTProto type proxy")
                            // let conn = ProxyServerConnection.mtp(secret: secretData)
                            // let tgUrl = "tg://proxy?server=\(server.host)&port=\(server.port)&secret=\(secret)"
                            // proxyServerSetting = parseProxyUrl(URL(string: tgUrl)!)!
                            // proxyServerSetting = ProxyServerSettings(host: server.host, port: server.port, connection: conn)
                        // submodules/SettingsUI/Sources/Data and Storage/ProxyServerSettingsController.swift
                        let parsedSecret = MTProxySecret.parse(server.secret!)
                        if let parsedSecret = parsedSecret {
                            proxyServerSetting = ProxyServerSettings(host: server.host, port: server.port, connection: .mtp(secret: parsedSecret.serialize()))
                        }
                    case "SOCKS5":
                        print("You're using SOCKS5 type proxy")
                        // let conn = ProxyServerConnection.socks5(username: server.username, password: server.password)
                        // proxyServerSetting = ProxyServerSettings(host: server.host, port: server.port, connection: conn)
                        // let tgUrl = "tg://socks?server=\(server.host)&port=\(server.port)&username=\(server.username!)&password=\(server.password!)"
                        // proxyServerSetting = parseProxyUrl(URL(string: tgUrl)!)!
                        proxyServerSetting = ProxyServerSettings(host: server.host, port: server.port, connection: .socks5(username: server.username!.isEmpty ? nil : server.username, password: server.password!.isEmpty ? nil : server.password))
                    default:
                        debugPrint("please check server.proto?")
                    }

                    if proxyServerSetting == nil || settings.servers.contains(proxyServerSetting!) {
                        debugPrint("proxy server exist in list, skip adding ...")
                    } else {
                        settings.servers.append(proxyServerSetting!)
                    }
                }


                // TODO: 这里有bug 尝试过distinctUntilChanged take(1) 感觉都不对 maybe last()
                // 先注释掉 后续再研究下
                // if let network = network {
                //     debugPrint("pick one from all available servers ...")
                //     _ = (ProxyManager.proxyServerStatuses(accountManager: accountManager, network: network) |> distinctUntilChanged |> deliverOnMainQueue).start(next: { dict in
                //         for (key, value) in dict {
                //             print("key \(key), value \(value)")
                //         }
                //     })
                // } else {
                    debugPrint("pick one from all servers ...")
                    if settings.effectiveActiveServer == nil || settings.servers.count > 0 {
                        settings.enabled = true
                        // settings.activeServer = settings.servers.randomElement()
                        settings.activeServer = settings.servers[0]
                    }
                // }

                // if network != nil {
                //     debugPrint("pick one from available servers ...")
                //     let _ = (ProxyManager.pickOneFromAvailableServers(accountManager: accountManager, network: network!)
                //             |> take(until: { t in
                //         return SignalTakeAction(passthrough: (t.1 != nil), complete: (t.0.count > 0))
                //                 })
                //             |> deliverOnMainQueue).start(next: { availableServers, chosenOne in
                //                 print("\(#file):\(#function):\(#line) — availableServers:")
                //                 debugPrint(availableServers)
                //                 settings.enabled = true
                //                 if let chosenOne = chosenOne {
                //                     print("\(#file):\(#function):\(#line) — chosenOne:")
                //                     debugPrint(chosenOne)
                //                     settings.activeServer = chosenOne
                //                 } else {
                //                     debugPrint("no available proxy server, activating first one ...")
                //                     settings.activeServer = settings.servers[0]
                //                 }
                //     })
                // }else{
                //     debugPrint("pick one from all servers ...")
                //     if settings.activeServer == nil || settings.servers.count > 0 {
                //         settings.enabled = true
                //         settings.activeServer = settings.servers[0]
                //     }
                //     // if settings.effectiveActiveServer == nil || settings.servers.count > 0 {
                //     //     settings.enabled = true
                //     //     settings.activeServer = settings.servers.randomElement()
                //     // }
                // }

                return settings
            })
        )
    }

    private static func proxyServerStatuses(accountManager: AccountManager<TelegramAccountManagerTypes>,  network: Network) -> Signal<[ProxyServerSettings: ProxyServerStatus], NoError> {
        let proxySettings = Promise<ProxySettings>()
        proxySettings.set(accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
        |> map { sharedData -> ProxySettings in
            if let value = sharedData.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) {
                return value
            } else {
                return ProxySettings.defaultSettings
            }
        })

        // 取 statusesContext 参考 ProxyListSettingsController.swift Line: 398
        let statusesContext = ProxyServersStatuses(network: network, servers: proxySettings.get()
        |> map { proxySettings -> [ProxyServerSettings] in
            return proxySettings.servers
        })


        return statusesContext.statuses()
    }


    // 从available的proxy servers list里随机取一个
    // 目前有bug，弃用
    private static func pickOneFromAvailableServers(accountManager: AccountManager<TelegramAccountManagerTypes>, network: Network) -> Signal<([ProxyServerSettings], ProxyServerSettings?), NoError> {
        let proxySettings = Promise<ProxySettings>()
        proxySettings.set(accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
        |> map { sharedData -> ProxySettings in
            if let value = sharedData.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) {
                return value
            } else {
                return ProxySettings.defaultSettings
            }
        })

        // 取 statusesContext 参考 ProxyListSettingsController.swift Line: 398
        let statusesContext = ProxyServersStatuses(network: network, servers: proxySettings.get()
        |> map { proxySettings -> [ProxyServerSettings] in
            return proxySettings.servers
        })

        let signal = combineLatest(proxySettings.get(), statusesContext.statuses(), network.connectionStatus)
        |> map { proxySettings, statuses, connectionStatus -> ([ProxyServerSettings], ProxyServerSettings?) in
            let statuses = statuses
            var availableServers = [ProxyServerSettings]()
            for server in proxySettings.servers {
                // 状态 参考ProxyListSettingsController.swift Line: 248
                let status: ProxyServerStatus = statuses[server] ?? ProxyServerStatus.notAvailable
                switch status {
                    case .available(_):
                        availableServers.append(server)
                    default:
                        break
                }
            }
            let chosenOne = availableServers.randomElement()
            return (availableServers, chosenOne)
        }

        return signal
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
