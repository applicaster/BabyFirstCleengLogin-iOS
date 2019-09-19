//
//  CleengLoginSignupViewControllers.swift
//  CleengPlugin
//
//  Created by Yossi Avramov on 28/05/2018.
//  Copyright © 2018 Applicaster. All rights reserved.
//

import UIKit
import FBSDKCoreKit
import FacebookLogin
import FacebookCore
import ZappPlugins
import SafariServices

internal class _CleengBaseSignViewController : UIViewController, UITextFieldDelegate, CleengLoginAndSubscriptionProtocol {
    @objc @IBOutlet fileprivate weak var backButton: UIButton!
    @objc @IBOutlet fileprivate weak var closeButton: UIButton!
    
    @objc @IBOutlet fileprivate weak var backgroundImageView: UIImageView!
    @objc @IBOutlet fileprivate weak var backgroundOverlay: UIView!
    
    @objc @IBOutlet private weak var logoImageView: UIImageView!
    @objc @IBOutlet fileprivate weak var logoBottomSpacing: NSLayoutConstraint!
    @objc @IBOutlet private weak var logoImageViewMaxHeight: NSLayoutConstraint!
    
    @objc @IBOutlet fileprivate weak var emailTextField: UITextField!
    @objc @IBOutlet fileprivate weak var emailTextFieldBackgroundImageView: UIImageView!
    
    @objc @IBOutlet fileprivate weak var passwordTextField: UITextField!
    @objc @IBOutlet fileprivate weak var passwordTextFieldBackgroundImageView: UIImageView!
    
    @objc @IBOutlet fileprivate weak var signButton: UIButton!
    @objc @IBOutlet fileprivate weak var goToSignButton: UIButton!
    @objc @IBOutlet fileprivate weak var facebookButton: UIButton!
    
    @objc @IBOutlet fileprivate weak var restoreButton: UIButton!
    @objc @IBOutlet fileprivate weak var restoreViewSpaceFromGoToSignButton: NSLayoutConstraint!
    
    @objc @IBOutlet fileprivate weak var signOrFacebookButtonsLabel: UILabel!
    
    //Outlets for adjust size for iPhone 4s, 5 & SE
    @objc @IBOutlet fileprivate weak var signTextsStackView: UIStackView!
    @objc @IBOutlet fileprivate weak var emailTextAreaHeight: NSLayoutConstraint!
    @objc @IBOutlet fileprivate weak var passwordTextAreaHeight: NSLayoutConstraint!
    @objc @IBOutlet fileprivate weak var signButtonHeight: NSLayoutConstraint!
    @objc @IBOutlet fileprivate weak var signTextsAndActionStackView: UIStackView!
    @objc @IBOutlet fileprivate weak var facebookButtonHeight: NSLayoutConstraint!
    @objc @IBOutlet fileprivate weak var mainStackView: UIStackView!
    @objc @IBOutlet fileprivate weak var mainStackViewCenterConstraint: NSLayoutConstraint!
    @objc @IBOutlet fileprivate weak var restoreViewHeight: NSLayoutConstraint!
    
