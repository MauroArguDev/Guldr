//
//  DayCalendar.swift
//  Guldr
//
//  Created by Mauricio Argumedo on 15/11/26.
//

import SwiftUI
import UIKit

/// The add sheet's calendar, which closes once a day is picked. SwiftUI's graphical `DatePicker` reports a month
/// chosen in its month and year wheel as a new date, the same as a tapped day, so it can't tell when to close.
/// `UICalendarView` only reports tapped days: moving between months never changes the selection.
struct DayCalendar: UIViewRepresentable {

    /// Its day changes to the picked one; the time of day stays, as the `DatePicker` kept it.
    @Binding var date: Date
    /// The last day that can be picked.
    let latest: Date
    let onPick: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICalendarView {
        let calendar = context.environment.calendar
        context.coordinator.calendar = calendar
        let view = UICalendarView()
        view.calendar = calendar
        view.locale = context.environment.locale
        view.tintColor = UIColor(resource: .gold)
        view.availableDateRange = DateInterval(start: .distantPast, end: latest)
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.selectedDate = day
        view.selectionBehavior = selection
        view.visibleDateComponents = day
        return view
    }

    func updateUIView(_ view: UICalendarView, context: Context) {
        context.coordinator.parent = self
    }

    /// As wide as offered and as tall as the calendar needs at that width.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView view: UICalendarView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let fitting = view.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                                                   withHorizontalFittingPriority: .required,
                                                   verticalFittingPriority: .fittingSizeLevel)
        return CGSize(width: width, height: fitting.height)
    }

    final class Coordinator: NSObject, UICalendarSelectionSingleDateDelegate {

        var parent: DayCalendar
        /// The calendar the view shows, which the picked day's components belong to.
        var calendar = Calendar.current

        init(parent: DayCalendar) {
            self.parent = parent
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents else { return }
            var picked = dateComponents
            let time = calendar.dateComponents([.hour, .minute, .second], from: parent.date)
            (picked.hour, picked.minute, picked.second) = (time.hour, time.minute, time.second)
            guard let date = calendar.date(from: picked) else { return }
            parent.date = date
            parent.onPick()
        }
    }
}

// MARK: - Previews

#Preview("Light") {
    @Previewable @State var date = Date.now
    DayCalendar(date: $date, latest: .now) {}
        .frame(width: 320)
        .padding()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    @Previewable @State var date = Date.now
    DayCalendar(date: $date, latest: .now) {}
        .frame(width: 320)
        .padding()
        .preferredColorScheme(.dark)
}
