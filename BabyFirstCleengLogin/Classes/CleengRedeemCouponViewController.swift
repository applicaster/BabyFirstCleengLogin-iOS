//
//  CleengRedeemCouponViewController.swift
//  AFNetworking
//
//  Created by Yossi Avramov on 09/10/2018.
//

import UIKit
import ZappPlugins

class CleengRedeemCouponViewController : UIViewController, CleengLoginAndSubscriptionProtocol, UITextFieldDelegate {
    weak var manager: CleengLoginAndSubscriptionManager? {
        didSet {
            if isViewLoaded {
                configureViews()
            }
        }
    }
    
    var offer: CleengOffer!
    
    @objc @IBOutlet private weak var backButton: UIButton!
    @objc @IBOutlet private weak var closeButton: UIButton!
    
    @objc @IBOutlet private weak var backgroundImageView: UIImageView!
    @objc @IBOutlet private weak var backgroundOverlay: UIView!
    
    @objc @IBOutlet private weak var textsStackView: UIStackView!
    @objc @IBOutlet private weak var headerLabel: UILabel!
    @objc @IBOutlet private weak var detailsLabel: UILabel!
    
    @objc @IBOutlet private weak var codeTextField: UITextField!
    @objc @IBOutlet private weak var codeTextFieldBackgroundImageView: UIImageView!
    @objc @IBOutlet private weak var codeTextAreaHeight: NSLayoutConstraint!
    @objc @IBOutlet private weak var redeemButton: UIButton!
    @objc @IBOutlet private weak var redeemButtonHeight: NSLayoutConstraint!
    @objc @IBOutlet fileprivate weak var mainStackViewCenterLayout: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        redeemButton.isEnabled = false
        redeemButton.setTitle(nil, for: .normal)
        redeemButton.backgroundColor = UIColor.clear
        configureViews()
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UI_USER_INTERFACE_IDIOM() == .phone {
            return .portrait
        } else {
            return .landscape
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        codeTextField.becomeFirstResponder()
        
        NotificationCenter.default.addObserver(self, selector: #selector(CleengRedeemCouponViewController.keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(CleengRedeemCouponViewController.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillLayoutSubviews() {
        let height = view.bounds.height
        if height < 500 {
            textsStackView.spacing = 15
            codeTextAreaHeight.constant = 37
            redeemButtonHeight.constant = 37
        }
        
        super.viewWillLayoutSubviews()
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
            self.mainStackViewCenterLayout.constant = -75
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
        codeTextField.resignFirstResponder()
        navigationController?.popViewController(animated: true)
    }
    
    @objc @IBAction fileprivate func close() {
        codeTextField.resignFirstResponder()
        manager?.userDidSelectToClose()
    }
    
    @objc @IBAction private func redeemCode() {
        guard let manager = manager else { return }
        
        guard let code = codeTextField.text else {
            codeTextField.becomeFirstResponder()
            return
        }
        
        guard manager.api.cleengLoginState == .loggedIn else {
            manager.purhcaseOnLogin = .redeem(code: code, offer: offer)
            manager.showSignUp(animated: true, makeRoot: true)
            return
        }
        
        manager.showLoading(for: self)
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
                let message = (((error as NSError).userInfo[NSLocalizedDescriptionKey] as? String)
                    ?? strongSelf.manager?.localizedString(for: .redeemCouponErrorMessage)
                    ?? error.localizedDescription)
                
                let alert = UIAlertController(title: manager.localizedString(for: .errorInternalTitle, defaultString: NSLocalizedString("Error", comment: "Error")), message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: manager.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")), style: .cancel, handler: { _ in
                    strongSelf.codeTextField.becomeFirstResponder()
                }))
                strongSelf.present(alert, animated: true, completion: nil)
            }
        })
    }
    
    //MARK: - Private
    private func configureViews() {
        guard let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate else {
            return
        }
        
        backgroundImageView.setupCleengBackground(with: stylesManager)
        backgroundOverlay.setZappStyle(using: stylesManager, withBackgroundColor: .backgroundColor)
        backButton.setZappStyle(using: stylesManager, withIconAsset: .backIcon)
        closeButton.setZappStyle(using: stylesManager, withIconAsset: .closeIcon)
        headerLabel.setZappStyle(using: stylesManager,
                                 text: manager?.localizedString(for: .redeemCouponTitle),
                                 style: .loginTitle)
        detailsLabel.setZappStyle(using: stylesManager,
                                  text: manager?.localizedString(for: .redeemCouponDetails),
                                  style: .loginDescription)
        codeTextFieldBackgroundImageView.setZappStyle(using: stylesManager, withAsset: .textFieldsBackground)
        codeTextField.setZappStyle(using: stylesManager,
                                    textStyle: .defaultText,
                                    placeholder: manager?.localizedString(for: .redeemCouponPlaceholder))
        
        redeemButton.setZappStyle(using: stylesManager,
                                         backgroundAsset: .signInButtonBackground,
                                         title: manager?.localizedString(for: .redeemCouponAction),
                                         style: .signInButton)
        
        redeemButton.setZappStyle(using: stylesManager,
                                         backgroundAsset: .buttonDisabledState,
                                         title: manager?.localizedString(for: .redeemCouponAction),
                                         style: .buttonDisabledState,
                                         forState: .disabled)
    }
    
    //MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return false
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let oldText = (textField.text ?? "")
        let text = oldText.replacingCharacters(in: Range(range, in: oldText)!, with: string).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        redeemButton.isEnabled = !(text.isEmpty)
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let text = (textField.text ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        redeemButton.isEnabled = !(text.isEmpty)
    }
}
