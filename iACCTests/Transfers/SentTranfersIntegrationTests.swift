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
class SentTranfersIntegrationTests: XCTestCase {
	
	override func tearDownWithError() throws {
		try SceneBuilder.reset()
		
		super.tearDown()
	}
    
    func test_sentTransfersList_navigationTitle() throws {
		let sentTransfersList = try SceneBuilder().build().sentTransfersList()
		
        sentTransfersList.loadViewIfNeeded()
        
		XCTAssertEqual(sentTransfersList.navigationItem.title, "Sent", "title")
	}
    
    func test_sentTransfersList_hasSendMoneyButton() throws {
		let sentTransfersList = try SceneBuilder().build().sentTransfersList()
		
        sentTransfersList.loadViewIfNeeded()
        
		XCTAssertTrue(sentTransfersList.hasSendMoneyButton, "send money button not found")
	}
    
    @MainActor
    func test_sentTransfersList_sendMoneyButton_showsSendMoneyViewOnTap() async throws {
		let sentTransfersList = try SceneBuilder().build().sentTransfersList()
		
        sentTransfersList.loadViewIfNeeded()
        
		XCTAssertFalse(sentTransfersList.isPresentingSendMoneyView, "precondition: shouldn't present send money view before tapping button")
		
		sentTransfersList.tapSendMoneyButton()
		
        try await until(sentTransfersList.isPresentingSendMoneyView == true)
	}
    
    @MainActor
    func test_sentTransfersList_showsOnlySentTranfers_whenAPIRequestSucceeds() async throws {
		let transfer0 = aTranfer(description: "a description", amount: 10.75, currencyCode: "USD", sender: "Bob", recipient: "Mary", sent: true, date: .APR_01_1976_AT_12_AM)
		let transfer1 = aTranfer(sent: false)
		let transfer2 = aTranfer(description: "another description", amount: 99.99, currencyCode: "GBP", sender: "Bob", recipient: "Mary", sent: true, date: .JUN_29_2007_AT_9_41_AM)

		let sentTransfersList = try SceneBuilder()
			.build(transfersAPI: .once([transfer0, transfer1, transfer2]))
			.sentTransfersList()
		        
        try await until(sentTransfersList.numberOfSentTransfers() == 2)
        try await until(sentTransfersList.cell(at: 0)?.has(label: "$ 10.75 • a description") == true)
        try await until(sentTransfersList.cell(at: 0)?.has(label: "Sent to: Mary on April 1, 1976 at 12:00 AM") == true)
        try await until(sentTransfersList.cell(at: 1)?.has(label: "£ 99.99 • another description") == true)
        try await until(sentTransfersList.cell(at: 1)?.has(label: "Sent to: Mary on June 29, 2007 at 9:41 AM") == true)
	}
    
    @MainActor
    func test_sentTransfersList_canRefreshData() async throws {
		let refreshedTransfer0 = aTranfer(description: "a description", amount: 0.01, currencyCode: "EUR", sender: "Bob", recipient: "Mary", sent: true, date: .APR_01_1976_AT_12_AM)
		let refreshedTransfer1 = aTranfer(sent: false)

		let sentTransfersList = try SceneBuilder()
			.build(transfersAPI: .results([
				.success([]),
				.success([refreshedTransfer0, refreshedTransfer1])
			]))
			.sentTransfersList()
		
        try await until(sentTransfersList.numberOfSentTransfers() == 0)
        
        XCTAssertFalse(sentTransfersList.isShowingLoadingIndicator())
		try await sentTransfersList.simulateRefresh()
        XCTAssertTrue(sentTransfersList.isShowingLoadingIndicator())
        
        try await until(sentTransfersList.isShowingLoadingIndicator() == false)
        try await until(sentTransfersList.numberOfSentTransfers() == 1)
        try await until(sentTransfersList.cell(at: 0)?.has(label: "€ 0.01 • a description") == true)
        try await until(sentTransfersList.cell(at: 0)?.has(label: "Sent to: Mary on April 1, 1976 at 12:00 AM") == true)
	}

