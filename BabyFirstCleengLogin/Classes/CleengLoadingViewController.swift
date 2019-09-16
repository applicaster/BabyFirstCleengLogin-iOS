//
//  CleengLoadingViewController.swift
//  CleengLogin
//
//  Created by Yossi Avramov on 19/06/2018.
//

import UIKit
import ZappPlugins

internal class CleengLoadingViewController : UIViewController {
    @objc @IBOutlet weak var activity: UIActivityIndicatorView!
    @objc @IBOutlet weak var messageLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = true
        view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        
        if let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate {
            activity.setZappStyle(using: stylesManager,
                                  withColor: .loadingIndicatorColor)
            messageLabel.setZappStyle(using: stylesManager,
                                      text: nil,
                                      style: ZappCleengConfiguration.StyleKey.alertDescription)
        }
    }
}
