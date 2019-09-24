//
//  ZappCleengLogin.swift
//  CleengPluginExample
//
//  Created by Yossi Avramov on 30/05/2018.
//  Copyright © 2018 Applicaster. All rights reserved.
//

import Foundation
import ZappPlugins
import ZappLoginPluginsSDK
import ApplicasterSDK
import SwiftyStoreKit

/**
 Cleeng login plugin entry point.
 
 ## Responsibilities:
 - Check access status to one or more items.
 - Make login with Cleeng using Email & Password or Facebook
 - Purchase an IAP from Apple store and update Cleeng
 - Present on app launch when `cleeng_login_start_on_app_launch` is true
 
 ## Flow for item access validation:
 1. `isUserComply(policies:completion:)` is being called. `completion` block will be dispatched when verifying access to all items has finished. If has access to all items, `completion` block will be dispatched with true. Otherwise, it'll dispatched with false.
 2. When there's an item with no access `login(_:completion:)` will be called.
 3. If user is logged-in, the offers view controller will be presented. If user isn't logged-in, the root view controller (login/sign up/offers) to present depend the value in `cleeng_login_start_with_action` configuration flag.
 
 ## Flow when presenting on app launch:
 1. `executeAfterAppRootPresentation(displayViewController:completion)` is being called.
 2. Load all available offers. If has access to at least one offer, don't present plugin.
 3. If no access to any offer, presen plugin.
 4. If user is logged-in, the offers view controller will be presented. If user isn't logged-in, the root view controller (login/sign up/offers) to present depend the value in `cleeng_login_start_with_action` configuration flag.
 */
@objc public class ZappCleengLogin : NSObject, ZPLoginProviderUserDataProtocol, ZPAppLoadingHookProtocol,ZPAdapterProtocol {
    
    enum CleengPurchaseItemType {
        case purchasableItem
        case atomEntry
    }
    
    /// Cleeng publisher identifier. **Required**
    private var publisherId: String!
    
    /// Plugin configuration json. See plugin manifest for the list of available configuration flags
    public var configurationJSON: NSDictionary?
    
    /// A map of items to check if access granted or not
    private var apiForItem: [AnyHashable? : CleengLoginAndSubscribeApi] = [:]
    
    /// The current presented view controller to make login and/or IAP purchase for one item
    private var controller: CleengLoginAndSubscriptionController!
    
    /// The configuration model
    public var configuration: ZappCleengConfiguration?
    
    /// Cleeng purchase item type
    private(set) var purchaseItemType: CleengPurchaseItemType?
    
    public required override init() {
        super.init()
    }
    
    public required init(configurationJSON: NSDictionary?) {
        
        let publisherId: String! = configurationJSON?["cleeng_login_publisher_id"] as? String
        assert(publisherId != nil, "'cleeng_login_publisher_id' is mandatory")
        
        super.init()
        self.publisherId = publisherId
        
        let _ = StoreProductsPurchaseManager.shared
        self.configurationJSON = configurationJSON
        self.configuration = ZappCleengConfiguration(configuration: (configurationJSON as? [String:Any]) ?? [:])
    }
    
    //MARK: - ZPAdapterProtocol
    
    public func handleUrlScheme(_ params: NSDictionary) {
        let pluginModel = ZPPluginManager.pluginModels()?.filter { $0.pluginType == .Login}.first
        if let screenModel = ZAAppConnector.sharedInstance().genericDelegate.screenModelForPluginID(pluginID: pluginModel?.identifier, dataSource: nil) {
            ZAAppConnector.sharedInstance().genericDelegate.hookManager().performPreHook(hookedViewController:self as? UIViewController, screenID:screenModel.screenID , model: nil) { continueFlow in
                if continueFlow {
                    self.login(nil) { (loginStatus) in
                        if let vc = self.controller?.presentingViewController {
                            vc.dismiss(animated: true, completion: nil)
                        }
                        if loginStatus == .completedSuccessfully {
                            
                        } else if loginStatus == .failed {
                            
                        } else if loginStatus == .cancelled {
                            
                        }
                    }
                } else {
                    let currentViewController = ZAAppConnector.sharedInstance().navigationDelegate.currentViewController()
                    if let currentViewController = currentViewController as? ZPPlugableScreenDelegate {
                        currentViewController.removeScreenPluginFromNavigationStack()
                    } else {
                        ZAAppConnector.sharedInstance().navigationDelegate.navigateToHomeScreen()
                    }
                }
            }
        }
    }
    
