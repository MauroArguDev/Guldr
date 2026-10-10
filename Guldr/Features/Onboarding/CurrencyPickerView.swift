//
//  CurrencyPickerView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import GuldrCore
import SwiftUI

/// Every currency the system knows, searchable by name, code or symbol. The region's currency is listed
/// first so most people find theirs without searching. No mockup: a native list (DESIGN.md › Principles).
struct CurrencyPickerView: View {

    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let options = CurrencyOption.all()
    private let regionCode = Locale.autoupdatingCurrent.currency?.identifier

    var body: some View {
        List {
            if query.isEmpty, let regionOption = options.first(where: { $0.code == regionCode }) {
                Section("Your region") {
                    row(for: regionOption)
                }
            }
            if !results.isEmpty {
                Section(query.isEmpty ? "All currencies" : "Results") {
                    ForEach(results) { option in
                        row(for: option)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.appBackground))
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .overlay {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private var results: [CurrencyOption] {
        options.filter { $0.matches(query) }
    }

    private func row(for option: CurrencyOption) -> some View {
        Button {
            selection = option.code
            dismiss()
        } label: {
            HStack(spacing: Spacing.rowGap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: option.name)
                        .foregroundStyle(Color(.textPrimary))
                    Text(verbatim: option.code)
                        .textRole(.meta)
                        .foregroundStyle(Color(.textSecondary))
                }
                Spacer()
                // Currencies without a symbol of their own show their code, which is already listed.
                if option.symbol != option.code {
                    Text(verbatim: option.symbol)
                        .foregroundStyle(Color(.textSecondary))
                }
                if option.code == selection {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(.gold))
                }
            }
            .contentShape(.rect)
        }
        .listRowBackground(Color(.surface))
        .accessibilityAddTraits(option.code == selection ? .isSelected : [])
    }
}

#Preview("Light") {
    @Previewable @State var selection = "EUR"
    NavigationStack {
        CurrencyPickerView(selection: $selection)
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    @Previewable @State var selection = "USD"
    NavigationStack {
        CurrencyPickerView(selection: $selection)
    }
    .preferredColorScheme(.dark)
}
