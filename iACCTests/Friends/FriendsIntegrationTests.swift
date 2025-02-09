//	
// Copyright © Essential Developer. All rights reserved.
//

import XCTest
import SwiftUI
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
class FriendsIntegrationTests: XCTestCase {
	
    override func tearDownWithError() throws {
        try SceneBuilder.reset()
		
		super.tearDown()
	}
	
	func test_friendsList_title() throws {
		let friendsList = try SceneBuilder().build().friendsList()
		
        friendsList.loadViewIfNeeded()

		XCTAssertEqual(friendsList.title, "Friends")
	}
	
	func test_friendsList_hasAddFriendButton() throws {
		let friendsList = try SceneBuilder().build().friendsList()
		
        friendsList.loadViewIfNeeded()
        
		XCTAssertTrue(friendsList.hasAddFriendButton, "add friend button not found")
	}
	
    @MainActor
	func test_friendsList_addFriendButton_showsAddFriendViewOnTap() async throws {
		let friendsList = try SceneBuilder().build().friendsList()

        friendsList.loadViewIfNeeded()
        
		XCTAssertFalse(friendsList.isPresentingAddFriendView, "precondition: shouldn't present add friend view before tapping button")
		
		friendsList.tapAddFriendButton()
		
        try await until(friendsList.isPresentingAddFriendView == true)
	}
	
    @MainActor
    func test_friendsList_withNonPremiumUser_showsFriends_whenAPIRequestSucceeds() async throws {
		let friend0 = aFriend(name: "a name", phone: "a phone")
		let friend1 = aFriend(name: "another name", phone: "another phone")
		let friendsList = try SceneBuilder()
			.build(
				user: nonPremiumUser(),
				friendsAPI: .once([friend0, friend1]),
				friendsCache: .never
			)
			.friendsList()
        
        try await until(friendsList.numberOfFriends() == 2)
        try await until(friendsList.cell(at: 0)?.has(label: friend0.name) == true)
        try await until(friendsList.cell(at: 0)?.has(label: friend0.phone) == true)
        try await until(friendsList.cell(at: 1)?.has(label: friend1.name) == true)
        try await until(friendsList.cell(at: 1)?.has(label: friend1.phone) == true)
	}
	
    @MainActor
    func test_friendsList_withNonPremiumUser_showsError_afterRetryingFailedAPIRequestTwice() async throws {
		let friendsList = try SceneBuilder()
			.build(
				user: nonPremiumUser(),
				friendsAPI: .results([
					.failure(NSError(localizedDescription: "1st request error")),
					.failure(NSError(localizedDescription: "1st retry error")),
					.failure(NSError(localizedDescription: "2nd retry error"))
				]),
				friendsCache: .once([aFriend(), aFriend()])
			)
			.friendsList()
		        
        try await until(friendsList.numberOfFriends() == 0)
        try await until(friendsList.alert()?.has(label: "2nd retry error") == true)
	}
	
    @MainActor
    func test_friendsList_withPremiumUser_showsCachedFriends_afterRetryingFailedAPIRequestTwice() async throws {
		let friend0 = aFriend(name: "a name", phone: "a phone")
		let friend1 = aFriend(name: "another name", phone: "another phone")
		
		let friendsList = try SceneBuilder()
			.build(
				user: premiumUser(),
				friendsAPI: .results([
					.failure(NSError(localizedDescription: "1st request error")),
					.failure(NSError(localizedDescription: "1st retry error")),
					.failure(NSError(localizedDescription: "2nd retry error"))
				]),
				friendsCache: .once([friend0, friend1])
			)
			.friendsList()
		        
        try await until(friendsList.numberOfFriends() == 2)
        try await until(friendsList.cell(at: 0)?.has(label: friend0.name) == true)
        try await until(friendsList.cell(at: 0)?.has(label: friend0.phone) == true)
        try await until(friendsList.cell(at: 1)?.has(label: friend1.name) == true)
        try await until(friendsList.cell(at: 1)?.has(label: friend1.phone) == true)
	}
	
    @MainActor
    func test_friendsList_withPremiumUser_showsError_whenCacheFails_afterRetryingFailedAPIRequestTwice() async throws {
		let friendsList = try SceneBuilder()
			.build(
				user: premiumUser(),
				friendsAPI: .results([
					.failure(NSError(localizedDescription: "1st request error")),
					.failure(NSError(localizedDescription: "1st retry error")),
					.failure(NSError(localizedDescription: "2nd retry error"))
				]),
				friendsCache: .once(NSError(localizedDescription: "cache error"))
			)
			.friendsList()
        
        try await until(friendsList.numberOfFriends() == 0)
        try await until(friendsList.alert()?.has(label: "cache error") == true)
	}
	
