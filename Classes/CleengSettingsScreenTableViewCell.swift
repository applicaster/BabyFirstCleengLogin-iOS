//
//  CleengSettingsScreenTableViewCell.swift
//  CleengLogin
//
//  Created by Liviu Romascanu on 15/02/2019.
//

import UIKit

class CleengSettingsScreenTableViewCell: UITableViewCell {

    @IBOutlet weak var itemImageView: UIImageView!
    @IBOutlet weak var arrowImageView: UIImageView!
    @IBOutlet weak var itemLabel: UILabel!
	open var bgColor: UIColor? = UIColor(argbHexString: "#00000000")
	open var bgColorSelected: UIColor? = UIColor(argbHexString: "#00000000")
	
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
	
	override func setSelected(_ selected: Bool, animated: Bool) {
		super.setSelected(selected, animated: animated)
		
		if(selected) {
			super.backgroundColor = bgColorSelected;
		} else {
			super.backgroundColor = bgColor;
		}
	}
}
