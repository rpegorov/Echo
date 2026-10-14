//
//  ArrangementMessageLine.swift
//  Echo
//

import SwiftUI

/// A warning icon with a wrapped secondary-colour message.
struct ArrangementMessageLine: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Arrangements.rowSpacing) {
            Image(systemName: DS.Arrangements.messageIcon)
                .foregroundStyle(DS.Arrangements.noticeColor)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Arrangements.detailFont)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