    //MARK: - ZPLoginProviderUserDataProtocol
    
    /// A map of closures to call on verify completion
    private var verifyCalls: [String:((Bool) -> ())] = [:]
    
    /**
     `ZPLoginProviderUserDataProtocol` api. Call this to check if user has access to one or more items.
     */
    
    public func isUserComply(policies: [String : NSObject]) -> Bool {
        var retVal = false
        isUserComply(policies: policies,completion: { (isComply) in
             retVal = isComply
        })
        return retVal
    }
    
    public func isUserComply(policies: [String : NSObject], completion: @escaping (Bool) -> ()) {
        var playableItems : [AnyObject] = []
        if let items = policies["playable_items"] as? [APPurchasableItem] {
            purchaseItemType = .purchasableItem
            playableItems.append(contentsOf: items)
        } else if let atomItems = policies["playable_items"] as? [APAtomEntryPlayable] {
            purchaseItemType = .atomEntry
            playableItems.append(contentsOf: atomItems)
        } else if let atomItems = policies["playable_items"] as? [APAtomEntry] {
            purchaseItemType = .atomEntry
            playableItems.append(contentsOf: atomItems)
        }
        else if let vodItemID = policies["vod_item_id"] as? String {
            purchaseItemType = .purchasableItem
            playableItems.append(APVodItem(uniqueID: vodItemID))
        } else {
            completion(false)
            return
        }
        
        let callId = UUID().uuidString
        verifyCalls[callId] = completion
        
        //Check if item is loaded
        if let item = playableItems.first,
            purchaseItemType == .purchasableItem,
            let playableItem: APPurchasableItem = item as? APPurchasableItem,
            playableItem.isLoaded() == false,
            playableItem.object == nil {
            
            playableItem.load { (success, model) in
                if playableItem.isFree() {
                    completion(true)
                } else {
                    
                    //Verify access for each item
                    var canUpdateOnFailure = false
                    var itemsForSuccess: [AnyObject] = []
                    for item in playableItems {
                        let res = self.addVerifyUserCall(forItem: item, allItems: playableItems, callId: callId)
                        if res.canUpdateFailure {
                            canUpdateOnFailure = true
                        } else if res.canUpdateSuccess {
                            itemsForSuccess.append(item)
                        }
                    }
                    
                    if canUpdateOnFailure {
                        self.verifyCalls[callId] = nil
                        completion(false)
                    } else if playableItems.count == itemsForSuccess.count {
                        self.verifyCalls[callId] = nil
                        completion(true)
                    }
                }
            }
        } else {
            
            //Verify access for each item
            var canUpdateOnFailure = false
            var itemsForSuccess: [AnyObject] = []
            for item in playableItems {
                let res = addVerifyUserCall(forItem: item, allItems: playableItems, callId: callId)
                if res.canUpdateFailure {
                    canUpdateOnFailure = true
                } else if res.canUpdateSuccess {
                    itemsForSuccess.append(item)
                }
            }
            
            if canUpdateOnFailure {
                verifyCalls[callId] = nil
                completion(false)
            } else if playableItems.count == itemsForSuccess.count {
                verifyCalls[callId] = nil
                completion(true)
            }
        }
    }
    
    /**
     Start silent verification for a specific item.
     
     - Parameter item: The item to check if user has access or not
     - Parameter allItems: The list of all items to verify before calling completion
     - Parameter callId: UUID to get the completion block from `self.verifyCalls`
     
     - Returns: A flag indicating if has access to item & a flag indicating if failed to check item's access status
     */
    private func addVerifyUserCall(forItem item: AnyObject, allItems: [AnyObject], callId: String) -> (canUpdateSuccess: Bool, canUpdateFailure: Bool) {
        
        
        let api: CleengLoginAndSubscribeApi
        if let itemAPI = apiForItem[item as? AnyHashable] {
            api = itemAPI
        } else {
            api = CleengLoginAndSubscribeApi(item: item, publisherId: publisherId)
            apiForItem[item as? AnyHashable] = api
        }
        
        let onRefresh: RefreshTokenEnded = { [weak self] (isLoggedIn) in
            self?.vertifyUserComply(items: allItems, callId: callId)
        }
        
        if api.onRefreshToken(onRefresh) == false { //No need to refresh token
            if api.hasAuthorizationTokenForCurrentItem {
                return (canUpdateSuccess: true, canUpdateFailure: false)
            } else {
                return (canUpdateSuccess: false, canUpdateFailure: true)
            }
        }
        
        return (canUpdateSuccess: false, canUpdateFailure: false)
    }
    
