//
//  StoreProductsPurchaseManager.swift
//  AFNetworking
//
//  Created by Yossi Avramov on 25/06/2018.
//

import Foundation
import SwiftyStoreKit
import StoreKit

typealias ZappCleengPurchaseResultBlock = ((_ result: StoreProductsPurchaseManager.PurchaseResult) -> Void)
typealias ZappCleengRestorePurchaseResultBlock = ((_ result: StoreProductsPurchaseManager.RestorePurchaseResult) -> Void)
typealias ZappCleengRedeemCodeResultBlock = ((_ result: StoreProductsPurchaseManager.RedeemCodeResult) -> Void)

typealias StoreProductsRestoreResults = RestoreResults
typealias StoreProductsRetrieveResults = RetrieveResults

/// Manage the entire flow of purchasing an IAP and syncing Cleeng for an IAP. Can manage multiple flows at once
class StoreProductsPurchaseManager {
    static let shared: StoreProductsPurchaseManager = StoreProductsPurchaseManager()
    
    enum PurchaseResult {
        case succeeded
        case fatalFailure(error: Error)
        case failedButCanRetry(error: Error, retry: (() -> Void), userSelectNotToRetry: (() -> Void)) //If 'retry' isn't null, one of the 2 blocks must be called: `retry` or `userSelectNotToRetry`
    }
    
    enum RestorePurchaseResult {
        case succeeded
        case failed(error: Error)
    }
    
    enum RedeemCodeResult {
        case redeemed
        case failed(error: Error)
    }
    
    private var restoredPurchases: [StorePurchase]?
    private var purchaseManagers: [String:ProductPurchaseManager] = [:]
    
    private init() {
        restoreStoreTransactions()
    }
    
    /// Restore transaction which still in proccess
    private func restoreStoreTransactions() {
        SwiftyStoreKit.completeTransactions(atomically: false) { [weak self] (purchases: [Purchase]) in
            DispatchQueue.onMain {
                self?.restoredPurchases = purchases
            }
        }
    }
    
    /**
     Load SKProduct-s for products id
     
     - Parameter productIds: List of products id to load SKProduct-s for
     - Parameter completion: The closure to execute when finish
     */
    func retrieveProductsInfo(_ productIds: Set<String>, completion: @escaping (RetrieveResults) -> Void) {
        SwiftyStoreKit.retrieveProductsInfo(Set(productIds)) { (results) in
            DispatchQueue.onMain {
                completion(results)
            }
        }
    }
    
    /**
     Restore old transactions for products id
     
     - Parameter productIds: List of products id to restore old transactions for
     - Parameter completion: The closure to execute when finish
     */
    func restorePurchases(forProductIds productIds: [String]?, completion: @escaping (_ restoredPurchases: [StorePurchase], _ restoreFailedPurchases: [(SKError, String?)]) -> Void) {
        
        SwiftyStoreKit.restorePurchases(atomically: false) { (results: RestoreResults) in
            
            var updatedRestoredPurchases: [StorePurchase] = results.restoredPurchases
            if let restoredPurchases = self.restoredPurchases , results.restoreFailedPurchases.isEmpty {
                for (index, purchase) in restoredPurchases.enumerated() {
                    if let purchase = purchase as? Purchase , purchase.transaction.transactionState == .restored && ((productIds?.isEmpty ?? true) ||  productIds!.contains(purchase.productId)) {
                        updatedRestoredPurchases.append(purchase)
                        self.restoredPurchases!.remove(at: index)
                    }
                }
            }
            
            if let productIds = productIds , !(productIds.isEmpty) {
                updatedRestoredPurchases = updatedRestoredPurchases.filter({ (purchase: StorePurchase) -> Bool in
                    return productIds.contains(purchase.productId)
                }).sorted(by: { (p1: StorePurchase, p2: StorePurchase) -> Bool in
                    if p2.transaction.transactionDate == nil {
                        return true
                    } else if p1.transaction.transactionDate == nil {
                        return true
                    } else {
                        return p2.transaction.transactionDate! < p1.transaction.transactionDate!
                    }
                })
            }
            
            DispatchQueue.onMain {
                completion(updatedRestoredPurchases, results.restoreFailedPurchases)
            }
        }
    }
    
