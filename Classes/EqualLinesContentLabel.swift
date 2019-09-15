//
//  EqualLinesContentLabel.swift
//  CleengLogin
//
//  Created by Yossi Avramov on 19/06/2018.
//

import UIKit

class EqualLinesContentLabel : UILabel {
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        if numberOfLines == 1 {
            return super.textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)
        } else {
            let originalRect = super.textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)
            guard !(originalRect.isNull) else { return originalRect }
            guard !(originalRect.isInfinite) else { return originalRect }
            
            let updatedNumberOfLines = ((numberOfLines == 0) ? 0 : (numberOfLines + 1))
            
            var lastRect = originalRect
            var updatedBounds = originalRect
            updatedBounds.size.width -= 10
            updatedBounds.size.height = CGFloat.greatestFiniteMagnitude
            while updatedBounds.width > 10 && (updatedBounds.width + 120 > originalRect.width) {
                let updatedRect = super.textRect(forBounds: updatedBounds, limitedToNumberOfLines: updatedNumberOfLines)
                if updatedRect.height > originalRect.height + 1 {
                    break
                }
                
                lastRect = updatedRect
                updatedBounds.size.width -= 10
            }
            
            return lastRect
        }
    }
}
