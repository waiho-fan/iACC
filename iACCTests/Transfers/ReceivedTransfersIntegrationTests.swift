//
// Copyright © Essential Developer. All rights reserved.
//

import XCTest
@testable import iACC

///
/// When dealing with legacy code, you most likely won't be able to test screens independently
/// because all dependencies are accessed directly through Singletons or passed from one
/// view controller to another.
///
/// So the simplest way to start testing legacy code is to write Integration Tests covering the
/// behavior from the view controllers all the way to deeper dependencies such as database
/// and network classes.
///
/// Writing fast and reliable Integration Tests before making changes to a legacy codebase can
/// give you confidence that you don't break existing behavior. If you trust those tests and they
/// still pass after a change, you're sure you didn't break anything.
///
/// That's why it's important to write tests you trust before making a change in legacy code.
///
/// So good Integration Tests can give you the confidence you didn't break anything when they pass.
/// But when they fail, it can be hard to find out *why it failed* and *where is the problem* because
/// many components are being tested together. The problem could be in a view, or in a model,
/// or in the database, or in the network component... You probably will have to debug to find the issue.
///
/// Thus, Integration Tests shouldn't be your primary testing strategy. Instead, you should focus on
/// testing components in isolation. So if the tests fail, you know exactly why and where.
///
/// But Integration Tests can be a simple way to start adding coverage to a legacy project until you can
/// break down the components and test them in isolation.
///
/// So to make this legacy project realistic, we kept the entangled legacy classes to show how you can start
/// testing components in integration without making massive changes to the project.
///
class ReceivedTransfersIntegrationTests: XCTestCase {
	
    override func tearDownWithError() throws {
        try SceneBuilder.reset()
		
		super.tearDown()
	}
	
	func test_receivedTransfersList_navigationTitle() throws {
		let receivedTransfersList = try SceneBuilder().build().receivedTransfersList()
        
        receivedTransfersList.loadViewIfNeeded()
		
		XCTAssertEqual(receivedTransfersList.navigationItem.title, "Received", "title")
	}
    
    func test_receivedTransfersList_hasRequestMoneyButton() throws {
		let receivedTransfersList = try SceneBuilder().build().receivedTransfersList()
		
        receivedTransfersList.loadViewIfNeeded()
        
		XCTAssertTrue(receivedTransfersList.hasRequestMoneyButton, "request money button not found")
	}
    
    @MainActor
    func test_receivedTransfersList_sendMoneyButton_showsRequestMoneyViewOnTap() async throws {
		let receivedTransfersList = try SceneBuilder().build().receivedTransfersList()
		
        receivedTransfersList.loadViewIfNeeded()
        
		XCTAssertFalse(receivedTransfersList.isPresentingRequestMoneyView, "precondition: shouldn't present request money view before tapping button")
		
		receivedTransfersList.tapRequestMoneyButton()
        
        try await until(receivedTransfersList.isPresentingRequestMoneyView == true)
	}
    
    @MainActor
    func test_receivedTransfersList_showsOnlyReceivedTranfers_whenAPIRequestSucceeds() async throws {
		let transfer0 = aTranfer(description: "a description", amount: 10.75, currencyCode: "USD", sender: "Bob", recipient: "Mary", sent: false, date: .APR_01_1976_AT_12_AM)
		let transfer1 = aTranfer(sent: true)
		let transfer2 = aTranfer(description: "another description", amount: 99.99, currencyCode: "GBP", sender: "Bob", recipient: "Mary", sent: false, date: .JUN_29_2007_AT_9_41_AM)
		
		let receivedTransfersList = try SceneBuilder()
			.build(transfersAPI: .once([transfer0, transfer1, transfer2]))
			.receivedTransfersList()
		
        try await until(receivedTransfersList.numberOfReceivedTransfers() == 2)
        try await until(receivedTransfersList.cell(at: 0)?.has(label: "$ 10.75 • a description") == true)
        try await until(receivedTransfersList.cell(at: 0)?.has(label: "Received from: Bob on 4/1/76, 12:00 AM") == true)
        try await until(receivedTransfersList.cell(at: 1)?.has(label: "£ 99.99 • another description") == true)
        try await until(receivedTransfersList.cell(at: 1)?.has(label: "Received from: Bob on 6/29/07, 9:41 AM") == true)
	}
    
    @MainActor
    func test_receivedTransfersList_canRefreshData() async throws {
		let refreshedTransfer0 = aTranfer(description: "a description", amount: 0.01, currencyCode: "EUR", sender: "Bob", recipient: "Mary", sent: false, date: .APR_01_1976_AT_12_AM)
		let refreshedTransfer1 = aTranfer(sent: true)
		
		let receivedTransfersList = try SceneBuilder()
			.build(transfersAPI: .results([
				.success([]),
				.success([refreshedTransfer0, refreshedTransfer1])
			]))
			.receivedTransfersList()
		
        try await until(receivedTransfersList.numberOfReceivedTransfers() == 0)
        
        XCTAssertFalse(receivedTransfersList.isShowingLoadingIndicator())
        try await receivedTransfersList.simulateRefresh()
        XCTAssertTrue(receivedTransfersList.isShowingLoadingIndicator())
        
        try await until(receivedTransfersList.isShowingLoadingIndicator() == false)
        try await until(receivedTransfersList.numberOfReceivedTransfers() == 1)
        try await until(receivedTransfersList.cell(at: 0)?.has(label: "€ 0.01 • a description") == true)
        try await until(receivedTransfersList.cell(at: 0)?.has(label: "Received from: Bob on 4/1/76, 12:00 AM") == true)
	}
    
