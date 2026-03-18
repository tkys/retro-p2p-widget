import SwiftUI
import WidgetKit

struct DataSourceListView: View {
    @State private var sources: [DataSource] = []
    @State private var showingAdd = false
    @State private var editingSource: DataSource?

    var body: some View {
        List {
            if sources.isEmpty {
                ContentUnavailableView {
                    Label("No Data Sources", systemImage: "antenna.radiowaves.left.and.right")
                } description: {
                    Text("Add a URL to fetch and display custom data on your widget.")
                }
            }

            ForEach(sources) { source in
                Button {
                    editingSource = source
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.name)
                                .font(.headline)
                            Text(source.url.absoluteString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            HStack {
                                Text(source.zone.rawValue.uppercased())
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(zoneBadgeColor(source.zone).opacity(0.2))
                                    .clipShape(Capsule())
                                if let fmt = source.displayFormat, !fmt.isEmpty {
                                    Text(fmt)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
                .tint(.primary)
            }
            .onDelete { indexSet in
                sources.remove(atOffsets: indexSet)
                save()
            }
        }
        .navigationTitle("Data Sources")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                DataSourceEditView(source: nil) { newSource in
                    sources.append(newSource)
                    save()
                }
            }
        }
        .sheet(item: $editingSource) { source in
            NavigationStack {
                DataSourceEditView(source: source) { updated in
                    if let i = sources.firstIndex(where: { $0.id == updated.id }) {
                        sources[i] = updated
                        save()
                    }
                }
            }
        }
        .onAppear {
            sources = DataSource.loadAll()
        }
    }

    private func save() {
        DataSource.saveAll(sources)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func zoneBadgeColor(_ zone: DataSource.DisplayZone) -> Color {
        switch zone {
        case .marquee:  return .blue
        case .eq:       return .green
        case .playlist: return .purple
        }
    }
}

// MARK: - Edit / Add View

struct DataSourceEditView: View {
    let isNew: Bool
    let onSave: (DataSource) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var urlString: String
    @State private var jsonPath: String
    @State private var displayFormat: String
    @State private var zone: DataSource.DisplayZone
    @State private var testResult: String?
    @State private var isTesting = false

    init(source: DataSource?, onSave: @escaping (DataSource) -> Void) {
        self.isNew = source == nil
        self.onSave = onSave
        let s = source ?? DataSource(name: "", url: URL(string: "https://")!, zone: .playlist)
        _name = State(initialValue: s.name)
        _urlString = State(initialValue: s.url.absoluteString)
        _jsonPath = State(initialValue: s.jsonPath ?? "")
        _displayFormat = State(initialValue: s.displayFormat ?? "")
        _zone = State(initialValue: s.zone)
        _sourceID = State(initialValue: s.id)
    }

    @State private var sourceID: UUID

    var body: some View {
        Form {
            Section("Basic") {
                TextField("Name", text: $name, prompt: Text("e.g. Weather"))
                TextField("URL", text: $urlString, prompt: Text("https://api.example.com/data"))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Parsing") {
                TextField("JSON Path", text: $jsonPath, prompt: Text("$.data.value (optional)"))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Display Format", text: $displayFormat, prompt: Text("{value}°F (optional)"))
                    .textInputAutocapitalization(.never)
            }

            Section("Display Zone") {
                Picker("Zone", selection: $zone) {
                    ForEach(DataSource.DisplayZone.allCases, id: \.self) { z in
                        Text(zoneLabel(z)).tag(z)
                    }
                }
                .pickerStyle(.segmented)
                Text(zoneDescription(zone))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Test") {
                Button {
                    testFetch()
                } label: {
                    HStack {
                        Text("Test Fetch")
                        if isTesting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(URL(string: urlString) == nil || isTesting)

                if let testResult {
                    Text(testResult)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(testResult.hasPrefix("Error") ? .red : .green)
                }
            }
        }
        .navigationTitle(isNew ? "Add Data Source" : "Edit Data Source")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let url = URL(string: urlString) else { return }
                    let source = DataSource(
                        id: sourceID,
                        name: name.isEmpty ? "Untitled" : name,
                        url: url,
                        jsonPath: jsonPath.isEmpty ? nil : jsonPath,
                        displayFormat: displayFormat.isEmpty ? nil : displayFormat,
                        zone: zone
                    )
                    onSave(source)
                    dismiss()
                }
                .disabled(URL(string: urlString) == nil || name.isEmpty)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func testFetch() {
        guard let url = URL(string: urlString) else { return }
        isTesting = true
        testResult = nil

        let source = DataSource(
            name: name,
            url: url,
            jsonPath: jsonPath.isEmpty ? nil : jsonPath,
            displayFormat: displayFormat.isEmpty ? nil : displayFormat,
            zone: zone
        )

        Task {
            let result = await DataFetcher.fetchOne(source: source)
            await MainActor.run {
                isTesting = false
                testResult = result ?? "Error: No data returned"
            }
        }
    }

    private func zoneLabel(_ zone: DataSource.DisplayZone) -> String {
        switch zone {
        case .marquee:  return "Marquee"
        case .eq:       return "EQ"
        case .playlist: return "Playlist"
        }
    }

    private func zoneDescription(_ zone: DataSource.DisplayZone) -> String {
        switch zone {
        case .marquee:  return "Shows in the scrolling text area of the main window"
        case .eq:       return "Shows in the equalizer window area (systemLarge only)"
        case .playlist: return "Shows as track list in the playlist window (systemLarge only)"
        }
    }
}
