//	
// Copyright © Essential Developer. All rights reserved.
//

import Foundation
@testable import iACC

///
/// This test helper method provides a way of creating `Friend` models without coupling the
/// tests with the `Friend` initializer. This way, we can change the `Friend` dependencies
/// and initializer without breaking tests (we just need to update the helper method).
///
func aFriend(id: UUID = UUID(), name: String = "any name \(UUID())", phone: String = "any phone \(UUID())") -> Friend {
	Friend(id: id, name: name, phone: phone)
}
