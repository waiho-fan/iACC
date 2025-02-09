//	
// Copyright © Essential Developer. All rights reserved.
//

import XCTest
@testable import iACC

extension SceneDelegate {
	static var main: SceneDelegate {
        get throws {
            try XCTUnwrap(UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)
        }
	}
}
