import SwiftUI

struct RecentItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var url: URL
    var date: Date
}

/// Dernières fiches consultées, enregistrées uniquement sur l'appareil (UserDefaults).
final class RecentsStore: ObservableObject {
    @Published private(set) var items: [RecentItem] = []
    private let key = "fico.recents.v1"
    private let limit = 50

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([RecentItem].self, from: data) {
            items = decoded
        }
    }

    func record(title: String, url: URL?) {
        guard let url, url != AppConfig.startURL else { return }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        items.removeAll { $0.url == url }
        items.insert(RecentItem(title: name, url: url, date: Date()), at: 0)
        if items.count > limit { items = Array(items.prefix(limit)) }
        save()
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    func clear() {
        items = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
