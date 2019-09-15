//
//  CleengResetPasswordViewController.swift
//  CleengLogin
//
//  Created by Yossi Avramov on 07/06/2018.
//

import UIKit
import SafariServices
import ZappPlugins

class CleengResetPasswordViewController : UIViewController, CleengLoginAndSubscriptionProtocol, UITextFieldDelegate {
    weak var manager: CleengLoginAndSubscriptionManager? {
        didSet {
            if isViewLoaded {
                configureViews()
            }
        }
    }
    
    @objc @IBOutlet private weak var backButton: UIButton!
    
    @objc @IBOutlet private weak var backgroundImageView: UIImageView!
    @objc @IBOutlet private weak var backgroundOverlay: UIView!
    
    @objc @IBOutlet private weak var textsStackView: UIStackView!
    @objc @IBOutlet private weak var headerLabel: UILabel!
    @objc @IBOutlet private weak var detailsLabel: UILabel!
    
    @objc @IBOutlet private weak var emailTextField: UITextField!
    @objc @IBOutlet private weak var emailTextFieldBackgroundImageView: UIImageView!
    @objc @IBOutlet private weak var emailTextAreaHeight: NSLayoutConstraint!
    @objc @IBOutlet private weak var resetPasswordButton: UIButton!
    @objc @IBOutlet private weak var resetPasswordButtonHeight: NSLayoutConstraint!
    @objc @IBOutlet private weak var helpButton: UIButton!
    @objc @IBOutlet private weak var helpBottomBarHeight: NSLayoutConstraint!
    @objc @IBOutlet fileprivate weak var mainStackViewCenterLayout: NSLayoutConstraint!
    
    private let emailPredicate = NSPredicate(format: "SELF MATCHES %@", "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        resetPasswordButton.isEnabled = false
        resetPasswordButton.setTitle(nil, for: .normal)
        resetPasswordButton.backgroundColor = UIColor.clear
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
        NotificationCenter.default.addObserver(self, selector: #selector(CleengResetPasswordViewController.keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(CleengResetPasswordViewController.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
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
            emailTextAreaHeight.constant = 37
            resetPasswordButtonHeight.constant = 37
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
        navigationController?.popViewController(animated: true)
    }
    
    @objc @IBAction private func resetPassword() {
        emailTextField.resignFirstResponder()
        guard let email = emailTextField.text , email.isEmpty == false else {
            let alert = UIAlertController(title: manager?.localizedString(for: .errorEmailRequiredTitle), message: manager?.localizedString(for: .errorEmailRequiredMessage), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: manager?.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")), style: .default, handler: { _ in
                self.emailTextField.becomeFirstResponder()
            }))
            present(alert, animated: true, completion: nil)
            return
        }
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        guard predicate.evaluate(with: email) else {
            let alert = UIAlertController(title: manager?.localizedString(for: .errorInvalideEmailFormatTitle), message: manager?.localizedString(for: .errorInvalideEmailFormatMessage), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: manager?.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")), style: .default, handler: { _ in
                self.emailTextField.becomeFirstResponder()
            }))
            present(alert, animated: true, completion: nil)
            return
        }
        
        manager?.showLoading(for: self)
        manager?.api.resetPassword(email: email, completion: { [weak self] (succeeded, error) in
            guard let strongSelf = self else { return }
            if succeeded {
                strongSelf.didSendResetURL()
            } else {
                strongSelf.manager?.hideLoading(for: strongSelf)
                let alert = UIAlertController(title: strongSelf.manager?.localizedString(for: .errorInternalTitle), message: error?.localizedDescription ?? strongSelf.manager?.localizedString(for: .errorInternalMessage), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: strongSelf.manager?.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")), style: .cancel, handler: nil))
                strongSelf.present(alert, animated: true, completion: nil)
            }
        })
    }
    
    private func didSendResetURL() {
        self.manager?.hideLoading(for: self)
        self.navigationController?.popViewController(animated: true)
        
        let message = manager?.localizedString(for: .resetPasswordEmailSent, defaultString: NSLocalizedString("Check your email for instructions to reset your password.", comment: "Check your email for instructions to reset your password."))
        let alert = UIAlertController(title: manager?.localizedString(for: .resetPasswordTitle), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: manager?.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")), style: .default, handler: { _ in
        }))
        
        self.navigationController?.present(alert, animated: true, completion: nil)
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
    
    private func configureViews() {
        guard let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate else {
            return
        }
        
        backgroundImageView.setupCleengBackground(with: stylesManager)
        backgroundOverlay.setZappStyle(using: stylesManager, withBackgroundColor: .backgroundColor)
        backButton.setZappStyle(using: stylesManager, withIconAsset: .backIcon)
        headerLabel.setZappStyle(using: stylesManager,
                                 text: manager?.localizedString(for: .resetPasswordTitle),
                                 style: .loginTitle)
        detailsLabel.setZappStyle(using: stylesManager,
                                  text: manager?.localizedString(for: .resetPasswordDetails),
                                  style: .loginDescription)
        emailTextFieldBackgroundImageView.setZappStyle(using: stylesManager, withAsset: .textFieldsBackground)
        emailTextField.setZappStyle(using: stylesManager,
                                    textStyle: .defaultText,
                                    placeholder: manager?.localizedString(for: .emailPlaceholder))
        
        resetPasswordButton.setZappStyle(using: stylesManager,
                                         backgroundAsset: .signInButtonBackground,
                                         title: manager?.localizedString(for: .resetPasswordButtonAction),
                                         style: .signInButton)
        
        resetPasswordButton.setZappStyle(using: stylesManager,
                                         backgroundAsset: .buttonDisabledState,
                                         title: manager?.localizedString(for: .resetPasswordButtonAction),
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
    
    //MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let oldText = (textField.text ?? "")
        let text = oldText.replacingCharacters(in: Range(range, in: oldText)!, with: string)
        resetPasswordButton.isEnabled = emailPredicate.evaluate(with: text)
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        resetPasswordButton.isEnabled = emailPredicate.evaluate(with: (textField.text ?? ""))
    }
}
