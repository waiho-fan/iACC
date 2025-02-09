//
// Copyright © Essential Developer. All rights reserved.
//

import UIKit
import XCTest

extension UIView {
    func simulateTap() throws {
        let window = try XCTUnwrap(window)
        let touch = makeTouch(at: center, in: window)
        let event = try makeEvent(with: touch)

        set(phase: .began, for: touch)
        window.sendEvent(event)
        
        set(phase: .ended, for: touch)
        window.sendEvent(event)
    }
    
    private func makeTouch(at point: CGPoint, in window: UIWindow) -> UITouch {
        let pointInWindow = convert(point, to: window)
        let targetView = window.hitTest(pointInWindow, with: nil)
        
        let touch = UITouch()
        touch.setValue(window, forKeyPath: "window")
        touch.setValue(1, forKeyPath: "tapCount")
        touch.setValue(pointInWindow, forKeyPath: "locationInWindow")
        touch.setValue(pointInWindow, forKeyPath: "previousLocationInWindow")
        touch.setValue(targetView, forKeyPath: "view")
        touch.setValue(true, forKeyPath: "isFirstTouchForView")
        return touch
    }
    
    private func set(phase: UITouch.Phase, for touch: UITouch) {
        touch.setValue(phase.rawValue, forKeyPath: "phase")
        touch.setValue(ProcessInfo.processInfo.systemUptime, forKeyPath: "timestamp")
    }
    
    private func makeEvent(with touch: UITouch) throws -> UIEvent {
        let event = try XCTUnwrap(UIApplication.shared.value(forKey: "_touchesEvent") as? UIEvent)
        event.perform(Selector(("_clearTouches")))
        event.perform(Selector(("_addTouch:forDelayedDelivery:")), with: touch, with: false)
        return event
    }
}
