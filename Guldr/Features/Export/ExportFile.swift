//
//  ExportFile.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 21/10/26.
//

import CoreTransferable
import Foundation
import GuldrCore
import UniformTypeIdentifiers

/// The CSV that `ShareLink` hands over. The text is built only when the user picks a destination, off
/// the main actor (`CSVExporter.data(for:)`), and written to a temporary file named
/// `Guldr-YYYY-MM-DD.csv`, so the receiving app sees that name.
nonisolated struct ExportFile: Transferable, Equatable {

    let rows: [CSVExporter.Row]
    let timeZone: TimeZone
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let url = FileManager.default.temporaryDirectory.appending(path: file.name)
            try await CSVExporter.data(for: file.rows, timeZone: file.timeZone).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
