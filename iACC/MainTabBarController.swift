//	
// Copyright © Essential Developer. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {
	
    private var friendsCache: FriendsCache!
    
    convenience init(friendCache: FriendsCache) {
		self.init(nibName: nil, bundle: nil)
        self.friendsCache = friendCache
		self.setupViewController()
	}

	private func setupViewController() {
		viewControllers = [
			makeNav(for: makeFriendsList(), title: "Friends", icon: "person.2.fill"),
			makeTransfersList(),
			makeNav(for: makeCardsList(), title: "Cards", icon: "creditcard.fill")
		]
	}
	
	private func makeNav(for vc: UIViewController, title: String, icon: String) -> UIViewController {
		vc.navigationItem.largeTitleDisplayMode = .always
		
		let nav = UINavigationController(rootViewController: vc)
		nav.tabBarItem.image = UIImage(
			systemName: icon,
			withConfiguration: UIImage.SymbolConfiguration(scale: .large)
		)
		nav.tabBarItem.title = title
		nav.navigationBar.prefersLargeTitles = true
		return nav
	}
	
	private func makeTransfersList() -> UIViewController {
		let sent = makeSentTransfersList()
		sent.navigationItem.title = "Sent"
		sent.navigationItem.largeTitleDisplayMode = .always
		
		let received = makeReceivedTransfersList()
		received.navigationItem.title = "Received"
		received.navigationItem.largeTitleDisplayMode = .always
		
		let vc = SegmentNavigationViewController(first: sent, second: received)
		vc.tabBarItem.image = UIImage(
			systemName: "arrow.left.arrow.right",
			withConfiguration: UIImage.SymbolConfiguration(scale: .large)
		)
		vc.title = "Transfers"
		vc.navigationBar.prefersLargeTitles = true
		return vc
	}
	
	private func makeFriendsList() -> ListViewController {
        let vc = ListViewController()
        
        vc.title = "Friends"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(addFriend))
        
        let isPremium = User.shared?.isPremium == true
        
        let api = FriendsAPIItemServiceAdapter(
            api: FriendsAPI.shared,
            cache: isPremium ? friendsCache : NullFriendsCache(),   // Null Object Pattern
            select: { [weak vc] item in
                vc?.select(friend: item)
            }
        ).retry(2)
        
        let cache = FriendsCacheAPIItemServiceAdapter(
            cache: friendsCache,
            select: { [weak vc] item in
                vc?.select(friend: item)
            })
        
        vc.service = isPremium ? api.fallback(cache) : api
        
		return vc
	}
	
	private func makeSentTransfersList() -> ListViewController {
		let vc = ListViewController()
        
        vc.navigationItem.title = "Sent"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: vc, action: #selector(sendMoney))
        
        vc.service = SentTransfersAPIItemServiceAdapter(
            api: TransfersAPI.shared,
            select: { [weak vc] item in
                vc?.select(transfer: item)
            }).retry(1)
		return vc
	}
	
	private func makeReceivedTransfersList() -> ListViewController {
		let vc = ListViewController()
        
        vc.navigationItem.title = "Received"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Request", style: .done, target: vc, action: #selector(requestMoney))
        
        vc.service = ReceivedTransfersAPIItemServiceAdapter(
            api: TransfersAPI.shared,
            select: { [weak vc] item in
                vc?.select(transfer: item)
            }
        ).retry(1)
        
		return vc
	}
	
	private func makeCardsList() -> ListViewController {
		let vc = ListViewController()
        vc.title = "Cards"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(addCard))
        
        vc.service = CardAPIItemServiceAdapter(
            api: CardAPI.shared,
            select: { [weak vc] item in
                vc?.select(card: item)
            })
		return vc
	}
	
}

extension ItemsService {
    func fallback(_ fallback: ItemsService) -> ItemsService {
        ItemsServiceWithFallback(primary: self, fallback: fallback)
    }
    
    func retry(_ retryCount: UInt) -> ItemsService {
        var service: ItemsService = self
        for _ in 0..<retryCount {
            service = service.fallback(self)
        }
        return service
    }
}

struct ItemsServiceWithFallback: ItemsService {
    let primary: ItemsService
    let fallback: ItemsService
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], any Error>) -> Void) {
        primary.loadItems { result in
            switch result {
            case .success:
                completion(result)
            case .failure:
                fallback.loadItems(completion: completion)
            }
        }
    }
}

// Issue: Higher level components (FriendAPI) should not depend on lower level details (ListViewController)
// Soultion: D - Dependency Inversion Principle (依賴反轉原則)
// >> Create a component (Adapter) in the middle to bridge and adapt their communication
// >> To keep these two modules decoupled
struct FriendsAPIItemServiceAdapter: ItemsService {
    let api: FriendsAPI
    let cache: FriendsCache
    let select: (Friend) -> Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadFriends { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { items in
                    cache.save(items)
                    
                    return items.map { item in
                        ItemViewModel(friend: item, selection: {
                            select(item)
                        })
                    }
                })
            }
        }
    }
}

struct FriendsCacheAPIItemServiceAdapter: ItemsService {
    let cache: FriendsCache
    let select: (Friend) -> Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        cache.loadFriends { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { items in
                    items.map { item in
                        ItemViewModel(friend: item, selection: {
                            select(item)
                        })
                    }
                })
            }
        }
    }
}

// Null Object Pattern: same interface, but you override the methods or implement the methods and do nothing
class NullFriendsCache: FriendsCache {
    override func save(_ newFriends: [Friend]) {}
}

struct CardAPIItemServiceAdapter: ItemsService {
    let api: CardAPI
    let select: (Card) -> Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadCards { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { items in
                    items.map { item in
                        ItemViewModel(card: item , selection: {
                            select(item)
                        })
                    }
                })
            }
        }
    }
}

struct SentTransfersAPIItemServiceAdapter: ItemsService {
    let api: TransfersAPI
    let select: (Transfer) -> Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadTransfers { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { items in
                    items
                        .filter { $0.isSender }
                        .map { item in
                            ItemViewModel(
                                transfer: item,
                                longDateStyle: true,
                                selection: {
                                    select(item)
                                })
                        }
                })
            }
        }
    }
}

struct ReceivedTransfersAPIItemServiceAdapter: ItemsService {
    let api: TransfersAPI
    let select: (Transfer) -> Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadTransfers { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { items in
                    items
                        .filter { !$0.isSender }
                        .map { item in
                            ItemViewModel(
                                transfer: item,
                                longDateStyle: false,
                                selection: {
                                    select(item)
                                })
                        }
                })
            }
        }
    }
}
