//
// Copyright © Essential Developer. All rights reserved.
//

import UIKit

extension UIView {
    func firstView<T>(ofType type: T.Type) -> T? {
        if let match = self as? T {
            return match
        }
        
        for subview in self.subviews {
            if let match = subview as? T {
                return match
            }
            if let match = subview.firstView(ofType: type) {
                return match
            }
        }
        return nil
    }
    
    func has(label: String) -> Bool {
        if 
            let view = self as? UILabel,
            let text = (view.text ?? view.attributedText?.string),
            text.normalized == label {
            return true
        }
        
        let accessibilityElements = accessibilityElements?.compactMap { $0 as? NSObject } ?? []
        for accessibilityElement in accessibilityElements {
            for accessibilityLabel in accessibilityElement.accessibilityLabels() {
                if accessibilityLabel.normalized == label {
                    return true
                }
            }
        }
        
        for subview in subviews {
            if subview.has(label: label) {
                return true
            }
        }
        
        return false
    }
}

private extension String {
    var normalized: String {
        replacingOccurrences(of: " ", with: " ")
    }
}

private extension NSObject {
    func accessibilityLabels() -> [String] {
        var labels = [String]()

        if let accessibilityLabel {
            labels.append(accessibilityLabel)
        }
        
        guard let attributedLabel = accessibilityAttributedLabel else { return labels }
        
        attributedLabel.enumerateAttributes(in: NSRange(location: 0, length: attributedLabel.length), options: []) { (attributes, range, _) in
            if attributes.count > 0 {
                labels.append(attributedLabel.attributedSubstring(from: range).string)
            }
        }
        
        return labels
    }
}
