//
//  CleengLoginAndSubscriptionController.swift
//  CleengPlugin
//
//  Created by Yossi Avramov on 28/05/2018.
//  Copyright © 2018 Applicaster. All rights reserved.
//

import UIKit
import ZappPlugins
import ZappLoginPluginsSDK
import SafariServices

public enum CleengLoginAndSubscriptionLaunch : Int {
    case none
    case signIn
    case signUp
    case subscriptionsList
}

internal enum PurchaseOnLogin {
    case buy(product: SKProduct, offer: CleengOffer)
    case redeem(code: String, offer: CleengOffer)
}

internal enum AuthenticationType {
    case unknown
    case inAppPurchase
    case coupon
}

protocol CleengLoginAndSubscriptionManager : NSObjectProtocol {
    
    
    var api: CleengLoginAndSubscribeApi! { get }
    var helpURL: URL? { get }
    var isFacebookLoginAvailable: Bool { get }
    var isRestoreAvailable: Bool { get }
    var isCouponRedeemAvailable: Bool { get }
    var purhcaseOnLogin: PurchaseOnLogin? { get set }
    
    var digicelUser: Bool { get }
    
    func localizedString(for key: ZappCleengLoginLocalization.Key) -> String?
    func localizedString(for key: ZappCleengLoginLocalization.Key, defaultString: String?) -> String?
    func offerLocalizedTagString(for offerIdOrCoupon: String) -> String?
    
    func showSignIn(animated: Bool, makeRoot: Bool)
    func showSignIn(animated: Bool, makeRoot: Bool, email: String?, password: String?)
    func showSignUp(animated: Bool, makeRoot: Bool)
    func showRestore(animated: Bool)
    func showSubscriptionsList(animated: Bool, makeRoot: Bool)
    func showLoading(for vc: UIViewController)
    func showLoading(for vc: UIViewController, message: String?)
    func hideLoading(for vc: UIViewController?)
    func hideLoading(for vc: UIViewController?, force: Bool)
    func userDidSelectToClose()
    func authenticated(with type: AuthenticationType, showAlert: Bool)
    func fatalErrorOccured(withTitle title: String?, message: String?, suggestContact: Bool)
}

public class CleengLoginAndSubscriptionController : UINavigationController, CleengLoginAndSubscriptionManager {
    
    public var digicelUserSubscription: Bool?
    var digicelUser: Bool { return digicelUserSubscription ?? false }
    private var cleengStoryboard: UIStoryboard!
    private(set) var api: CleengLoginAndSubscribeApi!
    private var configuration: ZappCleengConfiguration?
    var completion: ((ZPLoginOperationStatus) -> Void)?
    var helpURL: URL? { return configuration?.helpURL }
    var isFacebookLoginAvailable: Bool { return configuration?.facebookLoginSupported ?? true }
    var isRestoreAvailable: Bool { return configuration?.restoreSupported ?? true }
    var isCouponRedeemAvailable: Bool { return configuration?.couponRedeemAvailable ?? false }
    
    func localizedString(for key: ZappCleengLoginLocalization.Key) -> String? { return configuration?.localization.localizedString(for: key) }
    func localizedString(for key: ZappCleengLoginLocalization.Key, defaultString: String?) -> String? { return configuration?.localization.localizedString(for: key, defaultString: defaultString) }
    func offerLocalizedTagString(for offerIdOrCoupon: String) -> String? { return configuration?.localization.offerLocalizedTagString(for: offerIdOrCoupon) }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
  public  init(startWith: CleengLoginAndSubscriptionLaunch, api: CleengLoginAndSubscribeApi, configuration: ZappCleengConfiguration?) {
        let podBundle = Bundle(for: CleengLoginAndSubscriptionController.self)
        let bundleURL = podBundle.url(forResource: "cleeng-storyboard", withExtension: "bundle")!
        let bundle = Bundle(url: bundleURL)!
        
        let cleengStoryboard = UIStoryboard(name: "CleengMain", bundle: bundle)
        
        let vc: UIViewController!
        
        switch startWith {
        case .none:
            vc = nil
        case .signIn:
            print("Start with sign in")
            vc = cleengStoryboard.instantiateViewController(withIdentifier: "SignIn")
        case .signUp:
            print("Start with sign up")
            vc = cleengStoryboard.instantiateViewController(withIdentifier: "SignUp")
        case .subscriptionsList:
            print("Start with subscription")
            vc = cleengStoryboard.instantiateViewController(withIdentifier: "OffersList")
        }
        
        if let vc = vc {
            super.init(rootViewController: vc)
        } else {
            super.init(nibName: nil, bundle: nil)
        }
        
        (vc as? CleengLoginAndSubscriptionProtocol)?.manager = self
        
        self.cleengStoryboard = cleengStoryboard
        self.api = api
        self.configuration = configuration
        
        self.setNavigationBarHidden(true, animated: false)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return topViewController?.supportedInterfaceOrientations ?? super.supportedInterfaceOrientations
    }
    
