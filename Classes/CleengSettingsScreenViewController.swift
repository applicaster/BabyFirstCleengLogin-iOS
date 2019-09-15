//
//  CleengSettingsScreenViewController.swift
//  CleengLogin
//
//  Created by Liviu Romascanu on 08/02/2019.
//

import UIKit
import ZappPlugins
import Alamofire

class CleengSettingsScreenViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CleengSettingsBaseProtocol {
    
    
    //MARK: CleengSettingsBaseProtocol
    
    var cleengLogin: ZappCleengLogin?
    var pluginModel: ZPPluginModel?
    var screenModel: ZLScreenModel?
    var dataSourceModel: NSObject?
    
    
    //MARK: IBOutlets
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var loginContainerView: UIView!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var profileNameLabel: UILabel!
    @IBOutlet weak var viewYourProfileLabel: UILabel!
    @IBOutlet weak var logoutButton: UIButton!
    @IBOutlet weak var settingsTableView: UITableView!
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var topViewHeightConstraint: NSLayoutConstraint!
    
    var tableItems: [[String: String]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let podBundle = Bundle(for: CleengSettingsScreenViewController.self)
        let bundleURL = podBundle.url(forResource: "cleeng-storyboard", withExtension: "bundle")!
        let bundle = Bundle(url: bundleURL)!
        settingsTableView.register(UINib(nibName: "CleengSettingsScreenTableViewCell", bundle: bundle), forCellReuseIdentifier: "CleengSettingsScreenTableViewCell")
		
        // Setup styles and localizations
        setupCustomizations()
        populateTableItems()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateViewForLoginState()
        if let selectedIndex = settingsTableView.indexPathForSelectedRow {
            settingsTableView.deselectRow(at: selectedIndex, animated: false)
        }
    }
    
    @IBAction func logoutButtonClicked(_ sender: Any) {
        if (CleengLoginAndSubscribeApi.currentCleengUser?.token != nil) {
            // Currently logged in - Perform logout
            logoutButton.isUserInteractionEnabled = false
            cleengLogin?.logout({ [unowned self] status in
                self.logoutButton.isUserInteractionEnabled = true
                self.updateViewForLoginState()
            })
        } else {
            // Currently logged out - Perform login
			logoutButton.isUserInteractionEnabled = false
			cleengLogin?.login(nil, completion: { [unowned self] status in
				self.logoutButton.isUserInteractionEnabled = true
				self.updateViewForLoginState()
			})
        }
    }
    
    @IBAction func viewProfileButtonClicked(_ sender: Any) {
		if (CleengLoginAndSubscribeApi.currentCleengUser?.token != nil) {
            // User logged in - show profile screen
        } else {
            // User is not logged in - safe to ignore
        }
    }
    
