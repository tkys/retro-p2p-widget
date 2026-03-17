import SwiftUI
import WidgetKit

struct SkinPickerView: View {
    @State private var skins: [SkinDefinition] = []
    @State private var selectedID: String = SkinLoader.selectedSkinID

    var body: some View {
        NavigationStack {
            List(skins) { skin in
                Button {
                    selectedID = skin.id
                    SkinLoader.selectedSkinID = skin.id
                    WidgetCenter.shared.reloadAllTimelines()
                } label: {
                    HStack(spacing: 16) {
                        // Mini preview
                        skinPreview(skin)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(skin.name)
                                .font(.headline)
                            Text(skin.clock.style.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if skin.id == selectedID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title2)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .tint(.primary)
            }
            .navigationTitle("Retro Clock Skins")
            .onAppear {
                skins = SkinLoader.loadAll()
            }
        }
    }

    private func skinPreview(_ skin: SkinDefinition) -> some View {
        let previewEntry = ClockEntry(date: .now, skin: skin)
        return RetroClockView(entry: previewEntry)
    }
}
