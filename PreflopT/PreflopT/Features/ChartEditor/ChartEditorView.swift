//
//  ChartEditorView.swift
//  PreflopT
//
//  Tap or drag cells to paint them with the selected action; Save persists,
//  Cancel discards, Reset wipes everything (with confirmations).
//

import SwiftUI

struct ChartEditorView: View {

    @State private var viewModel: ChartEditorViewModel
    @Environment(\.colorPaletteStore) private var paletteStore
    @Environment(\.dismiss) private var dismiss

    @State private var showSaveConfirm = false
    @State private var showResetConfirm = false

    private var palette: ColorPalette { paletteStore.palette }

    init(scenario: Scenario, baseChart: Chart, overrideStore: ChartOverrideStore) {
        _viewModel = State(wrappedValue: ChartEditorViewModel(
            scenario: scenario,
            baseChart: baseChart,
            overrideStore: overrideStore
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusBar
                    .padding(.horizontal)

                grid
                    .padding(.horizontal)

                paletteRow
                    .padding(.horizontal)

                buttonRow
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Save changes?", isPresented: $showSaveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                viewModel.save()
                dismiss()
            }
        } message: {
            Text(saveAlertMessage)
        }
        .alert("Reset chart?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                viewModel.reset()
            }
        } message: {
            Text("This discards all your edits — including any that were already saved — and returns the chart to its bundled defaults.")
        }
    }

    // MARK: - Title

    private var title: String {
        let hero = viewModel.scenario.hero.rawValue
        switch viewModel.scenario.priorAction {
        case .firstToAct:
            return "Edit \(hero) RFI"
        case .facingOpen(let villain):
            return "Edit \(hero) vs \(villain.rawValue)"
        case .facingThreeBet:
            let suffix = viewModel.scenario.threeBettorGroupTitle ?? "vs 3-Bet"
            return "Edit \(hero) \(suffix)"
        case .facingFourBet(let villain):
            return "Edit \(hero) vs \(villain.rawValue) 4-Bet"
        }
    }

    // MARK: - Status

    private var statusBar: some View {
        HStack {
            if viewModel.modifiedCount > 0 {
                Label("\(viewModel.modifiedCount) edited", systemImage: "circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.accentColor)
            } else {
                Text("No edits yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Grid

    private var grid: some View {
        HandGridView(
            style: cellStyle,
            onCellActivated: { hand in viewModel.paint(hand) }
        )
    }

    private func cellStyle(for hand: HandClass) -> HandCellStyle {
        let action = viewModel.effectiveAction(for: hand)
        let modified = viewModel.isModified(hand)
        return HandCellStyle(
            fill: palette.color(for: action),
            foreground: palette.foreground(for: action),
            overlay: modified ? .edited : nil
        )
    }

    // MARK: - Palette row

    private var paletteRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paint with")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Array(viewModel.palette.enumerated()), id: \.offset) { index, option in
                    Button {
                        viewModel.selectedIndex = index
                    } label: {
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(palette.color(for: option.action))
                                .frame(width: 14, height: 14)
                            Text(option.label)
                                .font(.footnote.weight(.medium))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(viewModel.selectedIndex == index ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 4)
            }
        }
    }

    // MARK: - Buttons

    private var buttonRow: some View {
        HStack(spacing: 12) {
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            Button {
                showSaveConfirm = true
            } label: {
                Label("Save", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasUnsavedChanges)
        }
    }

    private var saveAlertMessage: String {
        let n = viewModel.modifiedCount
        return "Save \(n) edit\(n == 1 ? "" : "s") to this chart?"
    }
}

#Preview {
    let repo = (try? BundledChartRepository())!
    let scenario = Scenario(hero: .utg, priorAction: .facingThreeBet(from: .ip))
    let chart = repo.chart(for: scenario)!
    let store = ChartOverrideStore(
        directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("PreflopTPreview.\(UUID().uuidString)")
    )
    return NavigationStack {
        ChartEditorView(scenario: scenario, baseChart: chart, overrideStore: store)
    }
}