    @MainActor
	func test_sentTransfersList_showsError_afterRetryingFailedAPIRequestOnce() async throws {
		let sentTransfersList = try SceneBuilder()
			.build(
				user: nonPremiumUser(),
				transfersAPI: .results([
					.failure(NSError(localizedDescription: "request error")),
					.failure(NSError(localizedDescription: "retry error")),
				])
			)
			.sentTransfersList()

        try await until(sentTransfersList.numberOfSentTransfers() == 0)
        try await until(sentTransfersList.alert()?.has(label: "retry error") == true)
	}

    @MainActor
	func test_sentTransfersList_refreshData_showsError_afterRetryingFailedAPIRequestOnce() async throws {
		let sentTransfersList = try SceneBuilder()
			.build(
				transfersAPI: .results([
                    .failure(NSError(localizedDescription: "error")),
                    .success([aTranfer(sent: true)]),
                    
					.failure(NSError(localizedDescription: "refresh error")),
					.failure(NSError(localizedDescription: "refresh retry error")),
                    
                    .failure(NSError(localizedDescription: "refresh error")),
                    .success([aTranfer(sent: true), aTranfer(sent: true)]),
				])
			)
			.sentTransfersList()

        try await until(sentTransfersList.numberOfSentTransfers() == 1)
        XCTAssertNil(sentTransfersList.alert())
        
        XCTAssertFalse(sentTransfersList.isShowingLoadingIndicator())
        try await sentTransfersList.simulateRefresh()
        XCTAssertTrue(sentTransfersList.isShowingLoadingIndicator())

        try await until(sentTransfersList.isShowingLoadingIndicator() == false)
        try await until(sentTransfersList.alert()?.has(label: "refresh retry error") == true)
        
        XCTAssertFalse(sentTransfersList.isShowingLoadingIndicator())
        try await sentTransfersList.simulateRefresh()
        XCTAssertTrue(sentTransfersList.isShowingLoadingIndicator())

        try await until(sentTransfersList.isShowingLoadingIndicator() == false)
        try await until(sentTransfersList.numberOfSentTransfers() == 2)
	}
    
    @MainActor
    func test_sentTransfersList_canSelectTransfer() async throws {
		let sentTransfer = aTranfer(sent: true)
		
		let sentTransfersList = try SceneBuilder()
			.build(transfersAPI: .once([sentTransfer]))
			.sentTransfersList()
		
        try await until(sentTransfersList.numberOfSentTransfers() == 1)
        
        try sentTransfersList.selectTransfer(at: 0)
        try await until(sentTransfersList.isShowingDetails(for: sentTransfer))
	}
    
}

private extension TestViewControllerContainer {
	///
	/// Provides ways of extracting the "sent transfers" list view controller from the root tab bar
	/// without coupling the tests with internal implementation details, such as the tab item index.
	/// So we can later change those internal details easily without breaking the tests.
	///
	func sentTransfersList() throws -> UIViewController {
        let navigation: UINavigationController = try rootTab(atIndex: 1)
        return try XCTUnwrap(navigation.topViewController, "couldn't find sent transfers list")
	}
}

///
/// This `UIViewController` test helper extension provides ways of extracting values
/// from the view controller without coupling the tests with internal implementation details, such as
/// table views, labels, and buttons. So we can later change those internal details without
/// breaking the tests.
///
private extension UIViewController {
    
	func numberOfSentTransfers() -> Int {
        listView()?.numberOfCells(inSection: sentTransfersSection) ?? 0
	}
    
    func cell(at row: Int) -> UIView? {
        listView()?.cell(at: IndexPath(row: row, section: sentTransfersSection))
    }
	
	func selectTransfer(at row: Int) throws {
        try XCTUnwrap(cell(at: row)).simulateTap()
	}
	
	func isShowingDetails(for transfer: Transfer) -> Bool {
		let vc = navigationController?.topViewController as? TransferDetailsViewController
		return vc?.transfer == transfer
	}

	var hasSendMoneyButton: Bool {
		navigationItem.rightBarButtonItem?.title == "Send"
	}
	
	var isPresentingSendMoneyView: Bool {
		navigationController?.topViewController is SendMoneyViewController
	}
	
	func tapSendMoneyButton() {
		navigationItem.rightBarButtonItem?.simulateTap()
	}
	
	private var sentTransfersSection: Int { 0 }
}
