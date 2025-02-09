//	
// Copyright © Essential Developer. All rights reserved.
//

import UIKit
import XCTest
@testable import iACC

///
/// This `UIViewController` test helper extension provides ways of performing
/// common operations and extracting values from the view controller without coupling the tests with
/// internal implementation details, such as table/collection views, alerts, labels, refresh controls, and buttons.
/// So we can later change those internal details without breaking the tests.
///
extension UIViewController {
    
    func listView() -> TestableListView? {
        view.firstView(ofType: TestableListView.self)
    }
    
    func simulateRefresh() async throws {
        let listView = try await existence(of: self.listView())
        let control = try await existence(of: listView.refreshControl)
        
        guard !control.isRefreshing else { return }
                
        listView.contentOffset = CGPoint(x: 0, y: -control.frame.height-view.safeAreaInsets.top)
        try await until(control.window != nil)
        control.beginRefreshing()
        control.sendActions(for: .valueChanged)
        listView.contentOffset = CGPoint(x: 0, y: -view.safeAreaInsets.top)
    }
    
    func isShowingLoadingIndicator() -> Bool {
        listView()?.refreshControl?.isRefreshing == true
    }

    func alert() -> UIView? {
        (presenterVC.presentedViewController as? UIAlertController)?.view
    }
    
}
