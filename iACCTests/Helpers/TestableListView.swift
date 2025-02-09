//	
// Copyright © Essential Developer. All rights reserved.
//

import UIKit
import XCTest

protocol TestableListView: UIScrollView {
    var numberOfSections: Int { get }
    func numberOfCells(inSection section: Int) -> Int
    func cell(at indexPath: IndexPath) -> UIView?
}

extension UITableView: TestableListView {
    func numberOfCells(inSection section: Int) -> Int {
        layoutIfNeeded()
        return numberOfSections > section ? numberOfRows(inSection: section) : 0
    }
    
    func cell(at indexPath: IndexPath) -> UIView? {
        layoutIfNeeded()
        return cellForRow(at: indexPath)
    }
}

extension UICollectionView: TestableListView {
    func numberOfCells(inSection section: Int) -> Int {
        layoutIfNeeded()
        return numberOfSections > section ? numberOfItems(inSection: section) : 0
    }
    
    func cell(at indexPath: IndexPath) -> UIView? {
        layoutIfNeeded()
        return cellForItem(at: indexPath)
    }
}