    /**
     This will be called when the token has been refreshed.
     */
    private func vertifyUserComply(items: [AnyObject], callId: String) {
        guard let completion = verifyCalls[callId] else { return }
        
        var itemsForSuccess: [AnyObject] = []
        var hasApisProcessing = false
        
        for item in items {
            if let api = apiForItem[item as? AnyHashable] {
                if api.hasAuthorizationTokenForCurrentItem {
                    itemsForSuccess.append(item)
                } else if api.cleengLoginState == .loadItem || api.cleengLoginState == .refreshingToken {
                    hasApisProcessing = true
                }
            } else {
                let res = addVerifyUserCall(forItem: item, allItems: items, callId: callId)
                if res.canUpdateFailure {
                } else if res.canUpdateSuccess {
                    itemsForSuccess.append(item)
                } else {
                    hasApisProcessing = true
                }
            }
        }
        
        guard !hasApisProcessing else {
            return
        }
        
        verifyCalls[callId] = nil
        if itemsForSuccess.count == items.count {
            completion(true)
        } else {
            completion(false)
        }
    }
    
    /**
     `ZPLoginProviderUserDataProtocol` api. Call this to present UI to let user make login (if needed) and IAP purchase (if needed).
     */
    public func login(_ additionalParameters: [String : Any]?, completion: @escaping ((ZPLoginOperationStatus) -> Void)) {
        var playableItems : [AnyObject] = []
        
        if let items = additionalParameters?["playable_items"] as? [APPurchasableItem] {
            playableItems.append(contentsOf: items)
        } else if let items = additionalParameters?["playable_items"] as? [APAtomEntryPlayable] {
            playableItems.append(contentsOf: items)
        } else if let vodItemID = additionalParameters?["vod_item_id"] as? String {
            playableItems.append(APVodItem(uniqueID: vodItemID))
        } else {
            // no item to purchase - only log in.
        }
        
        let api: CleengLoginAndSubscribeApi!
        if let item = playableItems.first {
            if let itemAPI = apiForItem[item as? AnyHashable] {
                api = itemAPI
            } else {
                api = CleengLoginAndSubscribeApi(item: item, publisherId: publisherId)
                apiForItem[item as? AnyHashable] = api
            }
        } else {
            api = CleengLoginAndSubscribeApi(item: nil, publisherId: publisherId)
            apiForItem[nil] = api
        }
        
        if let controller = controller {
            if controller.api !== api {
                if let vc = controller.presentingViewController {
                    vc.dismiss(animated: true, completion: nil)
                }
                
                self.controller = nil
            }
            
            controller.viewControllers = []
            controller.completion = nil
        }
        
        api.isPerformingAuthorizationFlow = true
        let onCompletion: ((ZPLoginOperationStatus) -> Void) = { [weak self] status in
            if let strongSelf = self {
                strongSelf.apiForItem[playableItems.first as? AnyHashable] = nil
            }
            
            completion(status)
        }
        
        
        var needToCallAuthenticate = false
        var needToCallFailureOnItemLoad = false
        if api.cleengLoginState == .loadItem || api.cleengLoginState == .refreshingToken {
            //Api is refreshing Cleeng token or loading item data. Show `_ApiRefreshTokenViewController` with activity indicator & wait.
            
            //On refresh end, check access to item. If no access, show [login/signup/offers list to purchase] view controller.
            let _ = api.onRefreshToken { [weak self, weak api] _ in
                guard let strongSelf = self ,let api = api else { return }
                
                if api.cleengLoginState == .failedToLoadItemData {
                    
                    //Item couldn't be loaded. Present error
                    if let _ = strongSelf.controller!.presentingViewController {
                        let vc = _ApiRefreshTokenViewController()
                        strongSelf.controller!.viewControllers = [vc]
                        
                        let title = strongSelf.configuration?.localization.localizedString(for: .errorInternalTitle, defaultString: NSLocalizedString("Error", comment: "Error"))
                        let message = strongSelf.configuration?.localization.localizedString(for: .errorInternalMessage)
                        strongSelf.controller!.fatalErrorOccured(withTitle: title, message: message, suggestContact: true)
                    } else if let corrdinator = strongSelf.controller!.transitionCoordinator {
                        let title = strongSelf.configuration?.localization.localizedString(for: .errorInternalTitle, defaultString: NSLocalizedString("Error", comment: "Error"))
                        let message = strongSelf.configuration?.localization.localizedString(for: .errorInternalMessage)
                        
                        corrdinator.animate(alongsideTransition: nil, completion: { _ in
                            if let _ = strongSelf.controller!.presentingViewController {
                                strongSelf.controller!.fatalErrorOccured(withTitle: title, message: message, suggestContact: true)
                            }
                        })
                    } else {
                        needToCallFailureOnItemLoad = true
                    }
                    
                } else if api.hasAuthorizationTokenForCurrentItem {
                    
                    //Has access to item. Show `success` message
                    if let _ = strongSelf.controller!.presentingViewController {
                        let vc = _ApiRefreshTokenViewController()
                        strongSelf.controller!.viewControllers = [vc]
                        strongSelf.controller!.authenticated(with: .unknown)
                    } else if let corrdinator = strongSelf.controller!.transitionCoordinator {
                        corrdinator.animate(alongsideTransition: nil, completion: { _ in
                            if let _ = strongSelf.controller!.presentingViewController {
                                strongSelf.controller!.authenticated(with: .unknown)
                            }
                        })
                    } else {
                        needToCallAuthenticate = true
                    }
                } else {
                    
                    //No access to item. Show [login/signup/offers list to purchase]
                    var params = additionalParameters ?? [:]
                    if api.cleengLoginState == .loggedIn {
                        params["cleeng_login_start_with_action"] = "subscriptions_list"
                    }
                    
                    strongSelf.showViewControllerForLogin(api: api, additionalParameters: params, completion: onCompletion)
                }
            }
            
            if controller == nil {
                controller = CleengLoginAndSubscriptionController(startWith: .signIn, api: api, configuration: configuration)
            }
            
            controller.completion = onCompletion
            
            let vc = _ApiRefreshTokenViewController()
            controller.viewControllers = [vc]
            controller.showLoading(for: vc)
            
        } else { //Item is loaded and no token or token refreshed
            
            if api.cleengLoginState == .loggedIn {
                if api.hasAuthorizationTokenForCurrentItem {
                    if controller == nil {
                        controller = CleengLoginAndSubscriptionController(startWith: .none, api: api, configuration: configuration)
                    }
                    
                    let vc = _ApiRefreshTokenViewController()
                    controller.viewControllers = [vc]
                    
                    needToCallAuthenticate = true
                } else {
                    var params = additionalParameters ?? [:]
                    params["cleeng_login_start_with_action"] = "subscriptions_list"
                    showViewControllerForLogin(api: api, additionalParameters: params, completion: onCompletion)
                }
                
            } else {
                showViewControllerForLogin(api: api, additionalParameters: additionalParameters, completion: onCompletion)
            }
        }
        
        var onPresentCompletion: (() -> Void)?
        if needToCallAuthenticate {
            
            //Need to present modal view and when presentation animation failed, present success message
            onPresentCompletion = { [weak controller] in
                DispatchQueue.main.async {
                    controller?.authenticated(with: .unknown)
                }
            }
        } else if needToCallFailureOnItemLoad {
            
            //Need to present modal view and when presentation animation failed, present failure alert
            onPresentCompletion = { [weak controller] in
                DispatchQueue.main.async {
                    if let controller = controller {
                        let title = controller.localizedString(for: .errorInternalTitle, defaultString: NSLocalizedString("Error", comment: "Error"))
                        let message = controller.localizedString(for: .errorInternalMessage)
                        controller.fatalErrorOccured(withTitle: title, message: message, suggestContact: true)
                    }
                }
            }
        }
        
        if controller.presentingViewController == nil {
            UIViewController.topMostViewController?.present(controller, animated: true, completion: onPresentCompletion)
        }
    }
    