    @MainActor
    func test_friendsList_canRefreshData() async throws {
        let friend = aFriend(name: "name", phone: "phone")
		let anotherFriend = aFriend(name: "another name", phone: "another phone")
		
		let friendsList = try SceneBuilder()
			.build(
				friendsAPI: .results([
					.success([friend]),
					.success([friend, anotherFriend])
				])
			)
			.friendsList()
		        
        try await until(friendsList.numberOfFriends() == 1)
        try await until(friendsList.cell(at: 0)?.has(label: friend.name) == true)
        try await until(friendsList.cell(at: 0)?.has(label: friend.phone) == true)

        XCTAssertFalse(friendsList.isShowingLoadingIndicator())
        try await friendsList.simulateRefresh()
        XCTAssertTrue(friendsList.isShowingLoadingIndicator())
        
        try await until(friendsList.isShowingLoadingIndicator() == false)
        try await until(friendsList.numberOfFriends() == 2)
        try await until(friendsList.cell(at: 0)?.has(label: friend.name) == true)
        try await until(friendsList.cell(at: 0)?.has(label: friend.phone) == true)
        try await until(friendsList.cell(at: 1)?.has(label: anotherFriend.name) == true)
        try await until(friendsList.cell(at: 1)?.has(label: anotherFriend.phone) == true)
	}
	
    @MainActor
    func test_friendsList_refreshData_showsError_afterRetryingFailedAPIRequestTwice() async throws {
		let friendsList = try SceneBuilder()
			.build(
				friendsAPI: .results([
                    .failure(NSError(localizedDescription: "error")),
                    .failure(NSError(localizedDescription: "retry error")),
                    .success([aFriend()]),
                    
					.failure(NSError(localizedDescription: "refresh error")),
					.failure(NSError(localizedDescription: "1st refresh retry error")),
					.failure(NSError(localizedDescription: "2nd refresh retry error")),
                    
                    .failure(NSError(localizedDescription: "refresh error")),
                    .failure(NSError(localizedDescription: "1st refresh retry error")),
                    .success([aFriend(), aFriend()]),
				]),
				friendsCache: .never
			)
			.friendsList()
		
        try await until(friendsList.numberOfFriends() == 1)
        XCTAssertNil(friendsList.alert())
        
        XCTAssertFalse(friendsList.isShowingLoadingIndicator())
        try await friendsList.simulateRefresh()
        XCTAssertTrue(friendsList.isShowingLoadingIndicator())
                
        try await until(friendsList.isShowingLoadingIndicator() == false)
        try await until(friendsList.alert()?.has(label: "2nd refresh retry error") == true)

        XCTAssertFalse(friendsList.isShowingLoadingIndicator())
        try await friendsList.simulateRefresh()
        XCTAssertTrue(friendsList.isShowingLoadingIndicator())

        try await until(friendsList.isShowingLoadingIndicator() == false)
        try await until(friendsList.numberOfFriends() == 2)
	}
	
    @MainActor
    func test_friendsList_refreshData_withPremiumUser_showsCachedFriends_afterRetryingFailedAPIRequestTwice() async throws {
		let friend0 = aFriend(name: "a name", phone: "a phone")
		let friend1 = aFriend(name: "another name", phone: "another phone")
		
		let friendsList = try SceneBuilder()
			.build(
				user: premiumUser(),
				friendsAPI: .results([
					.success([friend0]),
					.failure(NSError(localizedDescription: "1st request error")),
					.failure(NSError(localizedDescription: "1st retry error")),
					.failure(NSError(localizedDescription: "2nd retry error"))
				]),
				friendsCache: .once([friend0, friend1])
			)
			.friendsList()
		
        try await until(friendsList.numberOfFriends() == 1)
        try await until(friendsList.cell(at: 0)?.has(label: friend0.name) == true)
        try await until(friendsList.cell(at: 0)?.has(label: friend0.phone) == true)

        XCTAssertFalse(friendsList.isShowingLoadingIndicator())
        try await friendsList.simulateRefresh()
        XCTAssertTrue(friendsList.isShowingLoadingIndicator())
        
        try await until(friendsList.isShowingLoadingIndicator() == false)
        try await until(friendsList.numberOfFriends() == 2)
        try await until(friendsList.cell(at: 0)?.has(label: friend0.name) == true)
        try await until(friendsList.cell(at: 0)?.has(label: friend0.phone) == true)
        try await until(friendsList.cell(at: 1)?.has(label: friend1.name) == true)
        try await until(friendsList.cell(at: 1)?.has(label: friend1.phone) == true)
	}
	
