//
//  GuldrCoreTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 4/10/26.
//

import Testing
@testable import GuldrCore

struct GuldrCoreTests {

    @Test func moduleIsAvailable() {
        #expect(GuldrCore.moduleName == "GuldrCore")
    }

}