    // MARK: - Tableview
	
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let urlString = tableItems[indexPath.row]["url"],
            let prefix = ZAAppConnector.sharedInstance().urlDelegate.appUrlSchemePrefix(),
            let url = URL(string: "\(prefix)://present?linkurl=\(urlString)&showcontext=1") {
            UIApplication.shared.openURL(url)
        }
    }
	
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = settingsTableView.dequeueReusableCell(withIdentifier: "CleengSettingsScreenTableViewCell")
        if let settingsCell = cell as? CleengSettingsScreenTableViewCell {
            setupCellCustomization(cell: settingsCell)
			settingsCell.selectionStyle = .none
            settingsCell.itemLabel.text = tableItems[indexPath.row]["name"]
			if let imageUrl = tableItems[indexPath.row]["imageUrl"],
				let url = URL(string: imageUrl) {
				Alamofire.request(url).responseData { (response) in
					if let data = response.data {
						settingsCell.itemImageView.image = UIImage(data: data, scale:3)
					}
				}
			} else if let imageKey = tableItems[indexPath.row]["imageKey"] {
				settingsCell.itemImageView.image = UIImage(named: imageKey)
			}
            
            //setup arrow image
            if let arrowImage = image(forAsset: "cleeng_settings_arrow") {
                settingsCell.arrowImageView.image = arrowImage
            }
        }
        
        return cell ?? UITableViewCell()
    }
	
	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return 75.0
	}
    
    //MARK: - private
    private func populateTableItems() {
        tableItems = []
        
        if let generalDict = screenModel?.general {
            for index in 1...5 {
                if let itemUrl = generalDict["cleeng_settings_menu_url\(index)"] as? String,
					let itemName = generalDict["cleeng_settings_menu_item\(index)"] as? String {
					if (!itemUrl.isEmpty && !itemName.isEmpty) { // filter items with no name or image. the 'if let' passes empty string as true
						let imageKey = "cleeng_settings_item1\(index)"
						let imageUrl = generalDict["cleeng_settings_menu_image_url\(index)"] as? String
						var item: [String: String] = [:]
						item["imageKey"] = imageKey
						item["imageUrl"] = imageUrl
						item["url"] = itemUrl
						item["name"] = itemName
						tableItems.append(item)
					}
                }
            }
        }
        settingsTableView.reloadData()
    }
    
    private func updateViewForLoginState() {
		if (CleengLoginAndSubscribeApi.currentCleengUser?.token != nil) {
            self.logoutButton.setTitle("Log out", for: .normal)
			
			//logout button
			if let generalDict = screenModel?.general,
				let logoutText = generalDict["cleeng_settings_logout_text"] as? String {
				self.logoutButton.setTitle(logoutText, for: .normal)
			}
			
			// name / wellcome
			profileNameLabel.text = CleengLoginAndSubscribeApi.currentCleengUser?.email
			
            viewYourProfileLabel.isHidden = false
        } else {
            self.logoutButton.setTitle("Log in", for: .normal)
			
			//logout button
            if let generalDict = screenModel?.general,
                let loginText = generalDict["cleeng_settings_login_text"] as? String {
                self.logoutButton.setTitle(loginText, for: .normal)
            }
			
			// name / wellcome
			if let generalDict = screenModel?.general,
				let profileNameLabelWelcomeText = generalDict["cleeng_settings_welcome_message"] as? String {
				profileNameLabel.text = profileNameLabelWelcomeText
			}
            
            viewYourProfileLabel.isHidden = true
        }
    }
    
    private func setupCustomizations() {
        // For now by default hide top view as we will use deafult app nav bar
        topView.isHidden = true
        topViewHeightConstraint.constant = 22.0
        
        // In case we want to use the top view - this will set it to the default state. Should check if presenting in a screen or not
//        topView.isHidden = false
//        topViewHeightConstraint.constant = 84.0
//        if let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate {
//            //            backgroundImageView.setupCleengBackground(with: stylesManager)
//            logoImageView.setZappStyle(using: stylesManager, withAsset: .logo)
//        }
        
        if let progileImage = image(forAsset: "cleeng_settings_avatar") {
            profileImageView.image = progileImage
        }
        
        if let generalDict = screenModel?.general,
            let stylesDict = screenModel?.style?.object {
            if let profileNameLabelFontName = stylesDict["cleeng_settings_user_name_font"] as? String,
                let profileNameLabelSizeString = stylesDict["cleeng_settings_user_name_size"] as? String,
                let profileNameLabelSize = Float(profileNameLabelSizeString),
                let profileNameLabelColorString = stylesDict["cleeng_settings_user_name_color"] as? String,
                let profileNameLabelWelcomeText = generalDict["cleeng_settings_welcome_message"] as? String {
                profileNameLabel.font = UIFont(name: profileNameLabelFontName, size: CGFloat(profileNameLabelSize))
                profileNameLabel.textColor = UIColor(argbHexString: profileNameLabelColorString)
                profileNameLabel.text = profileNameLabelWelcomeText
				profileNameLabel.numberOfLines = 2
				profileNameLabel.adjustsFontSizeToFitWidth = false
				profileNameLabel.lineBreakMode = .byTruncatingTail
            }
            
            if let viewYourProfileLabelFontName = stylesDict["cleeng_settings_view_profile_font"] as? String,
                let viewYourProfileLabelSizeString = stylesDict["cleeng_settings_view_profile_size"] as? String,
                let viewYourProfileLabelSize = Float(viewYourProfileLabelSizeString),
                let viewYourProfileLabelColorString = stylesDict["cleeng_settings_view_profile_color"] as? String,
                let viewYourProfileText = generalDict["cleeng_settings_view_profile_text"] as? String {
				viewYourProfileLabel.text = viewYourProfileText
                viewYourProfileLabel.font = UIFont(name: viewYourProfileLabelFontName, size: CGFloat(viewYourProfileLabelSize))
                viewYourProfileLabel.textColor = UIColor(argbHexString: viewYourProfileLabelColorString)
				viewYourProfileLabel.numberOfLines = 1
				viewYourProfileLabel.adjustsFontSizeToFitWidth = false
				viewYourProfileLabel.lineBreakMode = .byTruncatingTail
                
                //setup logout button text and font
                logoutButton.setTitleColor(UIColor(argbHexString: viewYourProfileLabelColorString), for: .normal)
                logoutButton.titleLabel?.font = UIFont(name: viewYourProfileLabelFontName, size: CGFloat(viewYourProfileLabelSize))
            }
        }
        
        //setup logout button
        if let logoutButtonImage = image(forAsset: "cleeng_settings_profile_logout") {
            logoutButton.setBackgroundImage(logoutButtonImage, for: .normal)
        }
        
        //setup background image from asset
        var bgImage: UIImage? = setupCleengSettingsBackground()
        
        if bgImage == nil {
            if let stylesDict = screenModel?.style?.object {
                //setup bg image from the styles
                if let mainBackgroundColor = stylesDict["cleeng_settings_screen_background_color"] as? String {
                    bgImage = UIImage(from: UIColor(argbHexString: mainBackgroundColor))
                }
            }
        }
        if bgImage == nil {
            //setup bg image from the main cleeng bg
            if let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate {
                backgroundImageView.setupCleengBackground(with: stylesManager)
            }
            return
        }
        backgroundImageView.image = bgImage
    }
    
    private func setupCellCustomization(cell: CleengSettingsScreenTableViewCell) {
        if let stylesDict = screenModel?.style?.object {
            if let cellFontName = stylesDict["cleeng_settings_menu_item_text_font"] as? String,
                let cellFontSizeString = stylesDict["cleeng_settings_menu_item_text_size"] as? String,
                let cellFontSize = Float(cellFontSizeString),
                let cellFontFontColor = stylesDict["cleeng_settings_menu_item_text_color"] as? String {
                cell.itemLabel.font = UIFont(name: cellFontName, size: CGFloat(cellFontSize))
                cell.itemLabel.textColor = UIColor(argbHexString: cellFontFontColor)
            }
			if let cellBGColor = stylesDict["menu_item_bg_color"] as? String {
				cell.backgroundColor = UIColor(argbHexString: cellBGColor);
				cell.bgColor = UIColor(argbHexString: cellBGColor);
			}
			if let cellBGColorSelected = stylesDict["menu_item_selected_bg_color"] as? String {
				cell.bgColorSelected = UIColor(argbHexString: cellBGColorSelected);
			}
        }
    }
    
    private func setupCleengSettingsBackground() -> UIImage? {
        
        let bounds: CGRect = (UIApplication.shared.keyWindow?.bounds)!
        guard bounds.width != 0 && bounds.height != 0 else {
            return nil
        }
        
        let imageKey: String
        if UI_USER_INTERFACE_IDIOM() == .phone {
            imageKey = "settings_background_image"
        } else {
            imageKey = "settings_background_image~ipad"
        }
        return image(forAsset: imageKey)
    }
    
    private func image(forAsset key: String?) -> UIImage? {
        guard let asset = key else {
            return nil
        }
        if let image = UIImage(named: "cleeng_settings_ios/\(asset)") {
            return image
        }
        return nil
    }
}
