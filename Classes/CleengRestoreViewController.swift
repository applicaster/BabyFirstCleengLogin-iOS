//
//  CleengRestoreViewController.swift
//  CleengPlugin
//
//  Created by Yossi Avramov on 28/05/2018.
//  Copyright © 2018 Applicaster. All rights reserved.
//

import UIKit
import SafariServices
import ZappPlugins

internal class CleengRestoreViewController : UIViewController, UITextFieldDelegate, CleengLoginAndSubscriptionProtocol {
 
    @objc @IBOutlet private weak var backButton: UIButton!
    @objc @IBOutlet private weak var closeButton: UIButton!
    
    @objc @IBOutlet fileprivate weak var backgroundImageView: UIImageView!
    @objc @IBOutlet fileprivate weak var backgroundOverlay: UIView!
    
    @objc @IBOutlet private weak var headerLabel: UILabel!
    @objc @IBOutlet private weak var detailsLabel: UILabel!
 
    @objc @IBOutlet private weak var emailTextField: UITextField!
    @objc @IBOutlet fileprivate weak var emailTextFieldBackgroundImageView: UIImageView!
    
    @objc @IBOutlet private weak var passwordTextField: UITextField!
    @objc @IBOutlet fileprivate weak var passwordTextFieldBackgroundImageView: UIImageView!
    
    @objc @IBOutlet private weak var restoreButton: UIButton!
    @objc @IBOutlet private weak var helpButton: UIButton!
    
    weak var manager: CleengLoginAndSubscriptionManager?
    
    //Outlets for adjust size for iPhone 4s, 5 & SE
    @objc @IBOutlet private weak var headerLabelTopSpacing: NSLayoutConstraint!
    @objc @IBOutlet fileprivate weak var mainStackView: UIStackView!
    @objc @IBOutlet fileprivate weak var mainStackViewTopSpacing: NSLayoutConstraint!
    @objc @IBOutlet fileprivate weak var mainStackViewBottomSpacing: NSLayoutConstraint!
    @objc @IBOutlet fileprivate weak var mainStackViewCenterLayout: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        helpButton.isHidden = true
        
        backButton.setTitle(nil, for: .normal)
        backButton.backgroundColor = UIColor.clear
        
        closeButton.setTitle(nil, for: .normal)
        closeButton.backgroundColor = UIColor.clear
        
        restoreButton.isEnabled = false
        restoreButton.setTitle(nil, for: .normal)
        restoreButton.backgroundColor = UIColor.clear
        
        if let nav = navigationController , nav.viewControllers.first === self {
            backButton.isHidden = true
        }
        
