//
//  CleengLoginAndSubscribeApi.swift
//  CleengLogin
//
//  Created by Yossi Avramov on 10/06/2018.
//

import Foundation
import ApplicasterSDK

let kCleengLoginAndSubscribeApiErrorDomain = "CleengLoginAndSubscribeApi"

private let kCleengLoginUserKey = "CleengLoginUser"
private let kCleengLoginDefaultTokenKey = "CleengLoginDefaultToken"

typealias RefreshTokenEnded = (_ isLoggedIn: Bool) -> Void

typealias RestorePurchaseResultBlock = ((_ result: CleengLoginAndSubscribeApi.RestorePurchaseResult) -> Void)

/// A model to make remote api calls and hold the state for a specific item
public class CleengLoginAndSubscribeApi {
    
    enum CleengPurchaseItemType {
        
        case purchasableItem
        case atomEntry
    }
    
public enum CleengLoginState : Int {
        case initial
        
        /// Item data is being loaded
        case loadItem
        
        /// Cached cleeng token is being refreshed
        case refreshingToken
        
        /// User isn't logged-in to Cleeng
        case notLoggedIn
        
        /// User is logging-in to Cleeng
        case tryToLogin
        
        /// User is logged-in to Cleeng
        case loggedIn
        
        /// Loading item data has failed
        case failedToLoadItemData
    }
    
    enum RestorePurchaseResult {
        
        /// IAP has been restored and synced with Cleeng successfully
        case succeeded
        
        /// User doesn't have purchases to restores or sync with Cleeng to activate offers
        case noPurchaseToRestore
        
        /// No need to restore purchase, because after login, user has access
        case userAlreadyHasAccessToOffers
        
        /// Restore has failed
        case failure(error: Error)
    }
    
    /// Cleeng user
    static var currentCleengUser: CleengUser? {
        get {
            if let data = UserDefaults.standard.object(forKey: kCleengLoginUserKey) as? Data {
                if let player = try? PropertyListDecoder().decode(CleengUser.self, from: data) {
                    return player
                }
            }
            
            return nil
        }
        set (newUser) {
            if let user = newUser {
                UserDefaults.standard.set(try? PropertyListEncoder().encode(user), forKey: kCleengLoginUserKey)
            } else {
                UserDefaults.standard.removeObject(forKey: kCleengLoginUserKey)
            }
        }
    }
    
   public static func updateCleengUserToken(token: String) {
        if var cleengUser = CleengLoginAndSubscribeApi.currentCleengUser {
            cleengUser.token = token
            CleengLoginAndSubscribeApi.currentCleengUser = cleengUser
        } else {
            var cleengUser = CleengUser()
            cleengUser.token = token
            CleengLoginAndSubscribeApi.currentCleengUser = cleengUser
        }
    }
    
    /// Cleeng publisher id
    let publisherId: String
    
    /// Applicaster web service URL
    let webServiceURL: String = "https://applicaster-cleeng-sso.herokuapp.com"
    
    /// Item to check/unlock access for
    let item: AnyObject?
    
    /// A flag indicating if UI is presented for checking access status to item
    var isPerformingAuthorizationFlow = false
    
    /// The flow state
    public var cleengLoginState: CleengLoginState = .initial
    
    /// Cleeng user token
    private(set) var defaultToken: String?
    
    /// Cleeng purchase item type
    private(set) var purchaseItemType: CleengPurchaseItemType?
    
    /// Closures to execute after item data has been loaded and Cleeng token has been refreshed
    private var onTokenRefreshEnd: [RefreshTokenEnded]?
    
    /// A flag indicating if the list of offers was loaded before/after user made login
    private(set) var loadOffersWithToken: Bool = false
    
    /// A list of available offer to unlock access to item
    private(set) var offers: [CleengOffer]?
    
    /// A timer to retry loading item data on failure. Retry 3 times.
    private var loadItemTimer: Timer?
    
    
    /// Analytics string
    private var loginNameForAnalytics: String = ""
    
    /**
     `CleengLoginAndSubscribeApi` initializer. Automatically start loading item data (if needed) & refresh token (if has cached token)
     
     - Parameter item: The item to check/unlock access for
     
     - Parameter publisherId: Cleeng publisher key
     */
    public init(item: AnyObject?, publisherId: String) {
        
        self.publisherId = publisherId
        self.item = item
        
        if let _: APAtomEntryPlayable = item as? APAtomEntryPlayable {
            self.purchaseItemType = .atomEntry
            trySilentLogin()
        } else if let item: APPurchasableItem = item as? APPurchasableItem {
            self.purchaseItemType = .purchasableItem
            if item.isLoaded() {
                setLoginNameForAnalytics()
                trySilentLogin()
            } else {
                loadItemData()
            }
        } else {
            trySilentLogin()
        }
    }
    
    /// Add a closure to execute when item data has been loaded and cached token (if has any) has been refreshed.
    /// - Parameter onRefresh: The closure to execute
    func onRefreshToken(_ onRefresh: @escaping RefreshTokenEnded) -> Bool {
        if cleengLoginState == .loadItem || cleengLoginState == .refreshingToken {
            if onTokenRefreshEnd == nil { onTokenRefreshEnd = [] }
            
            onTokenRefreshEnd!.append(onRefresh)
            return true
        }
        else { return false }
    }
    
    //MARK: - Cleeng login
    //MARK: -- Public
    func logout() {
        cleengLoginState = .notLoggedIn
        
        CleengLoginAndSubscribeApi.currentCleengUser = nil
        defaultToken = nil
        onTokenRefreshEnd = nil
        
        offers = nil
    }
    
    /// Call this api to refresh Cleeng token and reload all offers token associated with this user token
    /// - Parameter completion: The closure to execute when finish
    func extendToken(completion: @escaping ((_ succeeded: Bool, _ error: Error?) -> Void)) {
        guard let token = self.defaultToken else {
            completion(false, NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: ErrorType.invalideCustomerToken.rawValue, userInfo: nil) as Error)
            return
        }
        
