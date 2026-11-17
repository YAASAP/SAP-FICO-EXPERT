import SwiftUI

/// Bibliothèque personnelle : favoris, fiches consultées récemment et notes.
struct LibraryView: View {
    enum LibSection: String, CaseIterable, Identifiable {
        case favorites = "Favoris"
        case recents = "Récents"
        case notes = "Notes"
        var id: String { rawValue }
    }

    @ObservedObject var favorites: FavoritesStore
    @ObservedObject var recents: RecentsStore
    @ObservedObject var notes: NotesStore
    var onOpen: (URL) -> Void

    @State private var section: LibSection = .favorites
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(LibSection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                switch section {
                case .favorites: favoritesList
                case .recents: recentsList
                case .notes: notesList
                }
            }
            .navigationTitle("Ma bibliothèque")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vider") { recents.clear() }
                        .disabled(section != .recents || recents.items.isEmpty)
                        .opacity(section == .recents ? 1 : 0)
                }
            }
        }
    }

    private func open(_ url: URL) {
        onOpen(url)
        dismiss()
    }

    private func empty(_ symbol: String, _ title: String, _ hint: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: symbol).font(.largeTitle).foregroundColor(.secondary)
            Text(title).font(.headline)
            Text(hint)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var favoritesList: some View {
        if favorites.items.isEmpty {
            empty("star", "Aucun favori", "Ouvre une fiche et touche l'étoile pour la retrouver ici.")
        } else {
            List {
                ForEach(favorites.items) { fav in
                    Button { open(fav.url) } label: {
                        Text(fav.title).foregroundColor(.primary)
                    }
                }
                .onDelete(perform: favorites.remove)
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder private var recentsList: some View {
        if recents.items.isEmpty {
            empty("clock", "Aucune fiche consultée", "Les fiches que tu ouvres apparaissent ici pour les retrouver vite.")
        } else {
            List {
                ForEach(recents.items) { item in
                    Button { open(item.url) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).foregroundColor(.primary)
                            Text(item.date, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: recents.remove)
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder private var notesList: some View {
        if notes.items.isEmpty {
            empty("note.text", "Aucune note", "Ouvre une fiche et touche l'icône note pour écrire ton propre mémo.")
        } else {
            List {
                ForEach(notes.items) { note in
                    Button { open(note.url) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(note.title).font(.headline).foregroundColor(.primary)
                            Text(note.text)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
                .onDelete(perform: notes.remove)
            }
            .listStyle(.plain)
        }
    }
}
