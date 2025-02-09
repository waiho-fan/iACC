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
class CardsIntegrationTests: XCTestCase {
	
    override func tearDownWithError() throws {
        try SceneBuilder.reset()
		
		super.tearDown()
	}
	
	func test_cardsList_title() throws {
		let cardsList = try SceneBuilder().build().cardsList()
		
        cardsList.loadViewIfNeeded()
        
		XCTAssertEqual(cardsList.title, "Cards", "title")
	}
    
    func test_cardsList_hasAddCardButton() throws {
		let cardsList = try SceneBuilder().build().cardsList()
		
        cardsList.loadViewIfNeeded()
        
		XCTAssertTrue(cardsList.hasAddCardButton, "add card button not found")
	}
    
    @MainActor
    func test_cardsList_addCardButton_showsAddCardViewOnTap() async throws {
		let cardsList = try SceneBuilder().build().cardsList()
		
        cardsList.loadViewIfNeeded()
        
		XCTAssertFalse(cardsList.isPresentingAddCardView, "precondition: shouldn't present add card view before tapping button")
		
		cardsList.tapAddCardButton()
		
		try await until(cardsList.isPresentingAddCardView == true)
	}
    
    @MainActor
    func test_cardsList_showsCards_whenAPIRequestSucceeds() async throws {
		let card0 = aCard(number: "a number", holder: "a holder")
		let card1 = aCard(number: "another number", holder: "another holder")
		let cardsList = try SceneBuilder()
			.build(cardsAPI: .once([card0, card1]))
			.cardsList()
		        
        try await until(cardsList.numberOfCards() == 2)
        try await until(cardsList.cell(at: 0)?.has(label: card0.number) == true)
        try await until(cardsList.cell(at: 0)?.has(label: card0.holder) == true)
        try await until(cardsList.cell(at: 1)?.has(label: card1.number) == true)
        try await until(cardsList.cell(at: 1)?.has(label: card1.holder) == true)
	}
    
    @MainActor
    func test_cardsList_showsError_whenAPIRequestFails() async throws {
		let cardsList = try SceneBuilder()
			.build(cardsAPI: .once(NSError(localizedDescription: "an error")))
			.cardsList()
		
        try await until(cardsList.numberOfCards() == 0)
        try await until(cardsList.alert()?.has(label: "an error") == true)
	}
    
    @MainActor
    func test_cardsList_canRefreshData() async throws {
        let card = aCard(number: "number", holder: "holder")
		let anotherCard = aCard(number: "another number", holder: "another holder")
		
		let cardsList = try SceneBuilder()
			.build(cardsAPI: .results([
				.success([card]),
				.success([card, anotherCard])
			]))
			.cardsList()
		
        try await until(cardsList.numberOfCards() == 1)
        try await until(cardsList.cell(at: 0)?.has(label: card.number) == true)
        try await until(cardsList.cell(at: 0)?.has(label: card.holder) == true)

        XCTAssertFalse(cardsList.isShowingLoadingIndicator())
        try await cardsList.simulateRefresh()
        XCTAssertTrue(cardsList.isShowingLoadingIndicator())
        
        try await until(cardsList.isShowingLoadingIndicator() == false)
        try await until(cardsList.numberOfCards() == 2)
        try await until(cardsList.cell(at: 0)?.has(label: card.number) == true)
        try await until(cardsList.cell(at: 0)?.has(label: card.holder) == true)
        try await until(cardsList.cell(at: 1)?.has(label: anotherCard.number) == true)
        try await until(cardsList.cell(at: 1)?.has(label: anotherCard.holder) == true)
	}
    
    @MainActor
    func test_cardsList_showsError_whenRefreshAPIRequestFails() async throws {
        let cardsList = try SceneBuilder()
            .build(cardsAPI: .results([
                .success([aCard()]),
                .failure(NSError(localizedDescription: "refresh error")),
            ]))
            .cardsList()
        
        try await until(cardsList.numberOfCards() == 1)
        XCTAssertNil(cardsList.alert())
        
        XCTAssertFalse(cardsList.isShowingLoadingIndicator())
        try await cardsList.simulateRefresh()
        XCTAssertTrue(cardsList.isShowingLoadingIndicator())

        try await until(cardsList.isShowingLoadingIndicator() == false)
        try await until(cardsList.alert()?.has(label: "refresh error") == true)
    }

    @MainActor
	func test_cardsList_canSelectCard() async throws {
		let card = aCard(number: "a number", holder: "a holder")

        let cardsList = try SceneBuilder()
			.build(cardsAPI: .once([card]))
			.cardsList()

        try await until(cardsList.numberOfCards() == 1)
        
        try cardsList.selectCard(at: 0)
        try await until(cardsList.isShowingDetails(for: card))
	}
	
}

private extension TestViewControllerContainer {
	///
	/// Provides ways of extracting the "cards" list view controller from the root tab bar
	/// without coupling the tests with internal implementation details, such as the tab item index.
	/// So we can later change those internal details easily without breaking the tests.
	///
	func cardsList() throws -> UIViewController {
        let navigation: UINavigationController = try rootTab(atIndex: 2)
        return try XCTUnwrap(navigation.topViewController, "couldn't find card list")
	}
}

///
/// This `UIViewController` test helper extension provides ways of extracting values
/// from the view controller without coupling the tests with internal implementation details, such as
/// table views, labels, and buttons. So we can later change those internal details without
/// breaking the tests.
///
private extension UIViewController {
    
	func numberOfCards() -> Int {
        listView()?.numberOfCells(inSection: cardsSection) ?? 0
	}
	
    func cell(at row: Int) -> UIView? {
        listView()?.cell(at: IndexPath(row: row, section: cardsSection))
    }
    
    func selectCard(at row: Int) throws {
        try XCTUnwrap(cell(at: row)).simulateTap()
    }
	
	func isShowingDetails(for card: Card) -> Bool {
		let vc = navigationController?.topViewController as? CardDetailsViewController
		return vc?.card == card
	}

	var hasAddCardButton: Bool {
		navigationItem.rightBarButtonItem?.systemItem == .add
	}
	
	var isPresentingAddCardView: Bool {
		navigationController?.topViewController is AddCardViewController
	}
	
	func tapAddCardButton() {
		navigationItem.rightBarButtonItem?.simulateTap()
	}
	
	private var cardsSection: Int { 0 }
}