    /// Set the appropriate view controller on presneted controller depend the login status and configuration flag
    private func showViewControllerForLogin(api: CleengLoginAndSubscribeApi, additionalParameters: [String : Any]?, completion: @escaping ((ZPLoginOperationStatus) -> Void)) {
        let startWithActionString = (additionalParameters?["cleeng_login_start_with_action"] as? String) ?? (configurationJSON?["cleeng_login_start_with_action"] as? String)
        let startWithAction: CleengLoginAndSubscriptionLaunch
        switch startWithActionString {
        case "sign_in":
            startWithAction = .signIn
        case "sign_up":
            startWithAction = .signUp
        case "subscriptions_list":
            startWithAction = .subscriptionsList
        default:
            startWithAction = .signIn
        }
        
        if controller == nil {
            controller = CleengLoginAndSubscriptionController(startWith: startWithAction, api: api, configuration: configuration)
        } else {
            switch startWithAction {
            case .signIn:
                controller.showSignIn(animated: false, makeRoot: true)
            case .signUp:
                controller.showSignUp(animated: false, makeRoot: true)
            case .subscriptionsList:
                controller.showSubscriptionsList(animated: false, makeRoot: true)
            default: break
            }
        }
        
        controller.completion = completion
    }
    
    /**
     `ZPLoginProviderUserDataProtocol` api. Call this to logout from Cleeng.
     */
    public func logout(_ completion: @escaping ((ZPLoginOperationStatus) -> Void)) {
        let apis = apiForItem
        self.apiForItem = [:]
        for (_, api) in apis {
            api.logout()
        }
        
        CleengLoginAndSubscribeApi.currentCleengUser = nil
        completion(.completedSuccessfully)
    }
    