    weak var manager: CleengLoginAndSubscriptionManager? {
        didSet {
            if isViewLoaded {
                signConfigureViews()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        backButton.setTitle(nil, for: .normal)
        backButton.backgroundColor = UIColor.clear
        
        closeButton.setTitle(nil, for: .normal)
        closeButton.backgroundColor = UIColor.clear
        
        signButton.backgroundColor = UIColor.clear
        signButton.tintColor = UIColor.clear
        facebookButton.backgroundColor = UIColor.clear
        facebookButton.tintColor = UIColor.clear
        facebookButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
        
        if let lbl = restoreButton.titleLabel {
            lbl.numberOfLines = 2
            lbl.textAlignment = .center
        }
        
        if let nav = navigationController , nav.viewControllers.first === self {
            backButton.isHidden = true
        }
        
        signConfigureViews()
        restoreButton.superview?.isHidden = !(manager?.isRestoreAvailable ?? true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(_CleengBaseSignViewController.keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(_CleengBaseSignViewController.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillLayoutSubviews() {
        
        guard !isAdjustingLayoutForKeyboardOpen else { return }
        
        let height = view.bounds.height
        if height < 500 {
            logoBottomSpacing.constant = 8
            logoImageViewMaxHeight.constant = 80
            signTextsAndActionStackView.spacing = 15
            
            emailTextAreaHeight.constant = 37
            passwordTextAreaHeight.constant = 37
            signButtonHeight.constant = 37
            facebookButtonHeight.constant = 37
            restoreViewSpaceFromGoToSignButton.constant = 8
            restoreViewHeight.constant = 45
        }
        
        super.viewWillLayoutSubviews()
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if let nav = parent as? UINavigationController , nav.viewControllers.isEmpty || nav.viewControllers.first === self {
            backButton?.isHidden = true
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UI_USER_INTERFACE_IDIOM() == .phone {
            return .portrait
        } else {
            return .landscape
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection == nil || previousTraitCollection!.horizontalSizeClass == .unspecified || previousTraitCollection!.verticalSizeClass == .unspecified {
            if let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate {
                backgroundImageView.setupCleengBackground(with: stylesManager)
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate {
            coordinator.animateAlongsideTransition(in: backgroundImageView, animation: { (context) in
                self.backgroundImageView.setupCleengBackground(with: stylesManager)
            }, completion: nil)
        }
    }
    
    fileprivate var isAdjustingLayoutForKeyboardOpen: Bool { return keyboardWillHide != nil }
    private var keyboardWillHide: (() -> Void)?
    @objc private func keyboardWillShow(_ notification: Notification?) {
        let height = view.bounds.height
        guard height > 500 && height < 600 else { return }
        
        guard ((notification?.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? NSNumber)?.boolValue ?? true) else {
            return
        }
        
        let signTextsAndActionStackViewSpacing = signTextsAndActionStackView.spacing
        let logoBottomSpacingConstant = logoBottomSpacing.constant
        
        let additional = additionalKeyboardWillShowUpdates()
        if keyboardWillHide == nil {
            keyboardWillHide = { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.signTextsAndActionStackView.spacing = signTextsAndActionStackViewSpacing
                strongSelf.logoBottomSpacing.constant = logoBottomSpacingConstant
                strongSelf.mainStackViewCenterConstraint.constant = 0
                additional?.reverseAnimation()
                strongSelf.view.layoutIfNeeded()
            }
        }
        
        let duration = (notification?.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.3
        let curveValue = (notification?.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 0
        let options: UIView.AnimationOptions = [UIView.AnimationOptions(rawValue: curveValue), .beginFromCurrentState]
        
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            self.signTextsAndActionStackView.spacing = 15
            self.logoBottomSpacing.constant = 10
            self.mainStackViewCenterConstraint.constant = -20
            additional?.willShowAnimation()
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    @objc private func keyboardWillHide(_ notification: Notification?) {
        guard let willHideAnimation = keyboardWillHide else { return }
        
        keyboardWillHide = nil
        let duration = (notification?.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.3
        let curveValue = (notification?.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 0
        let options: UIView.AnimationOptions = [UIView.AnimationOptions(rawValue: curveValue), .beginFromCurrentState]
        
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: willHideAnimation, completion: nil)
    }
    
    fileprivate func additionalKeyboardWillShowUpdates() -> (willShowAnimation: () -> Void, reverseAnimation: () -> Void)? {
        return nil
    }
    
    @objc @IBAction fileprivate func signWithFacebook() {
        showLoading()
        
        emailTextField.resignFirstResponder()
        passwordTextField.resignFirstResponder()
        
        if let token = AccessToken.current,
            token.permissions.contains(Permission(stringLiteral: "email")) {
            let facebookID = token.userID
            getFacebookEmailAndSignUp(withFacebook: facebookID)
        } else {
            print("Start to login to Facebook")
            let loginManager = LoginManager()
            loginManager.logIn(permissions: [.email], viewController: self) { [weak self] (result: LoginResult) in
                guard let strongSelf = self else {
                    return
                }
                
                switch result {
                case .success(let grantedPermissions, let declinedPermissions, let token):
                    let facebookID = token.userID
                    if grantedPermissions.contains(Permission(stringLiteral: "email")) {
                        DispatchQueue.onMain {
                            strongSelf.getFacebookEmailAndSignUp(withFacebook: facebookID)
                        }
                    } else {
                        DispatchQueue.onMain {
                            print("Facebook email permission wasn't granted or user id is nil")
                            loginManager.logOut()
                            strongSelf.hideLoading()
                            
                            if declinedPermissions.contains(Permission(stringLiteral: "email")) {
                                
                                let alert = UIAlertController(title: strongSelf.manager?.localizedString(for: .errorFacebookEmailPermissionRequiredTitle), message: strongSelf.manager?.localizedString(for: .errorFacebookEmailPermissionRequiredMessage), preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: strongSelf.manager?.localizedString(for: .alertCancelAction, defaultString: NSLocalizedString("Cancel", comment: "Cancel")), style: .cancel, handler: nil))
                                alert.addAction(UIAlertAction(title: strongSelf.manager?.localizedString(for: .alertRetryAction, defaultString: NSLocalizedString("Retry", comment: "Retry")), style: .default, handler: { _ in
                                    strongSelf.signWithFacebook()
                                }))
                                strongSelf.present(alert, animated: true, completion: nil)
                            } else if grantedPermissions.contains(Permission(stringLiteral: "email")) {
                                //User id is nil
                                strongSelf.signWithFacebook()
                            }
                        }
                    }
                case .cancelled:
                    DispatchQueue.onMain {
                        strongSelf.hideLoading()
                    }
                case .failed(let error):
                    DispatchQueue.onMain {
                        print("Facebook login failed: \((error))")
                        strongSelf.hideLoading()
                        
                        let alert = UIAlertController(title: strongSelf.manager?.localizedString(for: .errorInternalTitle), message: error.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: strongSelf.manager?.localizedString(for: .alertCancelAction, defaultString: NSLocalizedString("Cancel", comment: "Cancel")), style: .cancel, handler: nil))
                        strongSelf.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    @objc @IBAction fileprivate func back() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc @IBAction fileprivate func close() {
        manager?.userDidSelectToClose()
    }
    
    @objc @IBAction fileprivate func restore() {
        manager?.showRestore(animated: true)
    }
    
    fileprivate func showLoading(with message: String? = nil) {
        manager?.showLoading(for: self, message: message)
    }
    
    fileprivate func hideLoading() {
        manager?.hideLoading(for: self)
    }
    
    private func getFacebookEmailAndSignUp(withFacebook facebookID: String) {
        let emailRequest = GraphRequest(graphPath: "me", parameters: ["fields":"email"])
        emailRequest.start { [weak self](_, response, error) in
            guard let strongSelf = self else {
                return
            }
            
            DispatchQueue.onMain {
                if let error = error {
                    print("Facebook Graph request error: \(error)")
                    let alert = UIAlertController(title: strongSelf.manager?.localizedString(for: .errorInternalTitle, defaultString: NSLocalizedString("Error", comment: "Error")), message: strongSelf.manager?.localizedString(for: .errorInternalMessage), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: strongSelf.manager?.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")), style: .default, handler: nil))
                    strongSelf.present(alert, animated: true, completion: nil)
                }
                else if let result = response as? NSDictionary {
                    if let email = result["email"] as? String {
                        strongSelf.manager?.api?.signup(withFacebook: facebookID, email: email, completion: { [weak self] (succeeded, error) in
                            self?.handleCleengSignResult(succeeded: succeeded, error: error)
                        })
                    }
                }
            }
        }
    }
    
    fileprivate func handleCleengSignResult(succeeded: Bool, error: Error?) {
        
        if succeeded && manager?.purhcaseOnLogin != nil {
            hideLoading()
        }
        
        if succeeded {
            print("Login/Signup succeeded")
            if manager?.api.hasAuthorizationTokenForCurrentItem ?? false {
                manager!.authenticated(with: .inAppPurchase, showAlert: true)
            } else if let purhcaseOnLogin = manager?.purhcaseOnLogin {
                let manager = self.manager!
                showLoading()
                manager.purhcaseOnLogin = nil
                
                switch purhcaseOnLogin {
                case let .buy(product, offer):
                    manager.api.purchaseProduct(product, forOffer: offer, completion: { [weak self, weak manager] (result) in
                        guard let strongSelf = self, let manager = manager else { return }
                        
                        switch result {
                        case .succeeded:
                            manager.hideLoading(for: strongSelf)
                            if manager.api.hasAuthorizationTokenForCurrentItem {
                                manager.authenticated(with: .inAppPurchase, showAlert: true)
                            } else {
                                assert(false, "That shouldn't happen. The user purchased a subscription and doesn't have token for it")
                            }
                        case .fatalFailure(let error):
                            manager.hideLoading(for: strongSelf)
                            manager.fatalErrorOccured(withTitle: manager.localizedString(for: .errorInternalTitle, defaultString: NSLocalizedString("Error", comment: "Error")), message: error.localizedDescription, suggestContact: true)
                        case .failedButCanRetry(let error, let retry, let userSelectNotToRetry):
                            if let err = (error as? SKError) , err.code == SKError.Code.paymentCancelled {
                                manager.hideLoading(for: strongSelf)
                                userSelectNotToRetry()
                                manager.showSubscriptionsList(animated: true, makeRoot: true)
                                return
                            }
                            
                            let alert = UIAlertController(title: manager.localizedString(for: .errorInternalTitle, defaultString: NSLocalizedString("Error", comment: "Error")), message: error.localizedDescription, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: manager.localizedString(for: .alertCancelAction, defaultString: NSLocalizedString("Cancel", comment: "Cancel")), style: .cancel, handler: { _ in
                                manager.hideLoading(for: strongSelf)
                                userSelectNotToRetry()
                                manager.showSubscriptionsList(animated: true, makeRoot: true)
                            }))
                            
                            alert.addAction(UIAlertAction(title: manager.localizedString(for: .alertRetryAction, defaultString: NSLocalizedString("Retry", comment: "Retry")), style: .default, handler: { _ in
                                retry()
                            }))
                            strongSelf.present(alert, animated: true, completion: nil)
                        }
                    })
                case let .redeem(code, offer):
                    manager.api.redeemCode(code, offer: offer, completion: { [weak self, weak manager] (result) in
                        guard let strongSelf = self, let manager = manager else { return }
                        manager.hideLoading(for: strongSelf)
                        
                        switch result {
                        case .redeemed:
                            if manager.api.hasAuthorizationTokenForCurrentItem {
                                manager.authenticated(with: .coupon, showAlert: true)
                            } else {
                                assert(false, "That shouldn't happen. The user purchased a subscription and doesn't have token for it")
                            }
                        case .failed(let error):
                            let alert = UIAlertController(title: manager.localizedString(for: .errorInternalTitle, defaultString: NSLocalizedString("Error", comment: "Error")), message: error.localizedDescription, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: manager.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")), style: .cancel, handler: { _ in
                                manager.showSubscriptionsList(animated: true, makeRoot: true)
                            }))
                            strongSelf.present(alert, animated: true, completion: nil)
                        }
                    })
                }
                
            } else if let manager = manager {
                if let error = error as NSError? , (error.code == CleengLoginAndSubscribeApi.ErrorType.currentItemHasNoAuthorizationProvidersIDs.rawValue) || (error.code == CleengLoginAndSubscribeApi.ErrorType.offerNotExist.rawValue) {
                    
                    manager.fatalErrorOccured(withTitle: manager.localizedString(for: .errorInternalTitle, defaultString: NSLocalizedString("Error", comment: "Error")), message: manager.localizedString(for: .errorInternalMessage), suggestContact: true)
                } else if manager.api.hasAuthorizationTokenForCurrentItem {
					manager.authenticated(with: .unknown, showAlert: true)
                } else if let _ = manager.api.item {
                    manager.showSubscriptionsList(animated: true, makeRoot: true)
				} else {
					manager.authenticated(with: .unknown, showAlert: false)
				}
            }
            
        } else {
            self.manager?.hideLoading(for: self)
            print("Login failed: \(String(describing: error))")
            var showUnknownError = (error == nil)
            if let error = error as NSError? {
                switch error.code {
                case CleengLoginAndSubscribeApi.ErrorType.unknown.rawValue:
                    showUnknownError = true
                case CleengLoginAndSubscribeApi.ErrorType.anotherLoginOrSignupInProcess.rawValue:
                    assert(false, "Make login only once at a time")
                    showUnknownError = true
                case CleengLoginAndSubscribeApi.ErrorType.alreadyLoggedInWithAnotherUser.rawValue:
                    assert(false, "Presenting login screen while user already logged-in")
                    showUnknownError = true
                case CleengLoginAndSubscribeApi.ErrorType.inactiveCustomerAccount.rawValue:
                    
                    let alert = UIAlertController(title: manager?.localizedString(for: .errorInternalTitle, defaultString: NSLocalizedString("Error", comment: "Error")), message: manager?.localizedString(for: .errorInternalMessage), preferredStyle: .alert)
                    
                    alert.addAction(UIAlertAction(title: manager?.localizedString(for: .alertCancelAction, defaultString: NSLocalizedString("Cancel", comment: "Cancel")), style: .cancel, handler: nil))
                    
                    if let url = manager?.helpURL {
                        let actionTitle = manager?.localizedString(for: .alertContactUsAction, defaultString: NSLocalizedString("Contact us", comment: "Contact us"))
                        alert.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { [weak self] _ in
                            guard let strongSelf = self else { return }
                            
                            if UIApplication.shared.canOpenURL(url) && url.absoluteString.contains("://") {
                                UIApplication.shared.openURL(url)
                            } else {
                                let safari = SFSafariViewController(url: url)
                                strongSelf.present(safari, animated: true, completion: nil)
                            }
                        }))
                    }
                    
                    present(alert, animated: true, completion: nil)
                default:
                    showUnknownError = true
                }
            }
            
            if showUnknownError {
                let alert = UIAlertController(title: manager?.localizedString(for: .errorInternalTitle, defaultString: NSLocalizedString("Error", comment: "Error")), message: manager?.localizedString(for: .errorInternalMessage), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: manager?.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")), style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        }
    }
    
    //MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    //MARK: - Setup views
    private func signConfigureViews() {
        guard let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate else {
            return
        }
        
        facebookButton.isHidden = !(manager?.isFacebookLoginAvailable ?? false)
        signOrFacebookButtonsLabel.isHidden = facebookButton.isHidden
        
        backgroundImageView.setupCleengBackground(with: stylesManager)
        backgroundOverlay.setZappStyle(using: stylesManager, withBackgroundColor: .backgroundColor)
        closeButton.setZappStyle(using: stylesManager, withIconAsset: .closeIcon)
        backButton.setZappStyle(using: stylesManager, withIconAsset: .backIcon)
        logoImageView.setZappStyle(using: stylesManager, withAsset: .logo)
        emailTextFieldBackgroundImageView.setZappStyle(using: stylesManager, withAsset: .textFieldsBackground)
        passwordTextFieldBackgroundImageView.setZappStyle(using: stylesManager, withAsset: .textFieldsBackground)
        emailTextField.setZappStyle(using: stylesManager,
                                    textStyle: .defaultText,
                                    placeholder: manager?.localizedString(for: .emailPlaceholder))
        passwordTextField.setZappStyle(using: stylesManager,
                                       textStyle: .defaultText,
                                       placeholder: manager?.localizedString(for: .passwordPlaceholder))
        facebookButton.setZappStyle(using: stylesManager,
                                    withIconAsset: .facebookIcon,
                                    backgroundAsset: .facebookButtonBackground,
                                    title: manager?.localizedString(for: .facebookButton),
                                    style: .facebookButton)
        restoreButton.superview?.setZappStyle(using: stylesManager, withBackgroundColor: .bottomBackgroundColor)
        restoreButton.setAttributedZappStyle(using: stylesManager,
                                             attributedTitle: [
                                                (style: .actionDescription,
                                                 string: manager?.localizedString(for: .restoreDetails) ?? NSLocalizedString("If you already purchased an account", comment: "If you already purchased an account"),
                                                 additionalAttributes: nil),
                                                (style: .actionText,
                                                 string: manager?.localizedString(for: .restoreAction) ?? NSLocalizedString("Restore", comment: "Restore"),
                                                 additionalAttributes: nil)
            ])
        
        signOrFacebookButtonsLabel.setZappStyle(using: stylesManager,
                                                text: manager?.localizedString(for: .actionAlternative),
                                                style: .actionAlternativeText)
    }
}

internal class CleengSignInViewController : _CleengBaseSignViewController {
    
    @objc @IBOutlet private weak var resetPasswordButton: UIButton!
    override weak var manager: CleengLoginAndSubscriptionManager? {
        didSet {
            if isViewLoaded {
                signInConfigureViews()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        signInConfigureViews()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let resetPasswordVC = segue.destination as? CleengResetPasswordViewController {
            resetPasswordVC.manager = self.manager
        }
        
        super.prepare(for: segue, sender: sender)
    }
    
    func setup(email: String, password: String) {
        let _ = view
        emailTextField.text = email
        passwordTextField.text = password
    }
    
    @objc @IBAction private func signIn() {
        emailTextField.resignFirstResponder()
        passwordTextField.resignFirstResponder()
        
        guard let result = validateEmailAndPassword(emailTextField: emailTextField, passwordTextField: passwordTextField, manager: manager) else {
            return
        }
        
        manager?.api?.logout() //Make sure there's no cached user
        
        showLoading()
        print("Start login")
        manager?.api?.login(withEmail: result.email, password: result.password) { [weak self] (succeeded, error) in
            guard let strongSelf = self else {
                return
            }
            
            var didHandle = false
            if let error = error as NSError? {
                if error.code == CleengLoginAndSubscribeApi.ErrorType.badCustomerEmailOrCustomerNotExist.rawValue {
                    strongSelf.hideLoading()
                    didHandle = true
                    
                    let titleKey = ZappCleengLoginLocalization.errorTitleLocalizationKey(forCode: error.code)
                    let messageKey = ZappCleengLoginLocalization.errorMessageLocalizationKey(forCode: error.code)
                    let alert = UIAlertController(title: strongSelf.manager?.localizedString(for: titleKey), message: strongSelf.manager?.localizedString(for: messageKey), preferredStyle: .alert)
                    
                    alert.addAction(UIAlertAction(title: strongSelf.manager?.localizedString(for: .alertCancelAction, defaultString: NSLocalizedString("Cancel", comment: "Cancel")), style: .cancel, handler: { _ in
                        strongSelf.emailTextField.becomeFirstResponder()
                    }))
                    
                    alert.addAction(UIAlertAction(title: strongSelf.manager?.localizedString(for: .signUpButton, defaultString: NSLocalizedString("Sign Up", comment: "Sign Up")), style: .default, handler: { _ in
                        print("Fallback to signup")
                        strongSelf.showLoading()
                        strongSelf.manager?.api?.signup(withEmail: result.email, password: result.password) { [weak self] (succeeded, error) in
                            self?.handleCleengSignResult(succeeded: succeeded, error: error)
                        }
                    }))
                    
                    strongSelf.present(alert, animated: true, completion: nil)
                } else if error.code == CleengLoginAndSubscribeApi.ErrorType.invalideCustomerCredentials.rawValue {
                    strongSelf.hideLoading()
                    didHandle = true
                    
                    let titleKey = ZappCleengLoginLocalization.errorTitleLocalizationKey(forCode: error.code)
                    let messageKey = ZappCleengLoginLocalization.errorMessageLocalizationKey(forCode: error.code)
                    let alert = UIAlertController(title: strongSelf.manager?.localizedString(for: titleKey), message: strongSelf.manager?.localizedString(for: messageKey), preferredStyle: .alert)
                 
                    alert.addAction(UIAlertAction(title: strongSelf.manager?.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")), style: .default, handler: { _ in
                        strongSelf.emailTextField.becomeFirstResponder()
                        strongSelf.passwordTextField.text = nil
                    }))
                    
                    strongSelf.present(alert, animated: true, completion: nil)
                }
            }
            
            if !didHandle {
                strongSelf.handleCleengSignResult(succeeded: succeeded, error: error)
            }
        }
    }
    
    @objc @IBAction private func goToSignUp() {
        manager?.showSignUp(animated: true, makeRoot: false)
    }
    
    //MARK: - Setup views
    private func signInConfigureViews() {
        guard let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate else {
            return
        }
        
        signButton.setZappStyle(using: stylesManager,
                                backgroundAsset: .signInButtonBackground,
                                title: manager?.localizedString(for: .signInButton),
                                style: .signInButton)
        
        goToSignButton.setAttributedZappStyle(using: stylesManager,
                                              attributedTitle: [
                                                (style: .actionDescription,
                                                 string: manager?.localizedString(for: .noAccount) ?? NSLocalizedString("Don't have an account?", comment: "Don't have an account?"),
                                                 additionalAttributes: nil),
                                                (style: .actionText,
                                                 string: manager?.localizedString(for: .signUp) ?? NSLocalizedString("Sign Up", comment: "Sign Up"),
                                                 additionalAttributes: nil)
            ])
        
        resetPasswordButton.setAttributedZappStyle(using: stylesManager,
                                                   attributedTitle: [
                                                    (style: .actionDescription,
                                                     string: manager?.localizedString(for: .resetPasswordActionDetails) ?? NSLocalizedString("Forgot your password?", comment: "Forgot your password?"),
                                                     additionalAttributes: nil),
                                                    (style: .actionText,
                                                     string: manager?.localizedString(for: .resetPasswordAction) ?? NSLocalizedString("Reset", comment: "Reset"),
                                                     additionalAttributes: nil)
            ])
    }
}

internal class CleengSignUpViewController : _CleengBaseSignViewController {
    @objc @IBOutlet private weak var newAccountDetailsLabel: UILabel!
    @objc @IBOutlet private weak var detailsLabel: UILabel!
    @objc @IBOutlet private weak var logoImageViewSpaceFromDetailsLabel: NSLayoutConstraint!
    @objc @IBOutlet private weak var detailsLabelMinSpaceFromTextFields: NSLayoutConstraint!
    
    override weak var manager: CleengLoginAndSubscriptionManager? {
        didSet {
            if isViewLoaded {
                signUpConfigureViews()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        signButton.isEnabled = true
        signUpConfigureViews()
    }
    
    fileprivate override func additionalKeyboardWillShowUpdates() -> (willShowAnimation: () -> Void, reverseAnimation: () -> Void)? {
        let logoImageViewSpaceFromDetailsLabelConstant = logoImageViewSpaceFromDetailsLabel.constant
        let detailsLabelMinSpaceFromTextFieldsConstant = detailsLabelMinSpaceFromTextFields.constant
        
        return (willShowAnimation: {
            if self.detailsLabel.text?.isEmpty ?? true {
                self.logoImageViewSpaceFromDetailsLabel.constant = 10
                self.detailsLabelMinSpaceFromTextFields.constant = 0
            } else {
                self.logoImageViewSpaceFromDetailsLabel.constant = 10
                self.detailsLabelMinSpaceFromTextFields.constant = 10
            }
        }, reverseAnimation: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.logoImageViewSpaceFromDetailsLabel.constant = logoImageViewSpaceFromDetailsLabelConstant
            strongSelf.detailsLabelMinSpaceFromTextFields.constant = detailsLabelMinSpaceFromTextFieldsConstant
        })
    }
    
    override func viewWillLayoutSubviews() {
        guard !isAdjustingLayoutForKeyboardOpen else { return }
        
        let height = view.bounds.height
        if height < 500 {
            logoImageViewSpaceFromDetailsLabel.constant = 8
            detailsLabelMinSpaceFromTextFields.constant = 8
        } else if height < 600 {
            if detailsLabel.text?.isEmpty ?? true {
                logoImageViewSpaceFromDetailsLabel.constant = 20
                detailsLabelMinSpaceFromTextFields.constant = 0
                logoBottomSpacing.constant = 20
            } else {
                logoImageViewSpaceFromDetailsLabel.constant = 30
                detailsLabelMinSpaceFromTextFields.constant = 20
                logoBottomSpacing.constant = 20
            }
        }
        super.viewWillLayoutSubviews()
    }
    
    @objc @IBAction private func signUp() {
        emailTextField.resignFirstResponder()
        passwordTextField.resignFirstResponder()
        
        guard let result = validateEmailAndPassword(emailTextField: emailTextField, passwordTextField: passwordTextField, manager: manager) else {
            return
        }
        
        manager?.api?.logout() //Make sure there's no cached user
        
        showLoading()
        print("Start login")
        manager?.api?.signup(withEmail: result.email, password: result.password) { [weak self] (succeeded, error) in
            guard let strongSelf = self else { return }
            
            var didHandle = false
            if let error = error as NSError? {
                if error.code == CleengLoginAndSubscribeApi.ErrorType.customerAlreadyExist.rawValue {
                    strongSelf.hideLoading()
                    didHandle = true
                    
                    let titleKey = ZappCleengLoginLocalization.errorTitleLocalizationKey(forCode: error.code)
                    let messageKey = ZappCleengLoginLocalization.errorMessageLocalizationKey(forCode: error.code)
                    
                    let alert = UIAlertController(title: strongSelf.manager?.localizedString(for: titleKey), message: strongSelf.manager?.localizedString(for: messageKey), preferredStyle: .alert)
                    
                    alert.addAction(UIAlertAction(title: strongSelf.manager?.localizedString(for: .alertCancelAction, defaultString: NSLocalizedString("Cancel", comment: "Cancel")), style: .default, handler: { _ in
                        strongSelf.emailTextField.becomeFirstResponder()
                    }))
                    
                    alert.addAction(UIAlertAction(title: strongSelf.manager?.localizedString(for: .signInButton, defaultString: NSLocalizedString("Sign In", comment: "Sign In")), style: .default, handler: { _ in
                        print("Fallback to sign-in")
                        strongSelf.hideLoading()
                        strongSelf.goToSignIn(takeEmailAndPassword: result)
                        strongSelf.emailTextField.text = nil
                        strongSelf.passwordTextField.text = nil
                        strongSelf.signButton.isEnabled = false
                    }))
                    
                    strongSelf.present(alert, animated: true, completion: nil)
                }
            }
            
            if !didHandle {
                strongSelf.handleCleengSignResult(succeeded: succeeded, error: error)
            }
        }
    }
    
    @objc @IBAction private func goToSignIn() {
        goToSignIn(takeEmailAndPassword: nil)
    }
    
    private func goToSignIn(takeEmailAndPassword: (email: String, password: String)?) {
        if let takeEmailAndPassword = takeEmailAndPassword {
            manager?.showSignIn(animated: true, makeRoot: false, email: takeEmailAndPassword.email, password: takeEmailAndPassword.password)
        } else {
            manager?.showSignIn(animated: true, makeRoot: false)
        }
        
    }
    
    //MARK: - UITextFieldDelegate
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let oldText = (textField.text ?? "")
        let text = oldText.replacingCharacters(in: Range(range, in: oldText)!, with: string)
        if textField === emailTextField {
            signButton.isEnabled = true //!(text.isEmpty) && !(passwordTextField.text?.isEmpty ?? true)
        } else if textField === passwordTextField {
            signButton.isEnabled = true //!(emailTextField.text?.isEmpty ?? true) && !(text.isEmpty)
        }
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        signButton.isEnabled = true //!(emailTextField.text?.isEmpty ?? true) && !(passwordTextField.text?.isEmpty ?? true)
    }
    
    private func signUpConfigureViews() {
        guard let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate else {
            return
        }
        
        signButton.setZappStyle(using: stylesManager,
                                backgroundAsset: .signUpButtonBackground,
                                title: manager?.localizedString(for: .signUpButton),
                                style: .signUpButton)
        
        signButton.setZappStyle(using: stylesManager,
                                backgroundAsset: .buttonDisabledState,
                                title: manager?.localizedString(for: .signUpButton),
                                style: .buttonDisabledState,
                                forState: .disabled)
        
        goToSignButton.setAttributedZappStyle(using: stylesManager,
                                              attributedTitle: [
                                                (style: .actionDescription,
                                                 string: manager?.localizedString(for: .haveAccount) ?? NSLocalizedString("Already have an account?", comment: "Already have an account?"),
                                                 additionalAttributes: nil),
                                                (style: .actionText,
                                                 string: manager?.localizedString(for: .signIn) ?? NSLocalizedString("Sign In", comment: "Sign In"),
                                                 additionalAttributes: nil)
            ])
        
        detailsLabel.setZappStyle(using: stylesManager,
                                  text: manager?.localizedString(for: .newAccountDetails),
                                  style: .loginDetails)
        newAccountDetailsLabel.setZappStyle(using: stylesManager,
                                            text: manager?.localizedString(for: .signupNewAccountDetails),
                                            style: .loginTitle)
    }
}
