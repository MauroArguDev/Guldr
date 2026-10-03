//
//  ConfigurationTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 3/10/26.
//

import Foundation
import Testing
@testable import Guldr

struct ConfigurationTests {

    // The tests are hosted in Guldr.app, so Bundle.main is the app's bundle. A missing or
    // empty value means APP_GROUP_ID is not reaching Info.plist from Config/Shared.xcconfig.
    @Test func appGroupIDIsConfigured() {
        let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String
        #expect(appGroupID == "group.com.argudev.guldr")
    }

}