    /**
     Start a flow for purchasing an IAP and activate offer in Cleeng
     
     - Parameter product: A StoreKit product to purchase
     - Parameter offer: The Cleeng offer associated with the IAP
     - Parameter cleengAPI: The api manager to use to make api calls
     - Parameter completion: The closure to execute when finish
     */
    func purchaseProduct(_ product: SKProduct, forOffer offer: CleengOffer, cleengAPI: CleengLoginAndSubscribeApi, completion: @escaping ZappCleengPurchaseResultBlock) {
        
        var purchase: StorePurchase?
        var purchaseIndex: Int?
        for (index, p) in (restoredPurchases ?? []).enumerated() {
            if p.productId == product.productIdentifier , p.needsFinishTransaction {
                purchase = p
                purchaseIndex = index
                break
            }
        }
        
        let managerId = UUID().uuidString
        let manager: ProductPurchaseManager
        if let purchase = purchase {
            restoredPurchases!.remove(at: purchaseIndex!)
            manager = ProductPurchaseManager(product: product, offer: offer, purchase: purchase, cleengAPI: cleengAPI)
        } else {
            manager = ProductPurchaseManager(product: product, offer: offer, cleengAPI: cleengAPI)
        }
        
        purchaseManagers[managerId] = manager
        
        manager.start { [weak self, weak manager] (result) in
            guard let strongSelf = self , let manager = manager else { return }
            
            strongSelf.purchaseProductCompletion(manager: manager, managerId: managerId, result: result, restoredPurchase: purchase, completion: completion)
        }
    }
    
    /**
     Try to use a restored transaction to activate a Cleeng offer
     
     - Parameter purchase: A restored purchase
     - Parameter offer: The Cleeng offer associated with the IAP
     - Parameter cleengAPI: The api manager to use to make api calls
     - Parameter completion: The closure to execute when finish
     */
    func retryUseRestoredPurchase(_ purchase: StorePurchase, offer: CleengOffer, cleengAPI: CleengLoginAndSubscribeApi, completion: @escaping ZappCleengRestorePurchaseResultBlock) {
        
        let managerId = UUID().uuidString
        let manager = ProductPurchaseManager(product: nil, offer: offer, purchase: purchase, cleengAPI: cleengAPI)
        
        purchaseManagers[managerId] = manager
        
        manager.start { [weak self] (result) in
            guard let strongSelf = self else { return }
            
            strongSelf.purchaseManagers[managerId] = nil
            
            switch result {
            case .succeeded:
                completion(.succeeded)
            case .failed(let error, _):
                completion(.failed(error: error))
            }
        }
    }
    
    /**
     Finish a batch of StoreKit transactions
     
     - Parameter purchases: StoreKit purchases to finish
     */
    func finishTranscation(for purchases: [StorePurchase]) {
        for purchase in purchases {
            if purchase.needsFinishTransaction {
                SwiftyStoreKit.finishTransaction(purchase.transaction)
            }
        }
    }
    
    //MARK: -- Private
    private func purchaseProductCompletion(manager: ProductPurchaseManager, managerId: String, result: ProductPurchaseManager.Result, restoredPurchase: StorePurchase?, completion: @escaping ZappCleengPurchaseResultBlock) {
        assert(Thread.isMainThread, "Need to be called on main thread")
        
        switch result {
        case .succeeded:
            self.purchaseManagers[managerId] = nil
            completion(.succeeded)
        case let .failed(error, retry):
            if let retry = retry {
                let userSelectNotToRetry: (() -> Void) = { [weak self] in
                    guard let strongSelf = self else { return }
                    
                    strongSelf.purchaseManagers[managerId] = nil
                    
                    if let purchase = manager.purchase , purchase.needsFinishTransaction {
                        strongSelf.restoredPurchases = (strongSelf.restoredPurchases ?? [])
                        strongSelf.restoredPurchases!.append(purchase)
                    }
                }
                
                completion(.failedButCanRetry(error: error, retry: retry, userSelectNotToRetry: userSelectNotToRetry))
            } else {
                self.purchaseManagers[managerId] = nil
                
                if let purchase = manager.purchase , purchase.needsFinishTransaction {
                    self.restoredPurchases = (self.restoredPurchases ?? [])
                    self.restoredPurchases!.append(purchase)
                }
                
                completion(.fatalFailure(error: error))
            }
        }
    }
}

//MARK: - ProductPurchaseManager
private typealias ProductPurchaseManagerResultBlock = ((_ result: ProductPurchaseManager.Result) -> Void)

/// A manager to handle the entire flow of purchasing an IAP and syncing Cleeng for a specific SKProduct or restored transaction
private class ProductPurchaseManager : NSObject {
    
