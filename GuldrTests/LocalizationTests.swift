//
//  LocalizationTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 22/10/26.
//

import Foundation
import GuldrCore
import Testing
@testable import Guldr

/// The Spanish strings as the built app ships them: read from the app bundle's `es.lproj`, whatever
/// language the simulator runs in.
struct LocalizationTests {

    /// Seeded names are runtime keys Xcode can't extract (`Category.displayName`); a missing entry would
    /// show the English name in a Spanish app.
    @Test func everyDefaultCategoryHasASpanishName() throws {
        let spanish = try Self.spanishBundle()
        let names = DefaultCategory.all.map { spanish.localizedString(forKey: $0.name, value: nil, table: nil) }
        #expect(names == ["Comida", "Transporte", "Vivienda", "Salud", "Compras", "Entretenimiento", "Educación",
                          "Otros", "Salario", "Freelance", "Otros ingresos"])
    }

    /// Counts use plural variations, including the export footer that English inflects automatically.
    @Test func countsAgreeWithTheirNumber() throws {
        let spanish = try Self.spanishBundle()
        func text(_ key: String, _ count: Int) -> String {
            String(format: spanish.localizedString(forKey: key, value: nil, table: nil),
                   locale: Locale(identifier: "es"), count)
        }
        #expect(text("%lld days left", 1) == "1 día restante")
        #expect(text("%lld days left", 12) == "12 días restantes")
        #expect(text("%lld categories over budget", 1) == "1 categoría excedida")
        #expect(text("%lld categories over budget", 3) == "3 categorías excedidas")
        #expect(text("^[%lld transaction](inflect: true) will be exported.", 1) == "Se exportará 1 movimiento.")
        #expect(text("^[%lld transaction](inflect: true) will be exported.", 40) == "Se exportarán 40 movimientos.")
    }

    @Test func theIncomeKindIsSingularAndTheTotalsPlural() throws {
        let spanish = try Self.spanishBundle()
        #expect(spanish.localizedString(forKey: "transaction.kind.income", value: nil, table: nil) == "Ingreso")
        #expect(spanish.localizedString(forKey: "Income", value: nil, table: nil) == "Ingresos")
    }

    private static func spanishBundle() throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: "es", ofType: "lproj"))
        return try #require(Bundle(path: path))
    }
}