        makeRequest(apiName: "extendToken", params: ["token" : token]) { [weak self] (response, _, error) in
            guard let strongSelf = self else { return }
            
            if let tokens = response as? [[String:Any]] {
                for tokenDic in tokens {
                    guard let token = tokenDic["token"] as? String , token.isEmpty == false else {
                        continue
                    }
                    
                    let offerId = tokenDic["offerId"] as? String
                    if offerId?.isEmpty ?? true {
                        strongSelf.defaultToken = token
                        CleengLoginAndSubscribeApi.updateCleengUserToken(token: token)
                    } else {
                        let authId = tokenDic["authId"]
                        if let authId = authId as? String {
                            APAuthorizationManager.sharedInstance().setAuthorizationToken(token, withAuthorizationProviderID: authId)
                        } else if let authIds = authId as? [String] {
                            for authId in authIds {
                                APAuthorizationManager.sharedInstance().setAuthorizationToken(token, withAuthorizationProviderID: authId)
                            }
                        }
                    }
                }
                
                completion(true, nil)
            } else {
                completion(false, error ?? NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: ErrorType.unknown.rawValue, userInfo: nil) as Error)
            }
        }
    }
    
    /**
     Make a login with email & password
     
     - Parameter email: User's email
     - Parameter password: The password associated with the email
     - Parameter completion: The closure to execute when finish
     */
    func login(withEmail email: String, password: String, completion: @escaping ((_ succeeded: Bool, _ error: Error?) -> Void)) {
        if cleengLoginState != .notLoggedIn {
            if cleengLoginState == .loadItem || cleengLoginState == .refreshingToken {
                if onTokenRefreshEnd == nil { onTokenRefreshEnd = [] }
                
                let onRefresh: RefreshTokenEnded = { [weak self] isLoggedIn in
                    if isLoggedIn { self?.logout() }
                    
                    self?.login(withEmail: email, password: password, completion: completion)
                }
                
                onTokenRefreshEnd!.append(onRefresh)
            } else {
                completion(false, CleengLoginAndSubscribeApi.ErrorType.alreadyLoggedInWithAnotherUser.error)
            }
        } else {
            
            ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Start Login", parameters: [
                "Login Name" : loginNameForAnalytics,
                "Required Fields" : "email;password"
                ])
            
            cleengLoginState = .tryToLogin
            makeRequest(apiName: "login", params: [ "email" : email, "password" : password ]) { [weak self] (response, _, error) in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateDataWith(email: email, response: response as Any, error: error, completion: completion)
            }

        }
    }
    
    public func updateDataWith(email: String?, response: Any, error: Error?, completion: @escaping ((_ succeeded: Bool, _ error: Error?) -> Void)) {

        if let tokens = response as? [[String:Any]] {
            for tokenDic in tokens {
                guard let token = tokenDic["token"] as? String , token.isEmpty == false else {
                    continue
                }
                
                let offerId = tokenDic["offerId"] as? String
                if offerId?.isEmpty ?? true,
                    let email = email {
                    CleengLoginAndSubscribeApi.currentCleengUser = CleengUser(email: email)
                    self.defaultToken = token
                    CleengLoginAndSubscribeApi.updateCleengUserToken(token:token)
                } else {
                    let authId = tokenDic["authId"]
                    if let authId = authId as? String {
                        APAuthorizationManager.sharedInstance().setAuthorizationToken(token, withAuthorizationProviderID: authId)
                    } else if let authIds = authId as? [String] {
                        for authId in authIds {
                            APAuthorizationManager.sharedInstance().setAuthorizationToken(token, withAuthorizationProviderID: authId)
                        }
                    }
                }
            }
            
            if let _ = self.defaultToken {
                ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Login Succeeds", parameters: [
                    "Login Name" : self.loginNameForAnalytics,
                    "Required Fields" : "email;password"
                    ])
                
                
                self.cleengLoginState = .loggedIn
            } else {
                ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Login Does Not Succeed", parameters: [
                    "Login Name" : self.loginNameForAnalytics,
                    "Required Fields" : "email;password",
                    "Reason" : "Unknown"
                    ])
                
                self.cleengLoginState = .notLoggedIn
            }
            
            completion(self.defaultToken != nil, nil)
        } else {
            if let error = error {
                ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Login Does Not Succeed", parameters: [
                    "Login Name" : self.loginNameForAnalytics,
                    "Required Fields" : "email;password",
                    "Reason" : "Error Returned",
                    "Error Message" : error.localizedDescription
                    ])
            } else {
                ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Login Does Not Succeed", parameters: [
                    "Login Name" : self.loginNameForAnalytics,
                    "Required Fields" : "email;password",
                    "Reason" : "Unknown"
                    ])
            }
            
            self.cleengLoginState = .notLoggedIn
            completion(false, error)
        }
    }
    
    /**
     Sign up as new user with email & password
     
     - Parameter email: New user's email
     - Parameter password: The password associated with the email
     - Parameter completion: The closure to execute when finish
     */
     func signup(withEmail email: String, password: String, completion: @escaping ((_ succeeded: Bool, _ error: Error?) -> Void)) {
        if cleengLoginState != .notLoggedIn {
            if cleengLoginState == .loadItem || cleengLoginState == .refreshingToken {
                if onTokenRefreshEnd == nil { onTokenRefreshEnd = [] }
                
                let onRefresh: RefreshTokenEnded = { [weak self] isLoggedIn in
                    if isLoggedIn { self?.logout() }
                    
                    self?.signup(withEmail: email, password: password, completion: completion)
                }
                
                onTokenRefreshEnd!.append(onRefresh)
            } else {
                completion(false, CleengLoginAndSubscribeApi.ErrorType.alreadyLoggedInWithAnotherUser.error)
            }
        } else {
            signup(email: email, password: password, completion: completion)
        }
    }
    
    /**
     Sign up as new user with Facebook
     
     - Parameter facebookId: User's Facebook id
     - Parameter email: The email associated with the user's Facebook
     - Parameter completion: The closure to execute when finish
     */
    func signup(withFacebook facebookId: String, email: String, completion: @escaping ((_ succeeded: Bool, _ error: Error?) -> Void)) {
        if cleengLoginState != .notLoggedIn {
            if cleengLoginState == .loadItem || cleengLoginState == .refreshingToken {
                if onTokenRefreshEnd == nil { onTokenRefreshEnd = [] }
                
                let onRefresh: RefreshTokenEnded = { [weak self] isLoggedIn in
                    if isLoggedIn { self?.logout() }
                    
                    self?.signup(withFacebook: facebookId, email: email, completion: completion)
                }
                
                onTokenRefreshEnd!.append(onRefresh)
            } else {
                completion(false, CleengLoginAndSubscribeApi.ErrorType.alreadyLoggedInWithAnotherUser.error)
            }
        } else {
            signup(email: email, facebookId: facebookId, completion: completion)
        }
    }
    
    /**
     Ask to send the user to his/her email a reset password link
     
     - Parameter email: The email associated with the user's account
     - Parameter completion: The closure to execute when finish
     */
    func resetPassword(email: String, completion: @escaping ((_ succeeded: Bool, _ error: Error?) -> Void)) {
        ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "PW Recovery Initialized", parameters: [
            "Login Name" : self.loginNameForAnalytics,
            "Required Fields" : "email"
            ])
        
        makeRequest(apiName: "passwordReset", params: ["email" : email]) { [weak self] (response, _, error) in
            guard let _ = self else { return }
            
            if let succeeded = (response as? [String:Any])?["success"] as? Bool {
                completion(succeeded, nil)
            } else {
                completion(false, error)
            }
        }
    }
    
    //MARK: -- Private
    private func loadItemData(retry: Int = 0) {
        if let item = item {
            cleengLoginState = .loadItem
            (item as! APPurchasableItem).load { [weak self] (success, model) in
                guard let strongSelf = self else { return }
                
                if success {
                    strongSelf.setLoginNameForAnalytics()
                    strongSelf.trySilentLogin()
                } else if retry > 3 {
                    strongSelf.cleengLoginState = .failedToLoadItemData
                    
                    let onTokenRefreshEnd = strongSelf.onTokenRefreshEnd ?? []
                    strongSelf.onTokenRefreshEnd = nil
                    for refeshEnds in onTokenRefreshEnd {
                        refeshEnds(false)
                    }
                } else {
                    strongSelf.startItemLoadTimer(retry: retry + 1)
                }
            }
        }
    }
    
    private func setLoginNameForAnalytics() {
        loginNameForAnalytics = ""
        guard let account = APApplicasterController.sharedInstance()?.account else {
            return
        }
        
        guard let item = item else {
            return
        }
        for authId in (item.authorizationProvidersIDs as? [String]) ?? [] {
            if let authorizationProvider: APAuthorizationProvider = account.authorizationProviders(byUniqueID: authId) , let name = authorizationProvider.storeFrontTitle , name.isEmpty == false {
                if loginNameForAnalytics.isEmpty {
                    loginNameForAnalytics = name
                } else {
                    loginNameForAnalytics = "\(loginNameForAnalytics);\(name)"
                }
            }
        }
    }
    
    /// Check if has chached token & refresh it to get the offers token list available for the user
    private func trySilentLogin() {
        if let token = CleengLoginAndSubscribeApi.currentCleengUser?.token,
            token.isEmpty == false  {
            refreshToken(token)
        } else {
            cleengLoginState = .notLoggedIn
            let onTokenRefreshEnd = self.onTokenRefreshEnd ?? []
            self.onTokenRefreshEnd = nil
            for refeshEnds in onTokenRefreshEnd {
                refeshEnds(false)
            }
        }
    }
    
    /// Refresh Cleeng token
    /// - Parameter token: The Cleeng token to refresh
    private func refreshToken(_ token: String) {
        cleengLoginState = .refreshingToken
        makeRequest(apiName: "extendToken", params: ["token" : token]) { [weak self] (response, _, error) in
            guard let strongSelf = self else {
                return
            }
            
            guard strongSelf.cleengLoginState == .refreshingToken else { return }
            
            if let tokens = response as? [[String:Any]] {
                for tokenDic in tokens {
                    guard let token = tokenDic["token"] as? String , token.isEmpty == false else {
                        continue
                    }
                    
                    let offerId = tokenDic["offerId"] as? String
                    if offerId?.isEmpty ?? true {
                        strongSelf.defaultToken = token
                        CleengLoginAndSubscribeApi.updateCleengUserToken(token: token)
                    } else {
                        let authId = tokenDic["authId"]
                        if let authId = authId as? String {
                            APAuthorizationManager.sharedInstance().setAuthorizationToken(token, withAuthorizationProviderID: authId)
                        } else if let authIds = authId as? [String] {
                            for authId in authIds {
                                APAuthorizationManager.sharedInstance().setAuthorizationToken(token, withAuthorizationProviderID: authId)
                            }
                        }
                    }
                }
                
                strongSelf.didRefreshToken()
            } else {
                strongSelf.cleengLoginState = .notLoggedIn
                
                let onTokenRefreshEnd = strongSelf.onTokenRefreshEnd ?? []
                strongSelf.onTokenRefreshEnd = nil
                for refeshEnds in onTokenRefreshEnd {
                    refeshEnds(false)
                }
            }
        }
    }
    
    private func didRefreshToken() {
        let isLoggedIn = (self.defaultToken != nil)
        self.cleengLoginState = (isLoggedIn ? .loggedIn : .notLoggedIn)
        
        let onTokenRefreshEnd = self.onTokenRefreshEnd ?? []
        self.onTokenRefreshEnd = nil
        for refeshEnds in onTokenRefreshEnd {
            refeshEnds(isLoggedIn)
        }
    }
    
    /// Make a signup with Email & Password or Faceebok
    private func signup(email: String, password: String? = nil, facebookId: String? = nil, completion: @escaping ((_ succeeded: Bool, _ error: Error?) -> Void)) {
        
        let locale = Locale.current
        guard let country = (locale as NSLocale).object(forKey: .countryCode) as? String else {
            completion(false, NSError(domain: "NSLocale", code: -1, userInfo: [NSLocalizedDescriptionKey : "NSLocale has no Country code"]) as Error)
            return
        }
        
        /*guard let currency = (locale as NSLocale).object(forKey: .currencyCode) as? String else {
         completion(false, NSError(domain: "NSLocale", code: -1, userInfo: [NSLocalizedDescriptionKey : "NSLocale has no Currency"]) as Error)
         return
         }
         
         guard let localeIdentifier = (locale as NSLocale).object(forKey: .identifier) as? String else {
         completion(false, NSError(domain: "NSLocale", code: -1, userInfo: [NSLocalizedDescriptionKey : "NSLocale has no Language code"]) as Error)
         return
         }*/
        
        var params = [
            "email" : email,
            "country" : country,
            "locale" : "en_US",//localeIdentifier (Cleeng can't support locale such as en_IL)
            "currency" : "USD"//currency (Cleeng can't support currency such as ILS)
        ]
        
        let requiredFields: String
        if let password = password {
            params["password"] = password
            requiredFields = "email;password"
        } else {
            params["facebookId"] = facebookId
            requiredFields = "email;facebookId"
        }
        
        ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Start Registration", parameters: [
            "Login Name" : loginNameForAnalytics,
            "Required Fields" : requiredFields
            ])
        
        cleengLoginState = .tryToLogin
        makeRequest(apiName: "register", params: params) { [weak self] (response, _, error) in
            guard let strongSelf = self else {
                return
            }
            
            if let tokens = response as? [[String:Any]] {
                
                // Iterate all tokens returned on user signup
                for tokenDic in tokens {
                    guard let token = tokenDic["token"] as? String , token.isEmpty == false else {
                        continue
                    }
                    
                    let offerId = tokenDic["offerId"] as? String
                    if offerId?.isEmpty ?? true {
                        //Token with no `offerId` is Cleeng user token
                        CleengLoginAndSubscribeApi.currentCleengUser = CleengUser(email: email)
                        strongSelf.defaultToken = token
                        CleengLoginAndSubscribeApi.updateCleengUserToken(token: token)
                    } else {
                        //Token with `offerId` is a token used to unlock item
                        let authId = tokenDic["authId"]
                        if let authId = authId as? String {
                            APAuthorizationManager.sharedInstance().setAuthorizationToken(token, withAuthorizationProviderID: authId)
                        } else if let authIds = authId as? [String] {
                            for authId in authIds {
                                APAuthorizationManager.sharedInstance().setAuthorizationToken(token, withAuthorizationProviderID: authId)
                            }
                        }
                    }
                }
                
                if let _ = strongSelf.defaultToken {
                    ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Registration Succeeds", parameters: [
                        "Login Name" : strongSelf.loginNameForAnalytics,
                        "Required Fields" : requiredFields
                        ])
                    
                    strongSelf.cleengLoginState = .loggedIn
                } else {
                    ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Registration Does Not Succeed", parameters: [
                        "Login Name" : strongSelf.loginNameForAnalytics,
                        "Required Fields" : requiredFields,
                        "Reason" : "Unknown"
                        ])
                    
                    strongSelf.cleengLoginState = .notLoggedIn
                }
                completion(strongSelf.defaultToken != nil, nil)
            } else {
                var didHandle = false
                
                //Signup has failed. If we tried to signup with Facebook account & we got that user already exist, then make a login with Facebook without giving the user any indication
                if let facebookId = facebookId , let error = error as NSError? {
                    if error.code == ErrorType.customerAlreadyExist.rawValue {
                        didHandle = true
                        strongSelf.login(facebookId: facebookId, email: email, completion: completion)
                    }
                }
                
                if !didHandle {
                    if let error = error {
                        ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Registration Does Not Succeed", parameters: [
                            "Login Name" : strongSelf.loginNameForAnalytics,
                            "Required Fields" : requiredFields,
                            "Reason" : "Error Returned",
                            "Error Message" : error.localizedDescription
                            ])
                    } else {
                        ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Registration Does Not Succeed", parameters: [
                            "Login Name" : strongSelf.loginNameForAnalytics,
                            "Required Fields" : requiredFields,
                            "Reason" : "Unknown"
                            ])
                    }
                    
                    strongSelf.cleengLoginState = .notLoggedIn
                    completion(false, error)
                }
            }
        }
    }
    
    /**
     Make a login with Facebook account. This is a fallback when sign up with Facebook has failed with error = 'customer already exist'
     
     - Parameter facebookId: User's Facebook id
     - Parameter email: The email associated with the user's Facebook
     - Parameter completion: The closure to execute when finish
     */
    private func login(facebookId: String, email: String, completion: @escaping ((_ succeeded: Bool, _ error: Error?) -> Void)) {
        ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Start Login", parameters: [
            "Login Name" : loginNameForAnalytics,
            "Required Fields" : "email;facebookId"
            ])
        
        cleengLoginState = .tryToLogin
        makeRequest(apiName: "login", params: [ "email" : email, "facebookId" : facebookId ]) { [weak self] (response, _, error) in
            guard let strongSelf = self else {
                return
            }
            
            if let tokens = response as? [[String:Any]] {
                for tokenDic in tokens {
                    guard let token = tokenDic["token"] as? String , token.isEmpty == false else {
                        continue
                    }
                    
                    let offerId = tokenDic["offerId"] as? String
                    if offerId?.isEmpty ?? true {
                        CleengLoginAndSubscribeApi.currentCleengUser = CleengUser(email: email)
                        strongSelf.defaultToken = token
                        CleengLoginAndSubscribeApi.updateCleengUserToken(token: token)
                    } else {
                        let authId = tokenDic["authId"]
                        if let authId = authId as? String {
                            APAuthorizationManager.sharedInstance().setAuthorizationToken(token, withAuthorizationProviderID: authId)
                        } else if let authIds = authId as? [String] {
                            for authId in authIds {
                                APAuthorizationManager.sharedInstance().setAuthorizationToken(token, withAuthorizationProviderID: authId)
                            }
                        }
                    }
                }
                
                if let _ = strongSelf.defaultToken {
                    ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Login Succeeds", parameters: [
                        "Login Name" : strongSelf.loginNameForAnalytics,
                        "Required Fields" : "email;facebookId"
                        ])
                    
                    strongSelf.cleengLoginState = .loggedIn
                } else {
                    ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Login Does Not Succeed", parameters: [
                        "Login Name" : strongSelf.loginNameForAnalytics,
                        "Required Fields" : "email;facebookId",
                        "Reason" : "Unknown"
                        ])
                    
                    strongSelf.cleengLoginState = .notLoggedIn
                }
                
                completion(strongSelf.defaultToken != nil, nil)
            } else {
                if let error = error {
                    ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Login Does Not Succeed", parameters: [
                        "Login Name" : strongSelf.loginNameForAnalytics,
                        "Required Fields" : "email;facebookId",
                        "Reason" : "Error Returned",
                        "Error Message" : error.localizedDescription
                        ])
                } else {
                    ZAAppConnector.sharedInstance().analyticsDelegate?.trackEvent(name: "Login Does Not Succeed", parameters: [
                        "Login Name" : strongSelf.loginNameForAnalytics,
                        "Required Fields" : "email;facebookId",
                        "Reason" : "Unknown"
                        ])
                }
                
                strongSelf.cleengLoginState = .notLoggedIn
                completion(false, error)
            }
        }
    }
    
    //MARK: -- Retry Timer
    private func startItemLoadTimer(retry: Int) {
        invalidateItemLoadTimer()
        loadItemTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(CleengLoginAndSubscribeApi.retryLoadItem(_:)), userInfo: retry, repeats: false)
    }
    
    private func invalidateItemLoadTimer() {
        loadItemTimer?.invalidate()
        loadItemTimer = nil
    }
    
    @objc private func retryLoadItem(_ ti: Timer) {
        let retry = (ti.userInfo as? Int) ?? 3
        invalidateItemLoadTimer()
        loadItemData(retry: retry)
    }
    
    //MARK: - Offers
    //MARK: -- Public
    
    /**
     Load Cleeng offers available to unlock the item
     
     - Parameter completion: The closure to execute when finish
     */
    func loadSubscriptionsForCurrentItem(withCompletion completion: @escaping ((_ offers: [CleengOffer]?, _ error: Error?) -> Void)) {
        if let item = item {
            var auth_Ids: [String] = []
            if purchaseItemType == .purchasableItem {
                guard item.isLoaded() else {
                    completion(nil, ErrorType.itemDataIsNotLoadedYet.error)
                    return
                }
                
                guard let authIds = item.authorizationProvidersIDs as? [String] else {
                    completion(nil, ErrorType.currentItemHasNoAuthorizationProvidersIDs.error)
                    return
                }
                auth_Ids = authIds
            } else {
                if let purchasableItemProtocol = item as? ZPPurchasableItemProtocol {
                    let auth_Ids = purchasableItemProtocol.authorizationProvidersIDs
                } else {
                    completion(nil, ErrorType.currentItemHasNoAuthorizationProvidersIDs.error)
                    return
                }
            }
            
            
            func unique(_ list: [String]) -> [String] {
                var updatedList: [String] = []
                for index in 0..<list.count {
                    let str = list[index]
                    if updatedList.index(of: str) == nil {
                        updatedList.append(str)
                    }
                }
                
                return updatedList
            }
            
            let uniqueAuthId = unique(auth_Ids)
            let didUseToken = defaultToken != nil
            
            loadSubscription(forAuthIds: uniqueAuthId) { [weak self] (offers, error) in
                guard let strongSelf = self else { return }
                
                if let offers = offers {
                    strongSelf.loadOffersWithToken = didUseToken
                    strongSelf.offers = offers
                    completion(offers, nil)
                } else {
                    let err = error ?? (NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error)
                    
                    completion(nil, err)
                }
            }
        } else {
            completion(nil, ErrorType.itemIsNotAvailable.error)
        }
    }
    
    /**
     Load Cleeng offer by offer id
     
     - Parameter offerId: The id of the offer to load
     - Parameter completion: The closure to execute when finish
     */
    func loadSubscription(forOffer offerId: String, completion: @escaping ((_ offers: [CleengOffer]?, _ error: Error?) -> Void)) {
        _loadSubscription(forIds: [offerId], useAuthIds: false, completion: completion)
    }
    
    /**
     Load Cleeng offers by item Applicaster authentication provider id
     
     - Parameter authIds: List of Applicaster authentication provider ids of load offers associated with one of those ids
     - Parameter completion: The closure to execute when finish
     */
    func loadSubscription(forAuthIds authIds: [String], completion: @escaping ((_ offers: [CleengOffer]?, _ error: Error?) -> Void)) {
        _loadSubscription(forIds: authIds, useAuthIds: !(authIds.isEmpty), completion: completion)
    }
    
    private func _loadSubscription(forIds ids: [String], useAuthIds: Bool, completion: @escaping ((_ offers: [CleengOffer]?, _ error: Error?) -> Void)) {
        
        var params: [String:Any] = [:]
        if ids.isEmpty == false { params["offers"] = ids }
        
        if let token = self.defaultToken { params["token"] = token }
        
        if purchaseItemType == .purchasableItem {
            if useAuthIds { params["byAuthId"] = 1 }
        }
        
        makeRequest(apiName: "subscriptions", params: params) { [weak self] (response, _, error) in
            guard let strongSelf = self else { return }
            
            if let items = (response as? [[String:Any]]) {
                let offers = items.map({ (offerDict) -> CleengOffer? in
                    return CleengOffer(dictionary: offerDict)
                }).filter({ (offer) -> Bool in return offer != nil }) as! [CleengOffer]
                
                strongSelf.offers = offers
                completion(offers, nil)
            } else {
                let err = error ?? (NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error)
                
                completion(nil, err)
            }
        }
    }
    
    /// Check if the item is unlocked or not.
    var hasAuthorizationTokenForCurrentItem: Bool {
        return authorizationTokenForCurrentItem != nil
    }
    
    /// Get a token string which can be used to unlock the item, is one exists.
    var authorizationTokenForCurrentItem: String? {
        if let item = item {
            if purchaseItemType == .purchasableItem {
                guard item.isLoaded() else { return nil }
            }
            
            var authIds = (item.authorizationProvidersIDs as? [String]) ?? []
            let tokens = APAuthorizationManager.sharedInstance().authorizationTokens()
            
            if authIds.isEmpty {
                authIds = (tokens?.allKeys ?? []).filter({ $0 is String && ($0 as! String) != kCleengLoginDefaultTokenKey }) as! [String]
            }
            
            for authId in authIds {
                if let tokenToValid = tokens?[authId] as? String, !(tokenToValid.isEmpty) {
                    return tokenToValid
                }
            }
        }
        
        return nil
    }
    
    /**
     Sync Cleeng with an IAP purchased to unlock an offer.
     
     - Parameter offer: The offer to ublock
     - Parameter transactionId: The IAP transaction identifier
     - Parameter isRestoredTransaction: A flag indicating if this transaction is a new one or restored.
     - Parameter receipt: The AppStore receipt blob
     - Parameter completion: The closure to execute when finish
     */
    func subscribe(for offer: CleengOffer,
                   transactionId: String,
                   isRestoredTransaction: Bool,
                   productId: String,
                   receipt: String,
                   completion: @escaping ((_ canVerify: Bool, _ error: Error?) -> Void)) {
        guard let token = self.defaultToken else {
            completion(false, NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.invalideCustomerToken.rawValue, userInfo: nil))
            return
        }
        
        let appType: String
        #if os(tvOS)
        appType = "tvos"
        #else
        appType = "ios"
        #endif
        
        let receiptInfo: [String:Any] = [
            "transactionId" : transactionId,
            "receiptData" : receipt
        ]
        
        let params: [String:Any] = [
            "appType" : appType,
            "receipt" : receiptInfo,
            "offerId" : offer.id,
            "token" : token,
            "isRestored" : isRestoredTransaction,
            "productId" : productId
        ]
        
        makeRequest(apiName: "subscription", params: params) { (result, httpResponse, error) in
            if let httpResponse = httpResponse , httpResponse.statusCode != 200 {
                print("Received error: \(httpResponse.statusCode)")
                let err = error ?? (NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: httpResponse.statusCode, userInfo: nil))
                completion(false, err)
            }
        }
        
        completion(true, nil)
    }
    
    //MARK: - StoreKit
    //MARK: -- Public
    
    /**
     Load IAP-s from StoreKit
     
     - Parameter completion: The closure to execute when finish
     */
    func loadStoreProducts(withCompletion completion: @escaping ((_ items: [(offer: CleengOffer, product: SKProduct)]?, _ error: Error?) -> Void)) {
        
        if let item = item {
            if purchaseItemType == .purchasableItem {
                guard item.isLoaded() else {
                    completion(nil, ErrorType.itemDataIsNotLoadedYet.error)
                    return
                }
                
                guard let _ = item.authorizationProvidersIDs else {
                    completion(nil, ErrorType.currentItemHasNoAuthorizationProvidersIDs.error)
                    return
                }
            }
        } else {
            completion(nil, ErrorType.itemIsNotAvailable.error)
            return
        }
        
        if offers?.isEmpty ?? true {
            loadSubscriptionsForCurrentItem { [weak self] (offers, error) in
                if let offers = offers {
                    self?._loadStoreProducts(forOffers: offers, completion: completion)
                } else {
                    let err = error ?? (NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error)
                    
                    completion(nil, err)
                }
            }
        } else {
            _loadStoreProducts(forOffers: offers!, completion: completion)
        }
    }
    
    /**
     Restore IAP-s from StoreKit and sync them with Cleeng
     
     - Parameter userEmail: The user's email to make signup/login
     - Parameter password: The associated password with user's email
     - Parameter completion: The closure to execute when finish
     */
    func restoreStorePurchases(userEmail: String, password: String, withCompletion completion: @escaping RestorePurchaseResultBlock) {
        if let item = item {
            if purchaseItemType == .purchasableItem {
                guard item.isLoaded() else {
                    completion(.failure(error: ErrorType.itemDataIsNotLoadedYet.error))
                    return
                }
                
                guard let _ = item.authorizationProvidersIDs else {
                    completion(.failure(error: ErrorType.currentItemHasNoAuthorizationProvidersIDs.error))
                    return
                }
            }
        } else {
            completion(.failure(error: ErrorType.itemIsNotAvailable.error))
            return
        }
        
        if offers?.isEmpty ?? true {
            loadSubscriptionsForCurrentItem { [weak self] (offers, error) in
                if let offers = offers {
                    self?._signInOrUpForRestoreStorePurchases(userEmail: userEmail, password: password, offers: offers, completion: completion)
                } else {
                    let err = error ?? (NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error)
                    
                    completion(.failure(error: err))
                }
            }
        } else {
            _signInOrUpForRestoreStorePurchases(userEmail: userEmail, password: password, offers: offers!, completion: completion)
        }
    }
    
    /**
     Ask StoreKit to purchase an IAP
     
     - Parameter product: The IAP to purchase
     - Parameter offer: The Cleeng offer related to this IAP
     - Parameter completion: The closure to execute when finish
     */
    func purchaseProduct(_ product: SKProduct, forOffer offer: CleengOffer, completion: @escaping ZappCleengPurchaseResultBlock) {
        StoreProductsPurchaseManager.shared.purchaseProduct(product, forOffer: offer, cleengAPI: self, completion: completion)
    }
    
    /**
     Ask Cleeng to redeem a coupon code
     
     - Parameter code: The code to redeem
     - Parameter offers: A list of Cleeng offers to unlock one of them with the coupon code
     - Parameter completion: The closure to execute when finish
     */
    func redeemCode(_ code: String, offer: CleengOffer, completion: @escaping ZappCleengRedeemCodeResultBlock) {
        guard let token = self.defaultToken else {
            print("Can't redeem code before user made login")
            let error = NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.invalideCustomerToken.rawValue, userInfo: nil) as Error
            
            completion(.failed(error: error))
            
            return
        }
        
        let params: [String:Any] = ["token" : token , "offerId" : offer.id, "couponCode" : code]
        
        makeRequest(apiName: "subscription", params: params) { [weak self] (response, _, error) in
            guard let strongSelf = self else { return }
            
            guard let info = response as? [String:Any] else {
                let err = error ?? (NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error)
                
                completion(.failed(error: err))
                return
            }
            
            guard let result = info["result"] else {
                let err: Error
                if let error = info["error"] as? String {
                    err = (NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey : error]) as Error)
                } else {
                    err = error ?? (NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error)
                }
                
                completion(.failed(error: err))
                return
            }
            
            guard Bool(result) ?? false else {
                let err = error ?? (NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error)
                
                completion(.failed(error: err))
                
                return
            }
            
            strongSelf.extendToken(completion: { [weak self] (succeeded, error) in
                guard let _ = self else { return }
                
                if succeeded {
                    completion(.redeemed)
                } else {
                    let err = error ?? (NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error)
                    
                    completion(.failed(error: err))
                }
            })
        }
    }
    
    //MARK: -- Private
    private func _loadStoreProducts(forOffers offers: [CleengOffer], completion: @escaping ((_ items: [(offer: CleengOffer, product: SKProduct)]?, _ error: Error?) -> Void)) {
        var productIds: [String] = []
        for offer in offers {
            productIds.append(offer.iapIdentifier)
        }
        
        StoreProductsPurchaseManager.shared.retrieveProductsInfo(Set(productIds)) { [weak self] (results) in
            self?.handleLoadProductsResponse(results, offers: offers, completion: completion)
        }
    }
    
    private func handleLoadProductsResponse(_ results: StoreProductsRetrieveResults, offers: [CleengOffer], completion: @escaping ((_ items: [(offer: CleengOffer, product: SKProduct)]?, _ error: Error?) -> Void)) {
        if let error = results.error {
            completion(nil, error)
        } else if results.invalidProductIDs.isEmpty == false {
            
            //Create offer-product map
            var productsMap: [String:SKProduct] = [:]
            for product in results.retrievedProducts {
                productsMap[product.productIdentifier] = product
            }
            
            var availableItems: [(offer: CleengOffer, product: SKProduct)]! = offers.filter({ (offer) -> Bool in
                return productsMap[offer.iapIdentifier] != nil
            }).map({ (offer) -> (offer: CleengOffer, product: SKProduct) in
                let product = productsMap[offer.iapIdentifier]!
                return (offer: offer, product: product)
            })
            
            if availableItems.isEmpty {
                availableItems = nil
            }
            
            let error = NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: ErrorType.offerNotExist.rawValue, userInfo: nil)
            completion(availableItems, error as Error)
            
        } else {
            //Create offer-product map
            var productsMap: [String:SKProduct] = [:]
            for product in results.retrievedProducts {
                productsMap[product.productIdentifier] = product
            }
            
            let availableItems: [(offer: CleengOffer, product: SKProduct)]! = offers.filter({ (offer) -> Bool in
                return productsMap[offer.iapIdentifier] != nil
            }).map({ (offer) -> (offer: CleengOffer, product: SKProduct) in
                let product = productsMap[offer.iapIdentifier]!
                return (offer: offer, product: product)
            })
            
            completion(availableItems, nil)
        }
    }
    
    private func _signInOrUpForRestoreStorePurchases(userEmail: String, password: String, offers: [CleengOffer], completion: @escaping RestorePurchaseResultBlock) {
        signup(withEmail: userEmail, password: password) { [weak self] (succeeded, signUpError) in
            guard let strongSelf = self else { return }
            if succeeded {
                strongSelf._restoreStorePurchasesIfNeeded(offers: offers, completion: completion)
            } else if let signUpError = signUpError as NSError?, signUpError.code == ErrorType.customerAlreadyExist.rawValue {
                strongSelf.login(withEmail: userEmail, password: password, completion: { [weak strongSelf] (succeeded, signInError) in
                    guard let strongSelf = strongSelf else { return }
                    
                    if succeeded {
                        strongSelf._restoreStorePurchasesIfNeeded(offers: offers, completion: completion)
                    } else {
                        completion(.failure(error: signInError ?? (NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error)))
                    }
                })
            } else {
                let err = signUpError ?? (NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error)
                completion(.failure(error: err))
            }
        }
    }
    
    private func _restoreStorePurchasesIfNeeded(offers: [CleengOffer], completion: @escaping RestorePurchaseResultBlock) {
        guard !hasAuthorizationTokenForCurrentItem else {
            completion(.userAlreadyHasAccessToOffers)
            return
        }
        
        var productIds: [String] = []
        for offer in offers {
            productIds.append(offer.iapIdentifier)
        }
        
        StoreProductsPurchaseManager.shared.restorePurchases(forProductIds: productIds) { [weak self] (restoredPurchases: [StorePurchase], restoreFailedPurchases: [(SKError, String?)]) in
            self?.handleRestorePurchasesResponse(restoredPurchases: restoredPurchases, restoreFailedPurchases: restoreFailedPurchases, offers: offers, completion: completion)
        }
    }
    
    private func handleRestorePurchasesResponse(restoredPurchases: [StorePurchase], restoreFailedPurchases: [(SKError, String?)], offers: [CleengOffer], completion: @escaping RestorePurchaseResultBlock) {
        var productIdentifierMapToOffer: [String:CleengOffer] = [:]
        for offer in offers {
            productIdentifierMapToOffer[offer.iapIdentifier] = offer
        }
        
        guard restoredPurchases.isEmpty == false else {
            completion(.noPurchaseToRestore)
            return
        }
        
        var morePurchasesToRetry = restoredPurchases
        let firstToTry = morePurchasesToRetry.removeFirst()
        self.retryUseRestoredPurchase(firstToTry, morePurchasesToRetry: morePurchasesToRetry, productIdentifierMapToOffer: productIdentifierMapToOffer, completion: completion)
    }
    
    private func retryUseRestoredPurchase(_ purchase: StorePurchase, morePurchasesToRetry: [StorePurchase], anyError: Error? = nil, productIdentifierMapToOffer: [String:CleengOffer], completion: @escaping RestorePurchaseResultBlock) {
        
        StoreProductsPurchaseManager.shared.retryUseRestoredPurchase(purchase, offer: productIdentifierMapToOffer[purchase.productId]!, cleengAPI: self) { [weak self] (result) in
            guard let strongSelf = self else { return }
            
            var currentAnyError = anyError
            switch result {
            case .succeeded:
                completion(.succeeded)
                StoreProductsPurchaseManager.shared.finishTranscation(for: morePurchasesToRetry)
            case .failed(let error):
                StoreProductsPurchaseManager.shared.finishTranscation(for: [purchase])
                currentAnyError = error
                if morePurchasesToRetry.isEmpty {
                    if let error = currentAnyError {
                        completion(.failure(error: error))
                    } else {
                        completion(.noPurchaseToRestore)
                    }
                } else {
                    var remainPurchasesToRetry = morePurchasesToRetry
                    let nextToTry = remainPurchasesToRetry.removeFirst()
                    
                    strongSelf.retryUseRestoredPurchase(nextToTry, morePurchasesToRetry: remainPurchasesToRetry, anyError: currentAnyError, productIdentifierMapToOffer: productIdentifierMapToOffer, completion: completion)
                }
            }
        }
    }
    
    //MARK: - Make request
    private func makeRequest(apiName: String, params: [String:Any], completion: @escaping ((_ result: Any?, _ httpResponse: HTTPURLResponse?, _ error: Error?) -> Void)) {
        
        var updatedParams = params
        updatedParams["publisherId"] = publisherId
        
        print("Send request: \(apiName) with params: \(updatedParams)")
        
        let url = URL(string: "\(webServiceURL)/\(apiName)")!
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try! JSONSerialization.data(withJSONObject: updatedParams, options: .prettyPrinted)
        
        let task = URLSession.shared.dataTask(with: request as URLRequest) { (data, response, error) in
            guard let data = data , let json = (try? JSONSerialization.jsonObject(with: data, options: [])) else {
                let err = error ?? (NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error)
                DispatchQueue.onMain {
                    completion(nil, (response as? HTTPURLResponse), err)
                }
                
                return
            }
            
            print("Response: \(json)")
            if let json = json as? [String:Any] , let code = json["code"] as? Int {
                let error: NSError
                if let message = json["message"] as? String {
                    error = NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: code, userInfo: [NSLocalizedDescriptionKey : message])
                } else {
                    error = NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: code, userInfo: nil)
                }
                
                DispatchQueue.onMain {
                    completion(nil, (response as? HTTPURLResponse), error as Error)
                }
            }
            else {
                DispatchQueue.onMain {
                    completion(json, (response as? HTTPURLResponse), error)
                }
            }
        }
        
        task.resume()
    }
    
    //MARK: - Errors
    enum ErrorType: Int {
        case unknown = -1
        case anotherLoginOrSignupInProcess = -2
        case alreadyLoggedInWithAnotherUser = -3
        case currentItemHasNoAuthorizationProvidersIDs = -5
        case subscriptionVerificationTimeOut = -6
        case loadTokensTimeOut = -7
        case noStoreProduct = -8
        case itemDataIsNotLoadedYet = -9
        case itemIsNotAvailable = -14
        
        case storeJsonDecodeError = -10
        case storeNotHaveReceiptData = -11
        case storeNoRemoteData = -12
        case storeReceiptInvalid = -13
        
        case invalideCustomerToken = 1
        case offerNotExist = 4
        case apiRequireEnterpriseAccount = 5
        case badCustomerEmailOrCustomerNotExist = 10
        case missingEmailOrPassword_orInvalideCustomerData = 11
        case inactiveCustomerAccount = 12
        case customerAlreadyExist = 13
        case ipAddressLimitExceeded = 14
        case invalideCustomerCredentials = 15
        case invalideResetPasswordTokenOrResetUrl = 16
        
        var error: Error {
            var userInfo: [String:Any]?
            if let message = self.errorMessage {
                userInfo = [NSLocalizedDescriptionKey : message]
            }
            return NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: self.rawValue, userInfo: userInfo) as Error
        }
        
        private var errorMessage: String? {
            switch self {
            case .alreadyLoggedInWithAnotherUser:
                return "Please logout before trying to login with another user"
            default:
                return nil
            }
        }
    }
}

