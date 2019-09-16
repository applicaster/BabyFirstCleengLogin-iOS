//
//  File.swift
//  CleengLogin
//
//  Created by Itai Navot on 08/04/2019.
//

import Foundation


struct CleengUser: Codable {
	var token: String?
	var email: String?
	
	enum CodingKeys: String, CodingKey {
		case token
		case email
	}
	
	init() {
		
	}
	
	init(email: String) {
		self.email = email
	}
}
