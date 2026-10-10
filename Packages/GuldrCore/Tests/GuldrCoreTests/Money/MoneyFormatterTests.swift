//
//  MoneyFormatterTests.swift
//  GuldrCoreTests
//
//  Created by Mauricio Argumedo on 8/10/26.
//

import Foundation
import Testing
@testable import GuldrCore

struct MoneyFormatterTests {

    private let enUS = MoneyFormatter(locale: Locale(identifier: "en_US"))
    private let esMX = MoneyFormatter(locale: Locale(identifier: "es_MX"))
    private let esES = MoneyFormatter(locale: Locale(identifier: "es_ES"))
    private let minus = MoneyFormatter.minusSign

    private func money(_ minorUnits: Int64, _ code: String = "USD") throws -> Money {
        try Money(minorUnits: minorUnits, currencyCode: code)
    }

    /// ICU uses non-breaking and narrow spaces that can differ between OS versions; compare them as spaces.
    private func normalized(_ text: String) -> String {
        text.replacing(/[\u{00A0}\u{202F}\u{2009}]/, with: " ")
    }

    @Test func formatsInEnglish() throws {
        #expect(enUS.string(from: try money(123_450)) == "$1,234.50")
        #expect(enUS.string(from: try money(0)) == "$0.00")
        #expect(enUS.string(from: try money(150_000, "JPY")) == "¥150,000")
    }

    @Test func formatsInSpanish() throws {
        #expect(esMX.string(from: try money(123_450, "MXN")) == "$1,234.50")
        #expect(normalized(esES.string(from: try money(1_234_567, "EUR"))) == "12.345,67 €")
    }

    @Test func signsFollowTheDesignSystem() throws {
        #expect(enUS.string(from: try money(500_000), sign: .plus) == "+$5,000.00")
        #expect(enUS.string(from: try money(4280), sign: .minus) == "\(minus)$42.80")
        #expect(enUS.string(from: try money(-175_950)) == "\(minus)$1,759.50")
        #expect(enUS.string(from: try money(-175_950), sign: .never) == "$1,759.50")
        #expect(normalized(esES.string(from: try money(-4280, "EUR"))) == "\(minus)42,80 €")
    }

    @Test func zeroNeverGetsASign() throws {
        #expect(enUS.string(from: try money(0), sign: .plus) == "$0.00")
        #expect(enUS.string(from: try money(0), sign: .minus) == "$0.00")
    }

    @Test func minusIsTheTrueMinusSign() throws {
        let text = enUS.string(from: try money(-100))
        #expect(text.hasPrefix("\u{2212}"))
        #expect(!text.contains("-"))
    }

    @Test func partsSplitCentsForTheSerifBalance() throws {
        #expect(enUS.parts(from: try money(1_245_080)) == .init(main: "$12,450", fraction: ".80"))
        #expect(enUS.parts(from: try money(-1_245_080)) == .init(main: "\(minus)$12,450", fraction: ".80"))

        let euros = esES.parts(from: try money(1_245_080, "EUR"))
        #expect(euros.main == "12.450")
        #expect(normalized(euros.fraction ?? "") == ",80 €")
    }

    @Test func partsHaveNoFractionForCurrenciesWithoutMinorUnits() throws {
        #expect(enUS.parts(from: try money(150_000, "JPY")) == .init(main: "¥150,000", fraction: nil))
    }

    @Test func wholeUnitsRoundHalfAwayFromZeroLikeTheMockups() throws {
        #expect(enUS.string(from: try money(1_287_450), precision: .wholeUnits) == "$12,875")   // Charts "Expenses"
        #expect(enUS.string(from: try money(175_950), precision: .wholeUnits) == "$1,760")      // donut center
        #expect(enUS.string(from: try money(1_248_025), precision: .wholeUnits) == "$12,480")   // widget
        #expect(enUS.string(from: try money(58_700), precision: .wholeUnits) == "$587")         // budget ring
        #expect(enUS.string(from: try money(-175_950), precision: .wholeUnits) == "\(minus)$1,760")
        #expect(normalized(esES.string(from: try money(1_234_567, "EUR"), precision: .wholeUnits)) == "12.346 €")
    }

    @Test func wholeUnitsThatRoundToZeroHaveNoSign() throws {
        #expect(enUS.string(from: try money(-40), precision: .wholeUnits) == "$0")
        #expect(enUS.string(from: try money(40), sign: .plus, precision: .wholeUnits) == "$0")
        #expect(enUS.string(from: try money(50), sign: .plus, precision: .wholeUnits) == "+$1")
    }

    @Test func wholeUnitsLeaveCurrenciesWithoutMinorUnitsAlone() throws {
        #expect(enUS.string(from: try money(150_000, "JPY"), precision: .wholeUnits) == "¥150,000")
    }

    @Test func threeDecimalCurrencies() throws {
        #expect(normalized(enUS.string(from: try money(1234, "KWD"))).hasSuffix("1.234"))
    }
}