//MARK: - CleengOffer
struct CleengOffer {
    var id: String
    let publisherEmail: String?
    let title: String
    let description: String
    let currency: String
    let price: Double
    
    let country: String?
    let period: String?
    let isActive: Bool
    
    let isPromoted: Bool
    let shouldRemovePromotionIcon: Bool
    
    let url: URL?
    let createdAt: Date?
    let updatedAt: Date?
    let expiresAt: Date?
    
    let tags: [String]?
    let iapIdentifier: String
    
    var accessGranted: Bool = false
    
    init(id: String, publisherEmail: String? = nil, title: String, description: String, currency: String, price: Double, iapIdentifier: String, country: String? = nil, period: String? = nil, isActive: Bool, isPromoted: Bool, shouldRemovePromotionIcon: Bool, url: URL? = nil, createdAt: Date? = nil, updatedAt: Date? = nil, expiresAt: Date? = nil, tags: [String]? = nil, accessGranted: Bool = false) {
        self.id = id
        self.publisherEmail = publisherEmail
        self.title = title
        self.description = description
        self.currency = currency
        self.price = price
        
        self.country = country
        self.period = period
        self.isActive = isActive
        self.shouldRemovePromotionIcon = shouldRemovePromotionIcon
        self.isPromoted = isPromoted
        
        self.url = url
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
        
        self.tags = tags
        
        self.accessGranted = accessGranted
        self.iapIdentifier = iapIdentifier
    }
    