    override public var childForStatusBarStyle: UIViewController? {
        return nil
    }
    
    override public var preferredStatusBarStyle: UIStatusBarStyle {
        return presentingViewController?.preferredStatusBarStyle ?? .default
    }
    
    //MARK: - CleengLoginAndSubscriptionManager
    var purhcaseOnLogin: PurchaseOnLogin?
    func showSignIn(animated: Bool, makeRoot: Bool) {
        showSignIn(animated: animated, makeRoot: makeRoot, email: nil, password: nil)
    }
    
    func showSignIn(animated: Bool, makeRoot: Bool, email: String?, password: String?) {
        print("Show sign in")
        var singInViewController: CleengSignInViewController!
        for vc in viewControllers {
            if let sign = vc as? CleengSignInViewController {
                singInViewController = sign
                break
            }
        }
        
        if let singInViewController = singInViewController {
            popToViewController(singInViewController, animated: animated)
            if let email = email , let password = password {
                singInViewController.setup(email: email, password: password)
            }
            
        } else {
            let vc = cleengStoryboard.instantiateViewController(withIdentifier: "SignIn")
            (vc as? CleengLoginAndSubscriptionProtocol)?.manager = self
            if let email = email , let password = password , let signInVC = vc as? CleengSignInViewController {
                signInVC.setup(email: email, password: password)
            }
            
            if makeRoot {
                setViewControllers([vc], animated: animated)
            } else {
                pushViewController(vc, animated: animated)
            }
        }
    }
    
    func showSignUp(animated: Bool, makeRoot: Bool) {
        print("Show sign up")
        var singUpViewController: CleengSignUpViewController!
        for vc in viewControllers {
            if let sign = vc as? CleengSignUpViewController {
                singUpViewController = sign
                break
            }
        }
        
        if let singUpViewController = singUpViewController {
            popToViewController(singUpViewController, animated: animated)
        } else {
            let vc = cleengStoryboard.instantiateViewController(withIdentifier: "SignUp")
            (vc as? CleengLoginAndSubscriptionProtocol)?.manager = self
            if makeRoot {
                setViewControllers([vc], animated: animated)
            } else {
                pushViewController(vc, animated: animated)
            }
        }
    }
    
    func showRestore(animated: Bool) {
        print("Show restore")
        var restoreViewController: CleengRestoreViewController!
        for vc in viewControllers {
            if let restore = vc as? CleengRestoreViewController {
                restoreViewController = restore
                break
            }
        }
        
        if let restoreViewController = restoreViewController {
            popToViewController(restoreViewController, animated: animated)
        } else {
            let vc = cleengStoryboard.instantiateViewController(withIdentifier: "Restore")
            (vc as? CleengLoginAndSubscriptionProtocol)?.manager = self
            pushViewController(vc, animated: animated)
        }
    }
    
    func showSubscriptionsList(animated: Bool, makeRoot: Bool) {
        print("Show offers list")
        var offersViewController: CleengOffersViewController!
        for vc in viewControllers {
            if let offers = vc as? CleengOffersViewController {
                offersViewController = offers
                break
            }
        }
        
        if let offersViewController = offersViewController {
            popToViewController(offersViewController, animated: animated)
        } else {
            let vc = cleengStoryboard.instantiateViewController(withIdentifier: "OffersList")
            (vc as? CleengLoginAndSubscriptionProtocol)?.manager = self
            if makeRoot {
                setViewControllers([vc], animated: animated)
            } else {
                pushViewController(vc, animated: animated)
            }
        }
    }
    
    func userDidSelectToClose() {
        if let vc = presentingViewController {
            let c = completion
            completion = nil
            vc.dismiss(animated: true, completion: {
                c?(.cancelled)
            })
        }
        else {
            completion?(.cancelled)
        }
    }
    
	func authenticated(with type: AuthenticationType, showAlert: Bool = true) {
		
		var alertActionClosure: (() -> Void)?
		alertActionClosure = { [weak self] in
			guard let strongSelf = self else { return }
			
			if let vc = strongSelf.presentingViewController {
				let c = strongSelf.completion
				strongSelf.completion = nil
				vc.dismiss(animated: true, completion: {
					c?(.completedSuccessfully)
				})
			} else {
				strongSelf.completion?(.completedSuccessfully)
			}
		}
		
		if !showAlert {
			alertActionClosure?()
			return
		}
		
		guard let alert = try? CleengLoginAlertController.alert(from: cleengStoryboard) else {
            if let vc = presentingViewController {
                let c = completion
                completion = nil
                vc.dismiss(animated: true, completion: {
                    c?(.completedSuccessfully)
                })
            } else {
                completion?(.completedSuccessfully)
            }
            return
        }
        
        alert.manager = self
        alert.alertTitle = self.localizedString(for: .alertConfirmTitle)
        
        if type == .coupon {
            alert.alertMessage = self.localizedString(for: .redeemCouponSuccessMessage)
		} else {
			alert.alertMessage = self.localizedString(for: .alertConfirmMessage)
		}
		
		alert.setAction(withTitle: self.localizedString(for: .alertConfirmAction) ?? NSLocalizedString("OK", comment: "OK"), action: alertActionClosure)
        alert.presentMe(from: self)
    }
    
