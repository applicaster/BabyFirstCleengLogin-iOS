//
//  DispatchQueue+Extension.swift
//  CleengPlugin
//
//  Created by Yossi Avramov on 30/05/2018.
//  Copyright © 2018 Applicaster. All rights reserved.
//

import Foundation

internal extension DispatchQueue {
    static func onMain(_ block: @escaping (() -> Void)) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