    @MainActor
    func test_friendsList_withNonPremiumUser_doesntCacheItems_whenAPIRequestSucceeds() async throws {
		let friend0 = aFriend()
		let friend1 = aFriend()
		var cachedItems = [[Friend]]()
		
		let friendsList = try SceneBuilder()
			.build(
				user: nonPremiumUser(),
				friendsAPI: .once([friend0, friend1]),
				friendsCache: .saveCallback { cachedItems.append($0) }
			)
			.friendsList()
		
        try await until(friendsList.numberOfFriends() == 2)
        
		XCTAssertEqual(cachedItems, [], "Shouldn't have cached items")
	}
	
    @MainActor
    func test_friendsList_withPremiumUser_cachesItems_whenAPIRequestSucceeds() async throws {
		let friend0 = aFriend()
		let friend1 = aFriend()
		var cachedItems = [[Friend]]()
		
		let friendsList = try SceneBuilder()
			.build(
				user: premiumUser(),
				friendsAPI: .once([friend0, friend1]),
				friendsCache: .saveCallback { cachedItems.append($0) }
			)
			.friendsList()
		
        try await until(friendsList.numberOfFriends() == 2)

		XCTAssertEqual(cachedItems, [[friend0, friend1]], "Should have cached items")
	}
	
    @MainActor
    func test_friendsList_canSelectAPIFriend() async throws {
		let friend = aFriend(name: "a name", phone: "a phone")
		
		let friendsList = try SceneBuilder()
			.build(
				user: premiumUser(),
				friendsAPI: .once([friend]),
				friendsCache: .never
			)
			.friendsList()
		
        try await until(friendsList.numberOfFriends() == 1)
        
        try friendsList.selectFriend(at: 0)
        try await until(friendsList.isShowingDetails(for: friend))
	}

    @MainActor
    func test_friendsList_canSelectCachedFriend() async throws {
		let friend = aFriend(name: "a name", phone: "a phone")
		
		let friendsList = try SceneBuilder()
			.build(
				user: premiumUser(),
				friendsAPI: .results([
					.failure(anError()),
					.failure(anError()),
					.failure(anError())
				]),
				friendsCache: .once([friend])
			)
			.friendsList()
		
        try await until(friendsList.numberOfFriends() == 1)

        try friendsList.selectFriend(at: 0)
        try await until(friendsList.isShowingDetails(for: friend))
	}

}

private extension TestViewControllerContainer {
	///
	/// Provides ways of extracting the "friends" list view controller from the root tab bar
	/// without coupling the tests with internal implementation details, such as the tab item index.
	/// So we can later change those internal details easily without breaking the tests.
	///
	func friendsList() throws -> UIViewController {
        let navigation: UINavigationController = try rootTab(atIndex: 0)
		return try XCTUnwrap(navigation.topViewController, "couldn't find friends list")
	}
}

///
/// This `UIViewController` test helper extension provides ways of extracting values
/// from the view controller without coupling the tests with internal implementation details, such as
/// table views, labels, and buttons. So we can later change those internal details without
/// breaking the tests.
///
private extension UIViewController {
    
    func numberOfFriends() -> Int? {
        listView()?.numberOfCells(inSection: friendsSection)
    }
    
    func cell(at row: Int) -> UIView? {
        listView()?.cell(at: IndexPath(row: row, section: friendsSection))
    }
    
    func selectFriend(at row: Int) throws {
        try XCTUnwrap(cell(at: row)).simulateTap()
    }
    
	func isShowingDetails(for friend: Friend) -> Bool {
		let vc = navigationController?.topViewController as? FriendDetailsViewController
		return vc?.friend == friend
	}
	
	var hasAddFriendButton: Bool {
		navigationItem.rightBarButtonItem?.systemItem == .add
	}
	
	var isPresentingAddFriendView: Bool {
		navigationController?.topViewController is AddFriendViewController
	}
	
	func tapAddFriendButton() {
		navigationItem.rightBarButtonItem?.simulateTap()
	}
 
    private var friendsSection: Int { 0 }
}
