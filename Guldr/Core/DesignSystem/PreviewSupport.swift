//
//  PreviewSupport.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

#if DEBUG
import GuldrCore

extension Money {
    /// Previews only, compiled out of release builds. USD is a valid ISO 4217 code, so this cannot fail.
    static func previewUSD(_ cents: Int64) -> Money {
        // swiftlint:disable:next force_try
        try! Money(minorUnits: cents, currencyCode: "USD") // Valid code, debug-only previews.
    }
}
#endif
