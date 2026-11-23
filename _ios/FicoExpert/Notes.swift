import SwiftUI

struct NoteItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var url: URL
    var text: String
    var updated: Date
}

/// Notes personnelles attachées à une fiche, enregistrées uniquement sur l'appareil.
final class NotesStore: ObservableObject {
    @Published private(set) var items: [NoteItem] = []
    private let key = "fico.notes.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([NoteItem].self, from: data) {
            items = decoded
        }
    }

    func note(for url: URL?) -> NoteItem? {
        guard let url else { return nil }
        return items.first { $0.url == url }
    }

    func hasNote(for url: URL?) -> Bool { note(for: url) != nil }

    /// Enregistre la note ; un texte vide supprime la note.
    func save(text: String, title: String, url: URL) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        items.removeAll { $0.url == url }
        if !trimmed.isEmpty {
            let name = title.isEmpty ? (url.lastPathComponent.isEmpty ? L("Fiche") : url.lastPathComponent) : title
            items.insert(NoteItem(title: name, url: url, text: trimmed, updated: Date()), at: 0)
        }
        persist()
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct NoteEditorView: View {
    @ObservedObject var notes: NotesStore
    let title: String
    let url: URL
    @State private var text: String
    @Environment(\.dismiss) private var dismiss

    init(notes: NotesStore, title: String, url: URL) {
        self.notes = notes
        self.title = title
        self.url = url
        _text = State(initialValue: notes.note(for: url)?.text ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title.isEmpty ? url.absoluteString : title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal)
                TextEditor(text: $text)
                    .padding(.horizontal, 12)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Ton mémo : paramétrage testé, numéro de pièce, point à vérifier…")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 17)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }
                Text("Cette note reste uniquement sur ton iPhone.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .navigationTitle("Ma note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        notes.save(text: text, title: title, url: url)
                        dismiss()
                    }
                }
            }
        }
    }
}
