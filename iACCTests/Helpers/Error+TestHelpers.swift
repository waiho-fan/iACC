//	
// Copyright © Essential Developer. All rights reserved.
//

import Foundation

struct Timeout: Error {}

func anError() -> Error {
	NSError(localizedDescription: "any error message")
}

extension NSError {
	convenience init(localizedDescription: String) {
		self.init(domain: "Test", code: 0, userInfo: [NSLocalizedDescriptionKey: localizedDescription])
	}
}