    enum Result {
        case succeeded
        case failed(error: Error, retry: (() -> Void)?)
    }
    
    enum PurchaseState : Int {
        case initial
        case purchaseFromAppStore
        case loadReceipt
        case verifyOnCleeng
        case loadTokens
        case finished
        case failed
    }
    
    let product: SKProduct?
    private(set) var offer: CleengOffer
    
    private var onCompletion: ProductPurchaseManagerResultBlock?
    private(set) var purchase: StorePurchase?
    
    private weak var cleengAPI: CleengLoginAndSubscribeApi!
    private var state: PurchaseState = .initial
    private var cleengVerifyTimer: Timer?
    private var cleengVerifyStartTime: Date?
    private var encryptedReceipt: String!
    private var forceRefreshReceipt: Bool = false
    
    private var productIdentifier: String {
        return purchase?.productId ?? product!.productIdentifier
    }
    
    init(product: SKProduct, offer: CleengOffer, cleengAPI: CleengLoginAndSubscribeApi) {
        self.product = product
        self.offer = offer
        self.cleengAPI = cleengAPI
        self.purchase = nil
    }
    
    init(product: SKProduct?, offer: CleengOffer, purchase: StorePurchase, cleengAPI: CleengLoginAndSubscribeApi) {
        self.product = product
        self.offer = offer
        self.purchase = purchase
        self.cleengAPI = cleengAPI
    }
    
    /// Start the purchase or Cleeng updating flow
    func start(onCompletion: @escaping ProductPurchaseManagerResultBlock) {
        assert(Thread.isMainThread, "Need to be called on main thread")
        
        guard state == .initial else {
            print("ProductPurchaseManager: Can't call start more than once. productId=\(self.productIdentifier) ; offerId=\(offer.id)")
            return
        }
        
        guard cleengAPI.cleengLoginState == .loggedIn else {
            print("ProductPurchaseManager: Can't call start before user made login")
            let error = NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.invalideCustomerToken.rawValue, userInfo: nil) as Error
            
            onCompletion(.failed(error: error, retry: nil))
            return
        }
        
