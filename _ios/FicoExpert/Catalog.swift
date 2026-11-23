import SwiftUI
import WebKit
import CoreSpotlight

/// Une entrée du catalogue embarqué dans l'app (catalogue.json) : consultable hors ligne.
struct CatalogEntry: Identifiable, Codable, Hashable {
    let id: String
    let module: String
    let code: String
    let title: String
    let summary: String
    let whereText: String
    let teaser: String

    enum CodingKeys: String, CodingKey {
        case id, module, code, title, summary, teaser
        case whereText = "where"
    }

    var isTip: Bool { module.hasPrefix("Tip") }
    var heading: String { code.isEmpty ? title : "\(code) · \(title)" }
}

/// Catalogue natif + favoris, notes et fiches enregistrées pour la lecture hors ligne.
/// Tout reste sur l'appareil (UserDefaults et dossier de l'app).
final class CatalogStore: ObservableObject {
    let entries: [CatalogEntry]
    @Published private(set) var favoriteIDs: Set<String>
    @Published private(set) var notes: [String: String]

    private let favKey = "fico.catalog.favs.v1"
    private let noteKey = "fico.catalog.notes.v1"

    init() {
        if let url = Bundle.main.url(forResource: appUsesFrench ? "catalogue" : "catalogue_en", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([CatalogEntry].self, from: data) {
            entries = list
        } else {
            entries = []
        }
        favoriteIDs = Set(UserDefaults.standard.stringArray(forKey: favKey) ?? [])
        notes = (UserDefaults.standard.dictionary(forKey: noteKey) as? [String: String]) ?? [:]
        indexInSpotlight()
    }

    /// Rend les fiches trouvables depuis la recherche iOS (Spotlight), sur l'appareil uniquement.
    private func indexInSpotlight() {
        let items = entries.map { entry -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: .content)
            attrs.title = entry.heading
            attrs.contentDescription = entry.summary
            attrs.keywords = [entry.code, entry.module, "SAP", "FICO"].filter { !$0.isEmpty }
            return CSSearchableItem(uniqueIdentifier: entry.id, domainIdentifier: "com.yaasap.sapfico.fiches", attributeSet: attrs)
        }
        guard !items.isEmpty else { return }
        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: ["com.yaasap.sapfico.fiches"]) { _ in
            index.indexSearchableItems(items) { _ in }
        }
    }

    var modules: [String] {
        var seen = [String]()
        for entry in entries where !entry.isTip && !seen.contains(entry.module) { seen.append(entry.module) }
        return seen
    }

    func isFavorite(_ id: String) -> Bool { favoriteIDs.contains(id) }

    func toggleFavorite(_ id: String) {
        if favoriteIDs.contains(id) { favoriteIDs.remove(id) } else { favoriteIDs.insert(id) }
        UserDefaults.standard.set(Array(favoriteIDs), forKey: favKey)
    }

    func note(for id: String) -> String { notes[id] ?? "" }

    func setNote(_ text: String, for id: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { notes.removeValue(forKey: id) } else { notes[id] = trimmed }
        UserDefaults.standard.set(notes, forKey: noteKey)
    }

    // MARK: Lecture hors ligne

    private var cacheFolder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("fiches", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func cacheURL(_ id: String) -> URL {
        let safe = id.replacingOccurrences(of: "/", with: "_")
        return cacheFolder.appendingPathComponent(safe + ".html")
    }

    func cachedHTML(_ id: String) -> String? {
        try? String(contentsOf: cacheURL(id), encoding: .utf8)
    }

    func saveHTML(_ html: String, for id: String) {
        try? html.write(to: cacheURL(id), atomically: true, encoding: .utf8)
        objectWillChange.send()
    }

    func isSavedOffline(_ id: String) -> Bool {
        FileManager.default.fileExists(atPath: cacheURL(id).path)
    }
}

struct CatalogView: View {
    @ObservedObject var catalog: CatalogStore
    @ObservedObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    let showsClose: Bool
    @State private var query: String
    @State private var filter: String

    init(catalog: CatalogStore, storeManager: StoreManager, initialFilter: String = L("Tous"), initialQuery: String = "", showsClose: Bool = true) {
        self.showsClose = showsClose
        self.catalog = catalog
        self.storeManager = storeManager
        _filter = State(initialValue: initialFilter)
        _query = State(initialValue: initialQuery)
    }

    private let tipsFilter = L("Tips & pièges")
    private let favFilter = L("Favoris")

    private var filters: [String] { [L("Tous"), favFilter] + catalog.modules + [tipsFilter] }

