//
//  ExportView.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import GuldrCore
import SwiftData
import SwiftUI

/// Settings › Export transactions. No mockup: a native `Form` (DESIGN.md › Principles). All time or a
/// range of days, how many transactions that includes, and a `ShareLink` with the CSV (author's call,
/// 2026-10-21). Every currency goes in; the file says which one each amount is in.
struct ExportView: View {

    @Query private var transactions: [Transaction]
    @State private var model = ExportModel()

    var body: some View {
        Form {
            Section {
                Picker("Transactions", selection: $model.range) {
                    Text("All time").tag(ExportModel.Range.allTime)
                    Text("Date range").tag(ExportModel.Range.dates)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .sensoryFeedback(Haptics.selection, trigger: model.range)

                if model.range == .dates {
                    DatePicker("From", selection: $model.startDay, displayedComponents: .date)
                    DatePicker("To", selection: $model.endDay, displayedComponents: .date)
                }
            } footer: {
                if model.file == nil {
                    Text("No transactions in this range.")
                } else {
                    Text("^[\(model.includedCount) transaction](inflect: true) will be exported.")
                }
            }

            Section {
                if let file = model.file {
                    ShareLink(item: file, preview: SharePreview(Text(verbatim: file.name),
                                                               image: Image(systemName: "tablecells"))) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .tint(Color(.gold))
                } else {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                        .foregroundStyle(Color(.textSecondary))
                }
            } footer: {
                Text("One row per transaction: date and time, title, category, type, amount and currency. Expenses are negative.")
            }
        }
        .tint(Color(.goldFill))
        .scrollContentBackground(.hidden)
        .background(Color(.appBackground))
        .navigationTitle(Text("Export"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: transactions, initial: true) { model.update(transactions: transactions) }
    }
}

// Previews use debug-only helpers (PreviewSupport.swift), so they are compiled out of release builds.
#if DEBUG
#Preview("Light") {
    PreviewEnvironment { NavigationStack { ExportView() } }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PreviewEnvironment { NavigationStack { ExportView() } }
        .preferredColorScheme(.dark)
}
#endif
