//
//  EditColorsView.swift
//  PreflopT
//
//  Form-based editor for the chart color palette. Ten rows, one per distinct
//  paintable chart action. Each row opens the system `ColorPicker`. Changes
//  apply immediately (the store persists after every mutation).
//

import SwiftUI

struct EditColorsView: View {
    @Environment(\.colorPaletteStore) private var store

    var body: some View {
        // `@Bindable` gives us `$store.palette.<keyPath>` bindings that drive
        // the individual `ColorPicker`s while keeping the store's didSet hook
        // in play (save-on-change).
        @Bindable var store = store

        Form {
            Section {
                row(label: "Fold",  binding: $store.palette.fold)
                row(label: "Call",  binding: $store.palette.call)
                row(label: "Open",  binding: $store.palette.open)
                row(label: "3-Bet", binding: $store.palette.threeBet)
                row(label: "4-Bet", binding: $store.palette.fourBet)
                row(label: "All-In", binding: $store.palette.fiveBet)
            } header: {
                Text("Pure actions")
            } footer: {
                Text("Each chart uses only one aggressive pure color (RFI uses Open; defense uses 3-Bet; vs-3-bet uses 4-Bet; vs-4-bet uses All-In). By default they all share the same red.")
            }

            Section {
                row(label: "3-Bet / Call", binding: $store.palette.threeBetCall)
                row(label: "3-Bet / Fold", binding: $store.palette.threeBetFold)
                row(label: "4-Bet / Call", binding: $store.palette.fourBetCall)
                row(label: "All-In / Call", binding: $store.palette.fiveBetCall)
            } header: {
                Text("Mixed actions")
            } footer: {
                Text("Mixed cells resolve to the aggressive leg when both hole cards are black, otherwise the passive leg. Default: all mixed share yellow.")
            }

            Section {
                Button(role: .destructive) {
                    store.resetAll()
                } label: {
                    Label("Reset to defaults", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("Edit Colors")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(label: String, binding: Binding<Color>) -> some View {
        ColorPicker(selection: binding, supportsOpacity: false) {
            Text(label)
        }
    }
}

#Preview {
    NavigationStack {
        EditColorsView()
    }
}