        self.onCompletion = onCompletion
        print("Start subscribe to offer \(offer.id) with product \(self.productIdentifier)")
        if let purchase = purchase , purchase.needsFinishTransaction || product == nil {
            loadReceipt()
        } else {
            startPurchasing()
        }
    }
    
    /// Purchase the StoreKit product
    private func startPurchasing() {
        assert(Thread.isMainThread, "Need to be called on main thread")
        
        guard let product = self.product else {
            assert(false, "Product is a must")
            failed(withError: NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.noStoreProduct.rawValue, userInfo: nil) as Error, retry: nil)
            return
        }
        
        guard state == .initial else {
            assert(false, "Called when state is \(state)")
            failed(withError: NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error, retry: nil)
            return
        }
        
        print("Start purchasing product \(self.productIdentifier)")
        
        state = .purchaseFromAppStore
        SwiftyStoreKit.purchaseProduct(product, atomically: false) { [weak self] (result) in
            guard let strongSelf = self else { return }
            
            switch result {
            case .success(let purchase):
                strongSelf.purchase = purchase
                print("[StoreKit Purchasing] Purchase Success: \(purchase.productId)")
                DispatchQueue.onMain {
                    strongSelf.loadReceipt()
                }
            case .error(let error):
                
                var canRetry: Bool = false
                switch error.code {
                case .unknown: print("[StoreKit Purchasing] Unknown error. Please contact support")
                case .clientInvalid:
                    print("[StoreKit Purchasing] Not allowed to make the payment")
                    canRetry = true
                case .paymentCancelled:
                    print("[StoreKit Purchasing] User cancelled purchase ")
                    canRetry = true
                case .paymentInvalid:
                    print("[StoreKit Purchasing] The purchase identifier was invalid")
                    canRetry = true
                case .paymentNotAllowed: print("[StoreKit Purchasing] The device is not allowed to make the payment")
                case .storeProductNotAvailable: print("[StoreKit Purchasing] The product is not available in the current storefront")
                case .cloudServicePermissionDenied: print("[StoreKit Purchasing] Access to cloud service information is not allowed")
                case .cloudServiceNetworkConnectionFailed: print("[StoreKit Purchasing] Could not connect to the network")
                case .cloudServiceRevoked: print("[StoreKit Purchasing] User has revoked permission to use this cloud service")
                default:
                    break
                }
                
                DispatchQueue.onMain {
                    var retry: (() -> Void)?
                    if canRetry {
                        retry = { [weak self] in
                            guard let strongSelf = self else { return }
                            
                            strongSelf.state = .initial
                            strongSelf.startPurchasing()
                        }
                    }
                    
                    strongSelf.failed(withError: error, retry:retry)
                }
            }
        }
    }
    
    /// Load StoreKit receipt
    private func loadReceipt() {
        assert(Thread.isMainThread, "Need to be called on main thread")
        
        let currentState = self.state
        
        guard state == .initial || state == .purchaseFromAppStore || (state == .verifyOnCleeng && forceRefreshReceipt) else {
            assert(false, "Called when state is \(state)")
            failed(withError: NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error, retry: nil)
            return
        }
        
        if let original = purchase?.originalTransaction {
            print("Start loading receipt for transaction \(purchase?.transaction.transactionIdentifier ?? "nil") (original: \(original.transactionIdentifier ?? "nil"))")
        } else {
            print("Start loading receipt for transaction \(purchase?.transaction.transactionIdentifier ?? "nil")")
        }
        
        state = .loadReceipt
        SwiftyStoreKit.fetchReceipt(forceRefresh: forceRefreshReceipt) { [weak self] (result) in
            guard let strongSelf = self else { return }
            
            switch result {
            case .success(let receiptData):
                let encryptedReceipt = receiptData.base64EncodedString(options: [])
                DispatchQueue.onMain {
                    strongSelf.encryptedReceipt = encryptedReceipt
                    strongSelf.subscribe()
                }
            case .error(let error):
                DispatchQueue.onMain {
                    strongSelf.failed(withError: error, retry: { [weak self] in
                        guard let strongSelf = self else { return }
                        
                        if let _ = strongSelf.purchase {
                            strongSelf.state = currentState
                            strongSelf.loadReceipt()
                        } else {
                            strongSelf.failed(withError: NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error, retry: nil)
                        }
                    })
                }
            }
        }
    }
    
    /// Sync Cleeng with new/restored transaction to activate the offer
    fileprivate func subscribe() {
        assert(Thread.isMainThread, "Need to be called on main thread")
        
        guard state == .loadReceipt else {
            assert(false, "Called when state is \(state)")
            failed(withError: NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error, retry: nil)
            return
        }
        
        state = .verifyOnCleeng
        guard let purchase = purchase , let transactionId = (purchase.originalTransaction?.transactionIdentifier ?? purchase.transaction.transactionIdentifier) else {
            let error = NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error
            failed(withError: error, retry: nil)
            return
        }
        
        print("Start subscribe on Cleeng with transaction \(transactionId)")
        
        cleengAPI.subscribe(for: offer, transactionId: transactionId, isRestoredTransaction: (purchase.transaction.transactionState == .restored), productId: purchase.productId, receipt: encryptedReceipt) { [weak self] (canVerify, error) in
            guard let strongSelf = self else { return }
            
            if canVerify {
                strongSelf.verifyOnCleeng()
            } else {
                if !(strongSelf.forceRefreshReceipt) {
                    strongSelf.encryptedReceipt = nil
                    strongSelf.forceRefreshReceipt = true
                    strongSelf.state = .verifyOnCleeng
                    strongSelf.loadReceipt()
                } else {
                    let err = error ?? (NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue, userInfo: nil) as Error)
                    strongSelf.failed(withError: err, retry: nil)
                }
            }
        }
    }
    
    /// Check with cleeng if offer's access status has changed to `granted`
    @objc private func verifyOnCleeng() {
        assert(Thread.isMainThread, "Need to be called on main thread")
        
        guard state == .verifyOnCleeng else { return }
        
        print("Verify on Cleeng access status for offer \(offer.id)")
        if let cleengVerifyStartTime = cleengVerifyStartTime , Date().timeIntervalSince(cleengVerifyStartTime) > 60 {
            invalidateTimer()
            
            if !forceRefreshReceipt {
                encryptedReceipt = nil
                forceRefreshReceipt = true
                loadReceipt()
            } else {
                let error = NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.subscriptionVerificationTimeOut.rawValue, userInfo: nil) as Error
                failed(withError: error, retry: { [weak self] in
                    guard let strongSelf = self else { return }
                    
                    strongSelf.state = .verifyOnCleeng
                    strongSelf.verifyOnCleeng()
                })
            }
            return
        }
        
        if cleengVerifyTimer == nil {
            cleengVerifyStartTime = Date()
            cleengVerifyTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(ProductPurchaseManager.verifyOnCleeng), userInfo: nil, repeats: true)
        }
        
        cleengAPI.loadSubscription(forOffer: offer.id) { [weak self] (offers, error) in
            guard let strongSelf = self else { return }
            
            if let offer = offers?.first , offer.accessGranted {
                strongSelf.offer = offer
                strongSelf.loadTokens()
            }
        }
    }
    
    /// After offer's access status has changed to `granted`, load all users' tokens again, to get the new token.
    @objc private func loadTokens() {
        assert(Thread.isMainThread, "Need to be called on main thread")
        
        print("Access granted for offer \(offer.id). Load tokens")
        
        self.state = .loadTokens
        let retryCount = ((cleengVerifyTimer?.userInfo as? [String:Any])?["retryCount"] as? Int) ?? 0
        invalidateTimer()
        
        cleengAPI.extendToken { [weak self] (succeeded, error) in
            guard let strongSelf = self else { return }
            if succeeded {
                strongSelf.accessGranted()
            } else if retryCount < 3 {
                strongSelf.cleengVerifyTimer = Timer.scheduledTimer(timeInterval: 2 + (0.5 * TimeInterval(retryCount)), target: strongSelf, selector: #selector(ProductPurchaseManager.loadTokens), userInfo: ["retryCount" : (retryCount + 1)], repeats: false)
            } else {
                let error = error ?? NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.loadTokensTimeOut.rawValue, userInfo: nil) as Error
                strongSelf.failed(withError: error, retry: { [weak strongSelf] in
                    guard let strongSelf = strongSelf else { return }
                    
                    strongSelf.state = .loadTokens
                    strongSelf.loadTokens()
                })
            }
        }
    }
    
    /// Update on access granted
    private func accessGranted() {
        assert(Thread.isMainThread, "Need to be called on main thread")
        
        print("Access granted for offer \(offer.id)")
        
        self.state = .finished
        invalidateTimer()
        
        if let purchase = purchase , purchase.needsFinishTransaction {
            SwiftyStoreKit.finishTransaction(purchase.transaction)
        }
        
        let block = onCompletion
        onCompletion = nil
        block?(.succeeded)
    }
    
    /// Invalidate retry timer
    private func invalidateTimer() {
        assert(Thread.isMainThread, "Need to be called on main thread")
        
        cleengVerifyTimer?.invalidate()
        cleengVerifyTimer = nil
        cleengVerifyStartTime = nil
    }
    
    /// Update on failure
    private func failed(withError error: Error, retry: (() -> Void)?) {
        assert(Thread.isMainThread, "Need to be called on main thread")
        
        guard state != .failed else { return }
        
        invalidateTimer()
        
        var errorToForward = error
        if let receiptError = error as? ReceiptError {
            switch receiptError {
            case .networkError(let error):
                errorToForward = error
            case .jsonDecodeError(_):
                errorToForward = CleengLoginAndSubscribeApi.ErrorType.storeJsonDecodeError.error
            case .noReceiptData:
                errorToForward = CleengLoginAndSubscribeApi.ErrorType.storeNotHaveReceiptData.error
            case .noRemoteData:
                errorToForward = CleengLoginAndSubscribeApi.ErrorType.storeNoRemoteData.error
            case .requestBodyEncodeError(let error):
                errorToForward = error
            case .receiptInvalid(_, let status):
                errorToForward = NSError(domain: kCleengLoginAndSubscribeApiErrorDomain, code: CleengLoginAndSubscribeApi.ErrorType.storeReceiptInvalid.rawValue, userInfo: [NSLocalizedDescriptionKey : "Something went wrong. Code: \(status)"])
            }
        }
        
        self.state = .failed
        
        if let purchase = purchase , purchase.transaction.transactionState == .restored && purchase.needsFinishTransaction {
            SwiftyStoreKit.finishTransaction(purchase.transaction)
        }
        
        let block = onCompletion
        onCompletion = nil
        block?(.failed(error: errorToForward, retry: retry))
    }
}

/// `SwiftyStoreKit` has multiple purchase types. We don't care for the differences between them most of time, so this protocol allow us to use those types at the same places
protocol StorePurchase {
    var productId: String { get }
    var quantity: Int { get }
    var transaction: PaymentTransaction { get }
    var originalTransaction: PaymentTransaction? { get }
    var needsFinishTransaction: Bool { get }
}

extension Purchase : StorePurchase {}
extension PurchaseDetails : StorePurchase {}
