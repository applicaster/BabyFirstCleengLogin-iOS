//
//  ZappCleengSettingScreenManager.swift
//  CleengLogin
//
//  Created by Liviu Romascanu on 27/02/2019.
//

import UIKit
import ZappPlugins
import ZappLoginPluginsSDK

class ZappCleengSettingScreenManager: NSObject, ZPPluggableScreenProtocol {
    var pluginModel: ZPPluginModel?
    var screenModel: ZLScreenModel?
    var dataSourceModel: NSObject?
    var screenPluginDelegate: ZPPlugableScreenDelegate?
    
    required init?(pluginModel: ZPPluginModel, screenModel: ZLScreenModel, dataSourceModel: NSObject?) {
        self.pluginModel = pluginModel
        self.screenModel = screenModel
        self.dataSourceModel = dataSourceModel
    }
    
    func createScreen() -> UIViewController {
        let podBundle = Bundle(for: CleengSettingsScreenViewController.self)
        let bundleURL = podBundle.url(forResource: "cleeng-storyboard", withExtension: "bundle")!
        let bundle = Bundle(url: bundleURL)!
        let cleengStoryboard = UIStoryboard(name: "CleengMain", bundle: bundle)
        let loginProvider = ZPLoginManager.sharedInstance.createWithUserData()
        
        var vc: UIViewController = UI_USER_INTERFACE_IDIOM() == .phone ? cleengStoryboard.instantiateViewController(withIdentifier: "Settings") : cleengStoryboard.instantiateViewController(withIdentifier: "SettingsSplit")
        
        if let cleengLogin = loginProvider as? ZappCleengLogin {
            if var settingsVC = vc as? CleengSettingsBaseProtocol {
                // Setup all the objects the VC will need to present and configure itself
                settingsVC.cleengLogin = cleengLogin
                settingsVC.pluginModel = pluginModel
                settingsVC.screenModel = screenModel
                settingsVC.dataSourceModel = dataSourceModel
            }
        }
        return vc
    }
    
    func screenPluginDidDisappear(viewController: UIViewController) {
        // Handle cleanup if needed
    }
}
