//
//  EditRFIColorsView.swift
//  PreflopT
//
//  Editor for the unified RFI chart's ring colors. Uses its own
//  `RFIColorPaletteStore`, isolated from the main chart palette editor.
//

import SwiftUI

struct EditRFIColorsView: View {
    @Environment(\.rfiColorPaletteStore) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                row(label: "UTG",    binding: $store.palette.utg)
                row(label: "MP",     binding: $store.palette.mp)
                row(label: "CO",     binding: $store.palette.co)
                row(label: "BTN/SB", binding: $store.palette.btnSb)
                row(label: "Fold",   binding: $store.palette.fold)
            } header: {
                Text("RFI ring colors")
            } footer: {
                Text("Only applies to the unified RFI chart. The main Edit Colors screen does not affect these.")
            }

            Section {
                Button(role: .destructive) {
                    store.resetAll()
                } label: {
                    Label("Reset to defaults", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("Edit RFI Colors")
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
        EditRFIColorsView()
    }
}
