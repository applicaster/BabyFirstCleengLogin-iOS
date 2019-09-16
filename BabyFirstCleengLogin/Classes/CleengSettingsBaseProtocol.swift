//
//  CleengSettingsBaseProtocol.swift
//  AFNetworking
//
//  Created by Anton Klysa on 6/26/19.
//

import ZappPlugins

protocol CleengSettingsBaseProtocol {
    
    //MARK: props
    var cleengLogin: ZappCleengLogin? { get set }
    var pluginModel: ZPPluginModel? { get set }
    var screenModel: ZLScreenModel? { get set }
    var dataSourceModel: NSObject? { get set }
}
