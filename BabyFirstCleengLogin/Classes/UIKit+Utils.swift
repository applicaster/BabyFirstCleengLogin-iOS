//
//  UIKit+Utils.swift
//  CleengLogin
//
//  Created by Yossi Avramov on 19/06/2018.
//

import UIKit
import ZappPlugins

internal extension UICollectionView {
    func reloadDataTruelyWorking() {
        let temp = dataSource
        dataSource = nil
        reloadData()
        dataSource = temp
        reloadData()
    }
}

extension UIImageView {
    func setupCleengBackground(with stylesManager: ZAAppDelegateConnectorLayoutsStylesProtocol) {
        self.clipsToBounds = true
        guard bounds.width != 0 && bounds.height != 0 else {
            self.image = nil
            return
        }
        
        let imageKeys: [ZappCleengConfiguration.AssetKey]
        if UI_USER_INTERFACE_IDIOM() == .phone {
            if bounds.width > bounds.height {
                imageKeys = [.loginBackground_iPadLandscape, .loginBackground_height1366, .loginBackground_height812, .loginBackground_height736, .loginBackground_height667, .loginBackground_height568, .loginBackground_default]
            } else {
                if bounds.height > 800 {
                    imageKeys = [.loginBackground_height812, .loginBackground_height736, .loginBackground_height667, .loginBackground_height1366, .loginBackground_height568, .loginBackground_default]
                } else if bounds.height > 700 {
                    imageKeys = [.loginBackground_height736, .loginBackground_height667, .loginBackground_height812, .loginBackground_height1366, .loginBackground_height568, .loginBackground_default]
                } else if bounds.height > 600 {
                    imageKeys = [.loginBackground_height667, .loginBackground_height736, .loginBackground_height568, .loginBackground_height812, .loginBackground_default, .loginBackground_height1366]
                } else if bounds.height > 500 {
                    imageKeys = [.loginBackground_height568, .loginBackground_default, .loginBackground_height667, .loginBackground_height736, .loginBackground_height812, .loginBackground_height1366]
                } else {
                    imageKeys = [.loginBackground_default, .loginBackground_height568, .loginBackground_height667, .loginBackground_height736, .loginBackground_height812, .loginBackground_height1366]
                }
            }
        } else {
            if (traitCollection.horizontalSizeClass == .regular) {
                if bounds.width > bounds.height {
                    imageKeys = [.loginBackground_iPadLandscape, .loginBackground_height1366, .loginBackground_height812, .loginBackground_height736, .loginBackground_height667, .loginBackground_height568, .loginBackground_default]
                } else {
                    imageKeys = [.loginBackground_height1366, .loginBackground_height812, .loginBackground_height736, .loginBackground_iPadLandscape, .loginBackground_height667, .loginBackground_height568, .loginBackground_default]
                }
            } else {
                if bounds.height > 750 {
                    imageKeys = [.loginBackground_height736, .loginBackground_height667, .loginBackground_height812, .loginBackground_height1366, .loginBackground_height568, .loginBackground_default]
                } else {
                    imageKeys = [.loginBackground_height812, .loginBackground_height736, .loginBackground_height667, .loginBackground_height1366, .loginBackground_height568, .loginBackground_default]
                }
            }
        }
        
        for key in imageKeys {
            self.setZappStyle(using: stylesManager, withAsset: key)
            if self.image != nil {
                break
            }
        }
    }
}

extension UIViewController {
    class var topMostViewController: UIViewController? {
        guard let window = UIApplication.shared.delegate?.window , let rootViewController = window?.rootViewController else {
            return nil
        }
        
        var top: UIViewController = rootViewController
        while let newTop = top.presentedViewController {
            top = newTop
        }
        
        return top
    }
    
    func validateEmailAndPassword(emailTextField: UITextField, passwordTextField: UITextField, manager: CleengLoginAndSubscriptionManager?) -> (email: String, password: String)? {
        guard let email = emailTextField.text , email.isEmpty == false else {
            let alert = UIAlertController(title: manager?.localizedString(for: .errorEmailRequiredTitle), message: manager?.localizedString(for: .errorEmailRequiredMessage), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: manager?.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")), style: .default, handler: { _ in
                emailTextField.becomeFirstResponder()
            }))
            present(alert, animated: true, completion: nil)
            return nil
        }
        
        guard let password = passwordTextField.text , password.isEmpty == false else {
            let alert = UIAlertController(title: manager?.localizedString(for: .errorPasswordRequiredTitle), message: manager?.localizedString(for: .errorPasswordRequiredMessage), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: manager?.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")), style: .default, handler: { _ in
                passwordTextField.becomeFirstResponder()
            }))
            present(alert, animated: true, completion: nil)
            return nil
        }
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        guard predicate.evaluate(with: email) else {
            let alert = UIAlertController(title: manager?.localizedString(for: .errorInvalideEmailFormatTitle), message: manager?.localizedString(for: .errorInvalideEmailFormatMessage), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: manager?.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")), style: .default, handler: { _ in
                emailTextField.becomeFirstResponder()
            }))
            present(alert, animated: true, completion: nil)
            return nil
        }
        
        return (email, password)
    }
}

extension CGRect {
    
    init(center: CGPoint, size: CGSize) {
        self.init(origin: CGPoint(x: center.x - (size.width * 0.5), y: center.y - (size.height * 0.5)), size: size)
    }
    
    var center: CGPoint {
        get { return CGPoint(x: centerX, y: centerY) }
        set { centerX = newValue.x; centerY = newValue.y }
    }
    
    var centerX: CGFloat {
        get { return midX }
        set { origin.x = newValue - (width * 0.5) }
    }
    
    var centerY: CGFloat {
        get { return midY }
        set { origin.y = newValue - (height * 0.5) }
    }
}