        configureViews()
    }
   
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(CleengRestoreViewController.keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(CleengRestoreViewController.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if let nav = parent as? UINavigationController , nav.viewControllers.isEmpty || nav.viewControllers.first === self {
            backButton?.isHidden = true
        }
    }
    
    override func viewWillLayoutSubviews() {
        let height = view.bounds.height
        if height < 500 {
            headerLabelTopSpacing.constant = 8
            mainStackViewTopSpacing.constant = 10
            mainStackViewBottomSpacing.constant = 10
            mainStackView.spacing = 30
        }
        
        super.viewWillLayoutSubviews()
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UI_USER_INTERFACE_IDIOM() == .phone {
            return .portrait
        } else {
            return .landscape
        }
    }
    
    private func configureViews() {
        guard let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate else {
            return
        }
        
        backgroundImageView.setupCleengBackground(with: stylesManager)
        backgroundOverlay.setZappStyle(using: stylesManager, withBackgroundColor: .backgroundColor)
        closeButton.setZappStyle(using: stylesManager, withIconAsset: .closeIcon)
        backButton.setZappStyle(using: stylesManager, withIconAsset: .backIcon)
        headerLabel.setZappStyle(using: stylesManager,
                                 text: manager?.localizedString(for: .restoreTitle),
                                 style: .loginTitle)
        detailsLabel.setZappStyle(using: stylesManager,
                                  text: manager?.localizedString(for: .restoreDescription),
                                  style: .loginDescription)
        emailTextFieldBackgroundImageView.setZappStyle(using: stylesManager, withAsset: .textFieldsBackground)
        passwordTextFieldBackgroundImageView.setZappStyle(using: stylesManager, withAsset: .textFieldsBackground)
        emailTextField.setZappStyle(using: stylesManager,
                                    textStyle: .defaultText,
                                    placeholder: manager?.localizedString(for: .emailPlaceholder))
        passwordTextField.setZappStyle(using: stylesManager,
                                       textStyle: .defaultText,
                                       placeholder: manager?.localizedString(for: .passwordPlaceholder))
        restoreButton.setZappStyle(using: stylesManager,
                                   backgroundAsset: .restoreButtonBackground,
                                   title: manager?.localizedString(for: .restoreButton),
                                   style: .restoreButton)
        restoreButton.setZappStyle(using: stylesManager,
                                   backgroundAsset: .buttonDisabledState,
                                   title: manager?.localizedString(for: .restoreButton),
                                   style: .buttonDisabledState,
                                   forState: .disabled)
        
        let helpURL = manager?.helpURL
        if helpURL == nil {
            helpButton.superview?.backgroundColor = UIColor.clear
            helpButton.isHidden = true
        } else {
            helpButton.isHidden = false
            helpButton.superview?.setZappStyle(using: stylesManager, withBackgroundColor: .bottomBackgroundColor)
            helpButton.setAttributedZappStyle(using: stylesManager,
                                              attributedTitle: [
                                                (style: .actionDescription,
                                                 string: manager?.localizedString(for: .troubleRestore) ?? NSLocalizedString("Having trouble?", comment: "Having trouble?"),
                                                 additionalAttributes: nil),
                                                (style: .actionText,
                                                 string: manager?.localizedString(for: .helpRestore) ?? NSLocalizedString("Contact us", comment: "Contact us"),
                                                 additionalAttributes: nil)
                ])
        }
    }
    
    @objc private func keyboardWillShow(_ notification: Notification?) {
        guard traitCollection.horizontalSizeClass == .regular && traitCollection.verticalSizeClass == .regular else { return }
        
        guard ((notification?.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? NSNumber)?.boolValue ?? true) else {
            return
        }
        
        let duration = (notification?.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.3
        let curveValue = (notification?.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 0
        let options: UIView.AnimationOptions = [UIView.AnimationOptions(rawValue: curveValue), .beginFromCurrentState]
        
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            self.mainStackViewCenterLayout.constant = -50
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    @objc private func keyboardWillHide(_ notification: Notification?) {
        guard traitCollection.horizontalSizeClass == .regular && traitCollection.verticalSizeClass == .regular else { return }
        
        let duration = (notification?.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.3
        let curveValue = (notification?.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 0
        let options: UIView.AnimationOptions = [UIView.AnimationOptions(rawValue: curveValue), .beginFromCurrentState]
        
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            self.mainStackViewCenterLayout.constant = 0
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    //MARK: - Actions
    @objc @IBAction private func back() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc @IBAction private func close() {
        manager?.userDidSelectToClose()
    }
    
    @objc @IBAction private func restore() {
        emailTextField.resignFirstResponder()
        passwordTextField.resignFirstResponder()
        guard let result = validateEmailAndPassword(emailTextField: emailTextField, passwordTextField: passwordTextField, manager: manager) else {
            return
        }
        
        guard let manager = manager else { return }
        emailTextField.resignFirstResponder()
        passwordTextField.resignFirstResponder()
        
        manager.api.logout() //Make sure there's no cached user
        manager.showLoading(for: self)
        print("Start restore")
        manager.api.restoreStorePurchases(userEmail: result.email, password: result.password, withCompletion: { [weak self, weak manager] (result) in
            guard let strongSelf = self, let manager = manager else { return }
            
            manager.hideLoading(for: self)
            
            switch result {
            case .succeeded:
                print("Restore Succeeded")
                if manager.api.hasAuthorizationTokenForCurrentItem {
                    manager.authenticated(with: .inAppPurchase, showAlert: true)
                } else {
                    assert(false, "That shouldn't happen. The user purchased a subscription and doesn't have token for it")
                }
            case .userAlreadyHasAccessToOffers:
                print("No need to restore. User already has access to offers")
                manager.authenticated(with: .unknown, showAlert: true)
            case .noPurchaseToRestore:
                print("No related purchases to restore from")
                let alert = UIAlertController(title: manager.localizedString(for: .restoreTitle), message: manager.localizedString(for: .noPurchasesToRestoreAlertMessage, defaultString: NSLocalizedString("No previous purchases to restore", comment: "No previous purchases to restore")), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: manager.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")), style: .default, handler: { [weak self] _ in
                    self?.navigationController?.popViewController(animated: true)
                }))
                strongSelf.present(alert, animated: true, completion: nil)
            case .failure(let error):
                print("Restore failed: \(error)")
                
                let err = error as NSError
                let titleKey = ZappCleengLoginLocalization.errorTitleLocalizationKey(forCode: err.code)
                let messageKey = ZappCleengLoginLocalization.errorMessageLocalizationKey(forCode: err.code)
                
                let alert = UIAlertController(title: manager.localizedString(for: titleKey), message: manager.localizedString(for: messageKey), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: manager.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")), style: .default, handler: { [weak self] _ in
                    guard let strongSelf = self else { return }
                    
                    if err.code == CleengLoginAndSubscribeApi.ErrorType.invalideCustomerCredentials.rawValue {
                        strongSelf.emailTextField.becomeFirstResponder()
                        strongSelf.passwordTextField.text = nil
                    } else {
                        strongSelf.navigationController?.popViewController(animated: true)
                    }
                }))
                strongSelf.present(alert, animated: true, completion: nil)
            }
        })
    }
    
    @objc @IBAction private func help() {
        guard let url = manager?.helpURL else { return }
        
        if UIApplication.shared.canOpenURL(url) && url.absoluteString.contains("://") {
            UIApplication.shared.openURL(url)
        } else {
            let safari = SFSafariViewController(url: url)
            present(safari, animated: true, completion: nil)
        }
    }
    
    //MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let oldText = (textField.text ?? "")
        let text = oldText.replacingCharacters(in: Range(range, in: oldText)!, with: string)
        if textField === emailTextField {
            restoreButton.isEnabled = !(text.isEmpty) && !(passwordTextField.text?.isEmpty ?? true)
        } else if textField === passwordTextField {
            restoreButton.isEnabled = !(emailTextField.text?.isEmpty ?? true) && !(text.isEmpty)
        }
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        restoreButton.isEnabled = !(emailTextField.text?.isEmpty ?? true) && !(passwordTextField.text?.isEmpty ?? true)
    }
}
