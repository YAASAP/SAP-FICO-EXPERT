import SwiftUI

struct Favorite: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var url: URL
}

/// Favoris enregistrés uniquement sur l'appareil (UserDefaults).
final class FavoritesStore: ObservableObject {
    @Published private(set) var items: [Favorite] = []
    private let key = "fico.favorites.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Favorite].self, from: data) {
            items = decoded
        }
    }

    func contains(_ url: URL?) -> Bool {
        guard let url else { return false }
        return items.contains { $0.url == url }
    }

    func toggle(title: String, url: URL?) {
        guard let url else { return }
        if let index = items.firstIndex(where: { $0.url == url }) {
            items.remove(at: index)
        } else {
            let name = title.isEmpty ? (url.lastPathComponent.isEmpty ? "Fiche" : url.lastPathComponent) : title
            items.insert(Favorite(title: name, url: url), at: 0)
        }
        save()
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct FavoritesView: View {
    @ObservedObject var favorites: FavoritesStore
    var onOpen: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if favorites.items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "star")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Aucun favori")
                            .font(.headline)
                        Text("Ouvre une fiche et touche l'étoile pour la retrouver ici.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(favorites.items) { fav in
                            Button {
                                onOpen(fav.url)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fav.title).foregroundColor(.primary)
                                    Text(fav.url.absoluteString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .onDelete(perform: favorites.remove)
                    }
                }
            }
            .navigationTitle("Favoris")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