    @MainActor
    func test_receivedTransfersList_showsError_afterRetryingFailedAPIRequestOnce() async throws {
		let receivedTransfersList = try SceneBuilder()
			.build(
				user: nonPremiumUser(),
				transfersAPI: .results([
					.failure(NSError(localizedDescription: "request error")),
					.failure(NSError(localizedDescription: "retry error")),
				])
			)
			.receivedTransfersList()
		
        try await until(receivedTransfersList.numberOfReceivedTransfers() == 0)
        try await until(receivedTransfersList.alert()?.has(label: "retry error") == true)
	}
    
    @MainActor
    func test_receivedTransfersList_refreshData_showsError_afterRetryingFailedAPIRequestOnce() async throws {
		let receivedTransfersList = try SceneBuilder()
			.build(
				transfersAPI: .results([
                    .failure(NSError(localizedDescription: "error")),
                    .success([aTranfer(sent: false)]),
					
					.failure(NSError(localizedDescription: "refresh error")),
					.failure(NSError(localizedDescription: "refresh retry error")),
                    
                    .failure(NSError(localizedDescription: "refresh error")),
                    .success([aTranfer(sent: false), aTranfer(sent: false)]),
				])
			)
			.receivedTransfersList()
		
        try await until(receivedTransfersList.numberOfReceivedTransfers() == 1)
        XCTAssertNil(receivedTransfersList.alert())
        
        XCTAssertFalse(receivedTransfersList.isShowingLoadingIndicator())
        try await receivedTransfersList.simulateRefresh()
        XCTAssertTrue(receivedTransfersList.isShowingLoadingIndicator())

        try await until(receivedTransfersList.isShowingLoadingIndicator() == false)
        try await until(receivedTransfersList.alert()?.has(label: "refresh retry error") == true)
        
        XCTAssertFalse(receivedTransfersList.isShowingLoadingIndicator())
        try await receivedTransfersList.simulateRefresh()
        XCTAssertTrue(receivedTransfersList.isShowingLoadingIndicator())

        try await until(receivedTransfersList.isShowingLoadingIndicator() == false)
        try await until(receivedTransfersList.numberOfReceivedTransfers() == 2)
	}
    
    @MainActor
    func test_receivedTransfersList_canSelectTransfer() async throws {
		let receivedTransfer = aTranfer(sent: false)
		
		let receivedTransfersList = try SceneBuilder()
			.build(transfersAPI: .once([receivedTransfer]))
			.receivedTransfersList()
		
        try await until(receivedTransfersList.numberOfReceivedTransfers() == 1)
        
        try receivedTransfersList.selectTransfer(at: 0)
        try await until(receivedTransfersList.isShowingDetails(for: receivedTransfer))
	}
	
}

private extension TestViewControllerContainer {
	///
	/// Provides ways of extracting the "received transfers" list view controller from the root tab bar
	/// without coupling the tests with internal implementation details, such as the tab item index.
	/// So we can later change those internal details easily without breaking the tests.
	///
	func receivedTransfersList() throws -> UIViewController {
        let navigation: SegmentNavigationViewController = try rootTab(atIndex: 1)
		
		if navigation.selectedSegmentIndex != 1 {
            navigation.selectSegment(at: 1, animated: false)
		}
		
		return try XCTUnwrap(navigation.topViewController, "couldn't find received transfers list")
	}
}

///
/// This `UIViewController` test helper extension provides ways of extracting values
/// from the view controller without coupling the tests with internal implementation details, such as
/// table views, labels, and buttons. So we can later change those internal details without
/// breaking the tests.
///
private extension UIViewController {
    
	func numberOfReceivedTransfers() -> Int {
        listView()?.numberOfCells(inSection: receivedTransfersSection) ?? 0
	}
	
    func cell(at row: Int) -> UIView? {
        listView()?.cell(at: IndexPath(row: row, section: receivedTransfersSection))
    }
    
    func selectTransfer(at row: Int) throws {
        try XCTUnwrap(cell(at: row)).simulateTap()
    }
    
	func isShowingDetails(for transfer: Transfer) -> Bool {
		let vc = navigationController?.topViewController as? TransferDetailsViewController
		return vc?.transfer == transfer
	}

	var hasRequestMoneyButton: Bool {
		navigationItem.rightBarButtonItem?.title == "Request"
	}
	
	var isPresentingRequestMoneyView: Bool {
		navigationController?.topViewController is RequestMoneyViewController
	}
	
	func tapRequestMoneyButton() {
		navigationItem.rightBarButtonItem?.simulateTap()
	}
	
	private var receivedTransfersSection: Int { 0 }
}