    public func isAuthenticated() -> Bool {
        return false
    }
    
    /**
     `ZPLoginProviderUserDataProtocol` api. Check if there currently UI presented to make login or IAP purchase for an item
     */
    public func isPerformingAuthorizationFlow() -> Bool {
        var hasOneApiActive: Bool = false
        for (_, api) in apiForItem {
            if api.isPerformingAuthorizationFlow {
                hasOneApiActive = true
                break
            }
        }
        
        return hasOneApiActive
    }
    
    public func getUserToken() -> String {
        return apiForItem.first?.value.defaultToken ?? CleengLoginAndSubscribeApi.currentCleengUser?.token ?? ""
    }
    
    public func getApi() -> CleengLoginAndSubscribeApi? {
        return apiForItem.first?.value
    }
    
    //MARK: - ZPAppLoadingHookProtocol
    public func executeAfterAppRootPresentation(displayViewController: UIViewController?, completion: (() -> Swift.Void)?) {
        guard let startOnAppLaunch = configurationJSON?["cleeng_login_start_on_app_launch"] else {
            completion?()
            return
        }
        
        var presentLogin = false
        if let flag = startOnAppLaunch as? Bool {
            presentLogin = flag
        } else if let num = startOnAppLaunch as? Int {
            presentLogin = (num == 1)
        } else if let str = startOnAppLaunch as? String {
            presentLogin = (str == "1")
        }
        
        if presentLogin {
            let item = EmptyAPPurchasableItem()
            self.login(["playable_items" : [item]], completion: { [weak self] _ in
                
                if let vc = self?.controller?.presentingViewController {
                    vc.dismiss(animated: true, completion: completion)
                } else {
                    completion?()
                }
            })
        } else {
            completion?()
        }
    }
}


//MARK: - Utils private classes
/**
 An empty view controller to present when verifying cached token. The view controller has background image and its overlay dimming color
 */
private class _ApiRefreshTokenViewController : UIViewController {
    private var imageView: UIImageView!
    private var overlay: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView = UIImageView(frame: view.bounds)
        overlay = UIView(frame: view.bounds)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        overlay.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(imageView)
        view.addSubview(overlay)
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[imageView]-0-|", options: [], metrics: nil, views: ["imageView" : imageView]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[imageView]-0-|", options: [], metrics: nil, views: ["imageView" : imageView]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[overlay]-0-|", options: [], metrics: nil, views: ["overlay" : overlay]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[overlay]-0-|", options: [], metrics: nil, views: ["overlay" : overlay]))
        
        if let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate {
            imageView.setupCleengBackground(with: stylesManager)
            overlay.setZappStyle(using: stylesManager,
                                 withBackgroundColor: .backgroundColor)
        }
    }
}

/**
 An object to use when plugin presented on app launch (without any item to be played), since *ZappCleengLogin* requires at least one item.
 */
private class EmptyAPPurchasableItem : APPurchasableItem {
    override var authorizationProvidersIDs: NSArray! {
        return []
    }
    
    override func isLoaded() -> Bool {
        return true
    }
}