    private var results: [CatalogEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return catalog.entries.filter { entry in
            switch filter {
            case L("Tous"): break
            case favFilter: if !catalog.isFavorite(entry.id) { return false }
            case tipsFilter: if !entry.isTip { return false }
            default: if entry.module != filter { return false }
            }
            if q.isEmpty { return true }
            return entry.title.lowercased().contains(q)
                || entry.code.lowercased().contains(q)
                || entry.summary.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { name in
                            Button { filter = name } label: {
                                Text(name)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(filter == name ? Color.accentColor : Color.secondary.opacity(0.18))
                                    .foregroundColor(filter == name ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if results.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "magnifyingglass").font(.largeTitle).foregroundColor(.secondary)
                        Text("Aucune fiche").font(.headline)
                        Text("Essaie un autre mot (ex. FB60, fournisseur, GR/IR).")
                            .font(.subheadline).foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(results) { entry in
                        NavigationLink {
                            FicheDetailView(entry: entry, catalog: catalog, storeManager: storeManager)
                        } label: {
                            row(entry)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Catalogue")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Transaction, mot-clé…")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if showsClose { Button("Fermer") { dismiss() } }
                }
            }
        }
    }

    private func row(_ entry: CatalogEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(entry.heading).font(.headline).lineLimit(2)
                Spacer(minLength: 4)
                if catalog.note(for: entry.id).isEmpty == false {
                    Image(systemName: "note.text").foregroundColor(.secondary)
                }
                if catalog.isSavedOffline(entry.id) {
                    Image(systemName: "arrow.down.circle.fill").foregroundColor(.green)
                }
                if catalog.isFavorite(entry.id) {
                    Image(systemName: "star.fill").foregroundColor(.yellow)
                }
            }
            Text(entry.module).font(.caption.weight(.semibold)).foregroundColor(.accentColor)
            Text(entry.summary).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

struct FicheDetailView: View {
    let entry: CatalogEntry
    @ObservedObject var catalog: CatalogStore
    @ObservedObject var storeManager: StoreManager

    @State private var html: String?
    @State private var loading = false
    @State private var failed = false
    @State private var showNote = false
    @State private var showPaywall = false
    @State private var noteText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.module).font(.caption.weight(.semibold)).foregroundColor(.accentColor)
                Text(entry.summary).font(.subheadline)
                if !entry.whereText.isEmpty {
                    Text(entry.whereText).font(.footnote).foregroundColor(.secondary)
                }
                if catalog.note(for: entry.id).isEmpty == false {
                    Label(catalog.note(for: entry.id), systemImage: "note.text")
                        .font(.footnote)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.yellow.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()

            Divider()

            if let html {
                FicheHTMLView(html: html)
            } else if loading {
                VStack { Spacer(); ProgressView(); Spacer() }.frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: storeManager.isPremium ? "wifi.slash" : "lock")
                        .font(.largeTitle).foregroundColor(.secondary)
                    if storeManager.isPremium {
                        Text(failed ? L("Fiche indisponible pour le moment. Vérifie ta connexion : une fois ouverte, elle reste lisible hors ligne.")
                                    : L("Chargement…"))
                            .font(.subheadline).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Réessayer") { Task { await load() } }
                            .buttonStyle(.bordered)
                    } else {
                        Text(entry.teaser.isEmpty ? L("La fiche complète est incluse avec Premium.") : entry.teaser)
                            .font(.subheadline).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Débloquer Premium") { showPaywall = true }
                            .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(entry.heading)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ShareLink(item: "\(entry.heading)\n\(entry.summary)\nhttps://yaasap.github.io/SAP-FICO-EXPERT/") {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Partager")
                Button {
                    noteText = catalog.note(for: entry.id)
                    showNote = true
                } label: {
                    Image(systemName: catalog.note(for: entry.id).isEmpty ? "square.and.pencil" : "note.text")
                }
                .accessibilityLabel("Ma note")
                Button { catalog.toggleFavorite(entry.id) } label: {
                    Image(systemName: catalog.isFavorite(entry.id) ? "star.fill" : "star")
                }
                .accessibilityLabel("Favori")
            }
        }
        .sheet(isPresented: $showNote) {
            NavigationStack {
                TextEditor(text: $noteText)
                    .padding(12)
                    .navigationTitle("Ma note")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Annuler") { showNote = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Enregistrer") {
                                catalog.setNote(noteText, for: entry.id)
                                showNote = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView(store: storeManager) }
        .task { await load() }
        .onChange(of: storeManager.isPremium) { _ in Task { await load() } }
    }

    @MainActor private func load() async {
        if let cached = catalog.cachedHTML(entry.id) {
            html = cached
            return
        }
        guard storeManager.isPremium else { return }
        loading = true
        failed = false
        if let content = await PremiumVault.shared.content(for: entry.id) {
            html = content
            catalog.saveHTML(content, for: entry.id)
        } else {
            failed = true
        }
        loading = false
    }
}

/// Affiche le contenu d'une fiche (HTML statique) sans JavaScript ni lien sortant.
struct FicheHTMLView: UIViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        guard context.coordinator.loaded != html else { return }
        context.coordinator.loaded = html
        let page = """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
        :root{color-scheme:light dark}
        body{font:16px/1.55 -apple-system,system-ui,sans-serif;margin:0;padding:16px 16px 40px;word-wrap:break-word}
        h1,h2,h3{line-height:1.25} h2{font-size:1.15em;margin-top:1.4em}
        table{border-collapse:collapse;width:100%;font-size:.9em} td,th{border:1px solid #8884;padding:6px;text-align:left}
        code,.code{font-family:ui-monospace,Menlo,monospace;background:#8882;padding:1px 5px;border-radius:4px}
        .box,.card{border:1px solid #8884;border-radius:10px;padding:10px 14px;margin:12px 0}
        a{color:inherit;text-decoration:none}
        </style></head><body>\(html)</body></html>
        """
        web.loadHTMLString(page, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded = ""
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(action.navigationType == .linkActivated ? .cancel : .allow)
        }
    }
}