    init?(dictionary: [String:Any]) {
        guard let id = dictionary["id"] as? String else { return nil }
        guard let currency = dictionary["currency"] as? String else { return nil }
        let priceValue = dictionary["price"]
        let optionalPrice: Double!
        if let priceString = priceValue as? String, let priceFloat = Double(priceString) {
            optionalPrice = priceFloat
        } else if let priceDouble = priceValue as? Double {
            optionalPrice = priceDouble
        } else if let priceNumber = priceValue as? NSNumber {
            optionalPrice = priceNumber.doubleValue
        } else {
            optionalPrice = nil
        }

        guard let price = optionalPrice else { return nil }

        guard let iap = dictionary["appleProductId"] as? String else { return nil }
        self.iapIdentifier = iap
        
        if let isPromotedValue = dictionary["is_voucher_promoted"] as? String {
            self.isPromoted = isPromotedValue.boolValue()
        } else if let isPromotedValue = dictionary["is_voucher_promoted"] as? Bool {
            self.isPromoted = isPromotedValue
        } else {
            self.isPromoted = false
        }

        if let shouldRemovePromotionIconValue = dictionary["should_hide_free_ribbon"] as? String {
            self.shouldRemovePromotionIcon = shouldRemovePromotionIconValue.boolValue()
        } else if let shouldDisplayPromotionIconValue = dictionary["should_display_free_ribbon"] as? Bool {
            self.shouldRemovePromotionIcon = shouldDisplayPromotionIconValue
        } else {
            self.shouldRemovePromotionIcon = false
        }

        let isActiveValue = dictionary["active"]
        let isActive: Bool
        if let isActiveString = isActiveValue as? String, isActiveString.lowercased() == "true" {
            isActive = true
        } else if let isActiveBool = isActiveValue as? Bool {
            isActive = isActiveBool
        } else {
            isActive = false
        }

        self.id = id
        self.publisherEmail = dictionary["publisherEmail"] as? String
        self.title = (dictionary["title"] as? String) ?? ""
        self.description = (dictionary["description"] as? String) ?? ""
        self.currency = currency
        self.price = price

        self.country = dictionary["country"] as? String
        self.period = dictionary["period"] as? String
        self.isActive = isActive

        if let urlString = dictionary["url"] as? String {
            self.url = URL(string: urlString)
        }
        else { self.url = nil }

        if let ti = dictionary["createdAt"] as? TimeInterval {
            self.createdAt = Date(timeIntervalSince1970: ti)
        }
        else { self.createdAt = nil }

        if let ti = dictionary["updatedAt"] as? TimeInterval {
            self.updatedAt = Date(timeIntervalSince1970: ti)
        }
        else { self.updatedAt = nil }

        if let ti = dictionary["expiresAt"] as? TimeInterval {
            self.expiresAt = Date(timeIntervalSince1970: ti)
        }
        else { self.expiresAt = nil }

        self.tags = dictionary["accessToTags"] as? [String]

        if let flag = dictionary["accessGranted"] as? Bool {
            self.accessGranted = flag
        }
        else { self.accessGranted = false }
    }
}


