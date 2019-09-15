//
//  CleengProfileViewController.swift
//  CleengLogin
//
//  Created by Liviu Romascanu on 08/02/2019.
//

import UIKit
import FacebookCore
import ZappPlugins


class CleengProfileViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        if let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate {
//            backgroundImageView.setupCleengBackground(with: stylesManager)
        }

        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