    func fatalErrorOccured(withTitle title: String?, message: String?, suggestContact: Bool) {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: localizedString(for: .alertCancelAction, defaultString: NSLocalizedString("Cancel", comment: "Cancel")), style: .cancel, handler: { [weak self] _ in
            guard let strongSelf = self else { return }
            if let vc = strongSelf.presentingViewController {
                let c = strongSelf.completion
                strongSelf.completion = nil
                vc.dismiss(animated: true, completion: {
                    c?(.failed)
                })
            } else {
                strongSelf.completion?(.failed)
            }
        }))
        
        if suggestContact , let url = helpURL {
            alert.addAction(UIAlertAction(title: localizedString(for: .alertContactUsAction, defaultString: NSLocalizedString("Contact us", comment: "Contact us")), style: .default, handler: { [weak self] _ in
                guard let strongSelf = self else { return }
                
                if let vc = strongSelf.presentingViewController {
                    var didOpenUrl = false
                    if UIApplication.shared.canOpenURL(url) && url.absoluteString.contains("://") {
                        didOpenUrl = true
                        UIApplication.shared.openURL(url)
                    }
                    
                    let c = strongSelf.completion
                    strongSelf.completion = nil
                    vc.dismiss(animated: true, completion: {
                        if !didOpenUrl {
                            let safari = SFSafariViewController(url: url)
                            UIViewController.topMostViewController?.present(safari, animated: true, completion: nil)
                        }
                        c?(.failed)
                    })
                } else {
                    strongSelf.completion?(.failed)
                }
            }))
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    private var loadingVC: CleengLoadingViewController?
    func showLoading(for vc: UIViewController) {
        self.showLoading(for: vc, message: nil)
    }
    
    func showLoading(for vc: UIViewController, message: String?) {
        
        if let loading = loadingVC {
            if loading.parent == nil || loading.parent! !== vc {
                loading.willMove(toParent: vc)
                loading.view.removeFromSuperview()
                loading.removeFromParent()

                vc.addChild(loading)
                vc.view.addSubview(loading.view)
                vc.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[loading]-0-|", options: [], metrics: nil, views: ["loading" : loading.view]))
                vc.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[loading]-0-|", options: [], metrics: nil, views: ["loading" : loading.view]))
                loading.didMove(toParent: vc)
            }
            
            if loading.activity.isAnimating == false {
                loading.activity.startAnimating()
            }
            
            if let message = message {
                loading.messageLabel.text = message
                loading.messageLabel.isHidden = false
            } else {
                loading.messageLabel.text = nil
                loading.messageLabel.isHidden = true
            }
        } else {
            let loading = cleengStoryboard.instantiateViewController(withIdentifier: "Loading") as! CleengLoadingViewController
            loadingVC = loading
            
            loading.willMove(toParent: vc)
            vc.addChild(loading)
            vc.view.addSubview(loading.view)
            loading.view.isUserInteractionEnabled = true
            loading.view.translatesAutoresizingMaskIntoConstraints = false
            vc.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[loading]-0-|", options: [], metrics: nil, views: ["loading" : loading.view]))
            vc.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[loading]-0-|", options: [], metrics: nil, views: ["loading" : loading.view]))
            loading.didMove(toParent: vc)
            
            loading.activity.startAnimating()
            if let message = message {
                loading.messageLabel.text = message
                loading.messageLabel.isHidden = false
            } else {
                loading.messageLabel.text = nil
                loading.messageLabel.isHidden = true
            }
        }
    }
    
    func hideLoading(for vc: UIViewController?) {
        self.hideLoading(for: vc, force: false)
    }
    
    func hideLoading(for vc: UIViewController?, force: Bool) {
        if let loading = loadingVC , loading.parent === vc || force {
            loadingVC = nil
            loading.willMove(toParent: nil)
            loading.view.removeFromSuperview()
            loading.removeFromParent()
            loading.didMove(toParent: nil)
        }
    }
}

protocol CleengLoginAndSubscriptionProtocol : NSObjectProtocol {
    var manager: CleengLoginAndSubscriptionManager? { get set }
}
