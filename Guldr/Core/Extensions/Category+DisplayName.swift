//
//  Category+DisplayName.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 15/10/26.
//

import Foundation
import GuldrCore

extension Category {

    /// The name to show. Seeded categories keep their English name in the store and are translated
    /// through the String Catalog until the user renames them; custom names are shown as typed.
    var displayName: String {
        guard usesDefaultName else { return name }
        // A runtime key: Xcode cannot extract it, so the seeded names are added to the catalog by hand.
        return String(localized: String.LocalizationValue(name))
    }
}
