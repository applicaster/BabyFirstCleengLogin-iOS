//
//  CleengSettingsSplitScreenViewController.swift
//  Alamofire
//
//  Created by Anton Klysa on 6/24/19.
//

import UIKit
import ZappPlugins
import ZappLoginPluginsSDK

class CleengSettingsSplitScreenViewController: UISplitViewController, UITableViewDelegate, CleengSettingsBaseProtocol {
    
    
    //MARK: CleengSettingsBaseProtocol
    
    var cleengLogin: ZappCleengLogin?
    var pluginModel: ZPPluginModel?
    var screenModel: ZLScreenModel?
    var dataSourceModel: NSObject?
    
    
    //MARK: props
    
    private var masterViewController: CleengSettingsScreenViewController!
    
    
    //MARK: lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let podBundle = Bundle(for: CleengSettingsScreenViewController.self)
        let bundleURL = podBundle.url(forResource: "cleeng-storyboard", withExtension: "bundle")!
        let bundle = Bundle(url: bundleURL)!
        let cleengStoryboard = UIStoryboard(name: "CleengMain", bundle: bundle)
        let loginProvider = ZAAppConnector.sharedInstance().pluginsDelegate?.loginPluginsManager?.createWithUserData()
        
        //adding master view controller
        masterViewController = cleengStoryboard.instantiateViewController(withIdentifier: "Settings") as? CleengSettingsScreenViewController
        if let cleengLogin = loginProvider as? ZappCleengLogin {
            masterViewController.cleengLogin = cleengLogin
            masterViewController.pluginModel = pluginModel
            masterViewController.screenModel = screenModel
            masterViewController.dataSourceModel = dataSourceModel
        }
        
        viewControllers = [masterViewController, CleengSettingsSplitDetailsViewController(withURL: nil)]
        minimumPrimaryColumnWidth = 375.0
        maximumPrimaryColumnWidth = 375.0
        preferredPrimaryColumnWidthFraction = 2.0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        masterViewController.settingsTableView.delegate = self
    }
    
    
    //MARK: UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let urlString = masterViewController.tableItems[indexPath.row]["url"] {
            if let url = URL(string: urlString) {
                let detailsVC: CleengSettingsSplitDetailsViewController = CleengSettingsSplitDetailsViewController(withURL: url)
                showDetailViewController(detailsVC, sender: nil)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 75.0
    }
}

class CleengSettingsSplitDetailsViewController: UIViewController {
    
    //MARK: props
    
    private var webView: UIWebView = UIWebView()
    
    
    //MARK: init
    
    init(withURL: URL?) {
        super.init(nibName: nil, bundle: nil)
        
        setupBackgroundImage()
        setupWebView()
        
        webView.backgroundColor = .clear
        self.view.backgroundColor = .clear
        
        guard withURL != nil else {
            webView.isHidden = true
            return
        }
        
        let request = URLRequest(url: withURL!)
        webView.loadRequest(request)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    //MARK: setup controller props
    
    private func setupBackgroundImage() {
        let backgroundImage: UIImageView = UIImageView()
        if let image = UIImage(named: "cleeng_settings_ios/settings_background_image~ipad") {
            backgroundImage.image = image
        }
        view.addSubview(backgroundImage)
        backgroundImage.translatesAutoresizingMaskIntoConstraints = false
        backgroundImage.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        backgroundImage.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        backgroundImage.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        backgroundImage.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
    
    private func setupWebView() {
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        webView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}
