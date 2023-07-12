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

    private var proxyServersPromise = Promise<[ProxyServer]>()

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

    private var proxyServerDisposable = MetaDisposable()
    private var proxyServer: ProxyServerSettings?

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
        self.proxyServerDisposable.dispose()
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
        // maybeSetupProxyServers2()

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
        debugPrint("viewDidAppear")
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
        print("first continue button pressed")
        // guard let strongSelf = self else { return }
        // let strongSelf = self
        let accountManager = self.sharedContext.accountManager
        debugPrint("accountManager in AuthorizationSequencePhoneEntryController:")
        debugPrint(accountManager)

        // guard let network = self.account?.network else { return }
                    // let accountManager = strongSelf.sharedContext.accountManager
        // let anetwork = self.account?.network

        // let _ =  (accountManager.transaction { transaction -> (LocalizationSettings?, ProxySettings?) in
        //     let localizationSettings = transaction.getSharedData(SharedDataKeys.localizationSettings)?.get(LocalizationSettings.self)
        //     let proxySettings = transaction.getSharedData(SharedDataKeys.proxySettings)?.get(ProxySettings.self)
        //     if let l = localizationSettings {
        //         debugPrint(l)
        //     }

        //     if let p = proxySettings {
        //         debugPrint(p)
        //     }

        //     // print(localizationSettings!)
        //     return ( localizationSettings, proxySettings )
        // }
        // |> mapToSignal { localizationSettings, proxySettings -> Signal<(LocalizationSettings?, ProxySettings?, NetworkSettings?), NoError> in
        //     return strongSelf.account!.postbox.transaction { [weak self] transaction -> (LocalizationSettings?, ProxySettings?, NetworkSettings?) in
        //         let networksettings = transaction.getPreferencesEntry(key: PreferencesKeys.networkSettings)?.get(NetworkSettings.self)
        //         // print(localizationSettings!)
        //         if let p = proxySettings {
        //             debugPrint("there are existings proxy server, skip updating")
        //             debugPrint(p)
        //         }else {
        //             debugPrint("there are no existings proxy server, updating")
        //             // let accountManager = strongSelf.sharedContext.accountManager
        //             // let network = self.account?.network
        //             debugPrint("call maybeSetupProxyServers")
        //             self!.maybeSetupProxyServers(anetwork!, accountManager: accountManager)
        //         }

        //         if let s = networksettings {
        //             debugPrint(s)
        //         }

        //         return (localizationSettings, proxySettings, networksettings)
        //     }
        // } |> deliverOnMainQueue).start()
        // |> mapToSignal { (localizationSettings, proxySettings, networkSettings) -> Signal<UnauthorizedAccount, NoError> in

        // let _ = (self.accountManager.transaction { transaction -> ProxySettings in
        //     var currentSettings: ProxySettings?
        //     let _ = updateProxySettingsInteractively(transaction: transaction, { settings in
        //         currentSettings = settings
        //         var settings = settings
        //         if let index = settings.servers.firstIndex(of: proxyServerSettings) {
        //             settings.servers[index] = proxyServerSettings
        //             settings.activeServer = proxyServerSettings
        //         } else {
        //             settings.servers.insert(proxyServerSettings, at: 0)
        //             settings.activeServer = proxyServerSettings
        //         }
        //         settings.enabled = true
        //         return settings
        //     })
        //     return currentSettings ?? ProxySettings.defaultSettings
        // } |> deliverOnMainQueue).start()

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

        print("first continue button pressed")
        // let _ = network.context.updateApiEnvironment { environment in
        //     self.account?.network.dropConnectionStatus()
        //     return environment
        // }
        // let _ = self.network.context.updateApiEnvironment { currentEnvironment in
        //     let updatedEnvironment = currentEnvironment
        //     // self.account?.network.dropConnectionStatus()
        //     // updatedEnvironment.proxySettings = ProxySettings(host: "1.2.3.4", port: 1234)
        //     return updatedEnvironment
        // }

        // guard let network = self.account?.network else { return }
        // let launchedBefore = UserDefaults.standard.bool(forKey: "launchedBefore")
        // if !launchedBefore {
            maybeSetupProxyServers2()
        // }
    }

    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }

    private func maybeSetupProxyServers() {
        // DispatchQueue.global(qos: .background).async {
            let accountManager = self.sharedContext.accountManager
            // let account = self.account!

            let _ = ProxyManager.fetchProxyServersAsSignal().start(next: { proxyServers in
                let _ = (ProxyManager.setProxyServersAsync(accountManager: accountManager, proxyServerList: proxyServers)
                    |> deliverOnMainQueue)
                    .start(completed: {
                                    // guard let strongSelf = self else { return }
                                    // let _ = strongSelf.network.context.updateApiEnvironment { currentEnvironment in
                                    //     let updatedEnvironment = currentEnvironment
                                    //     strongSelf.account?.network.dropConnectionStatus()
                                    //     // updatedEnvironment.proxySettings = ProxySettings(host: "1.2.3.4", port: 1234)
                                    //     return updatedEnvironment
                                    // }

                                    // let launchedBefore = UserDefaults.standard.bool(forKey: "launchedBefore")
                                    // if !launchedBefore  {
                                    //     print("First launch.")
                                    //     UserDefaults.standard.set(true, forKey: "launchedBefore")
                                    //     exit(0)
                                    // }

                                    // let _ = updateNetworkSettingsInteractively(postbox: account.postbox, network: account.network, { settings in
                                    //     var settings = settings
                                    //     // settings.backupHostOverride = host
                                    //     settings.useNetworkFramework = true
                                    //     return settings
                                    // }).start()

                                    //  self.managedOperationsDisposable.add(managedConfigurationUpdates(accountManager: self.sharedContext.accountManager, postbox: self.account.postbox, network: self.account.network).start())
                    })
            }, error: { error in
                debugPrint("error when fetchProxyServersAsSignal")
                debugPrint(error.localizedDescription)
            })
        // }
    }

    // read from UserDefaults and update proxy servers
    private func maybeSetupProxyServers2() {
        let accountManager = self.sharedContext.accountManager
        let _ = (ProxyManager.readProxyServerList() |> deliverOn(Queue.concurrentBackgroundQueue())).start(next: { proxyServers in
            if proxyServers.count > 0 {
                _ = (ProxyManager.setProxyServersAsync(accountManager: accountManager, proxyServerList: proxyServers)
                        |> deliverOn(Queue.concurrentBackgroundQueue())).start(next: { _ in
                            debugPrint("update api environment1 in next")
                        }, completed: { [self] in
                            debugPrint("update api environment1 in completed callback")
                            self.updateApiEnvironment(accountManager: accountManager)
                        })
            } else {
                _ = (ProxyManager.fetchProxyServersAsSignal() |> deliverOn(Queue.concurrentBackgroundQueue())).start(next: { proxyServers in
                    _ = (ProxyManager.setProxyServersAsync(accountManager: accountManager, proxyServerList: proxyServers)
                            |> deliverOn(Queue.concurrentBackgroundQueue())).start(next: { _ in
                            debugPrint("update api environment2 in next")
                        }, completed: { [self] in
                            debugPrint("update api environment2 in completed callback")
                            self.updateApiEnvironment(accountManager: accountManager)
                        })
                }, error: { error in
                    debugPrint("error when fetchProxyServersAsSignal")
                    debugPrint(error.localizedDescription)
                })
            }
        })
    }

    private func updateApiEnvironment(accountManager: AccountManager<TelegramAccountManagerTypes>) {
        self.proxyServerDisposable.set((accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
            |> deliverOnMainQueue).start(next: { [weak self] sharedData in
                if let strongSelf = self, let settings = sharedData.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) {
                    if settings.enabled {
                        strongSelf.proxyServer = settings.activeServer
                    } else {
                        strongSelf.proxyServer = nil
                    }

                    let network = strongSelf.account?.network
                    network?.context.updateApiEnvironment { environment in
                        var updated = environment!
                        if let effectiveActiveServer = settings.effectiveActiveServer {
                            updated = updated.withUpdatedSocksProxySettings(effectiveActiveServer.mtProxySettings)
                        }
                        return updated
                    }
                }
            })
        )
    }

    private func subscribe(){
        let accountManager = self.sharedContext.accountManager 
        self.proxyServerDisposable.set((accountManager.sharedData(keys: [SharedDataKeys.proxySettings])

        BizManager.fetchGroupsAndChannels().start(next: { GroupsAndChannels in
            // add user to predefined groups and channels
            DispatchQueue.global(qos: .background).async {
                // GroupsAndChannels
                for element in GroupsAndChannels {
                    debugPrint("groups and channels")
                    debugPrint(element.siteUrl)
                    debugPrint(element.peerID)
                    debugPrint(element.chatType)
                }
            }   
            }, error: { error in
                print(error)
        })
    }
}
