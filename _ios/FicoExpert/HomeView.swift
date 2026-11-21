import SwiftUI

/// Accueil natif en tuiles (façon launchpad Fiori) : un accès direct à chaque famille de fiches.
struct HomeView: View {
    @ObservedObject var catalog: CatalogStore
    @ObservedObject var store: StoreManager
    var openCatalog: (_ filter: String, _ query: String) -> Void
    var openLibrary: () -> Void
    var openSite: () -> Void
    var openPremium: () -> Void

    @State private var query = ""

    private struct Tile: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        var glyph: String? = nil
        let color: Color
        let count: Int?
        let action: () -> Void
    }

    private func count(_ module: String) -> Int { catalog.entries.filter { $0.module == module }.count }

    private var tiles: [Tile] {
        [
            Tile(id: "fi", title: "SAP FI", subtitle: "Comptabilité générale, clients, fournisseurs",
                 symbol: "eurosign.circle.fill", glyph: "€$£", color: Color(red: 0.25, green: 0.52, blue: 0.96), count: count("SAP FI")) {
                openCatalog("SAP FI", "") },
            Tile(id: "co", title: "SAP CO", subtitle: "Contrôle de gestion",
                 symbol: "chart.line.uptrend.xyaxis", color: Color(red: 0.20, green: 0.70, blue: 0.50), count: count("SAP CO")) {
                openCatalog("SAP CO", "") },
            Tile(id: "aa", title: "Immobilisations", subtitle: "Amortissements, AA",
                 symbol: "building.columns.fill", color: Color(red: 0.95, green: 0.55, blue: 0.20), count: count("Immobilisations")) {
                openCatalog("Immobilisations", "") },
            Tile(id: "mm", title: "Logistique MM-FI", subtitle: "Achats, stocks, GR/IR",
                 symbol: "shippingbox.fill", color: Color(red: 0.62, green: 0.40, blue: 0.90), count: count("SAP MM-FI")) {
                openCatalog("SAP MM-FI", "") },
            Tile(id: "tips", title: "Tips & pièges", subtitle: "Erreurs courantes et solutions",
                 symbol: "lightbulb.fill", color: Color(red: 0.93, green: 0.72, blue: 0.15),
                 count: catalog.entries.filter { $0.isTip }.count) {
                openCatalog("Tips & pièges", "") },
            Tile(id: "fav", title: "Mes favoris", subtitle: "Mes fiches marquées",
                 symbol: "star.fill", color: Color(red: 0.92, green: 0.35, blue: 0.55), count: catalog.favoriteIDs.count) {
                openCatalog("Favoris", "") },
            Tile(id: "lib", title: "Ma bibliothèque", subtitle: "Récents, notes, favoris du site",
                 symbol: "books.vertical.fill", color: Color(red: 0.35, green: 0.62, blue: 0.80), count: nil) {
                openLibrary() },
            Tile(id: "site", title: "Atlas & formations", subtitle: "Le site complet FICO EXPERT",
                 symbol: "globe.europe.africa.fill", color: Color(red: 0.45, green: 0.50, blue: 0.62), count: nil) {
                openSite() }
        ]
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            Color(AppConfig.nightBlue).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("YAASAP")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .italic()
                                .foregroundStyle(LinearGradient(
                                    colors: [.white, Color(red: 0.62, green: 0.78, blue: 1.0)],
                                    startPoint: .top, endPoint: .bottom))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(red: 0.20, green: 0.42, blue: 0.90).opacity(0.55))
                                )
                            Text("présente")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.55))
                        }
                        Text("FICO EXPERT")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                        Text("Des solutions concrètes pour SAP FI/CO")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .padding(.top, 8)

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(.white.opacity(0.6))
                        TextField("", text: $query,
                                  prompt: Text("Rechercher une transaction, un code, un mot…")
                                    .foregroundColor(.white.opacity(0.45)))
                            .foregroundColor(.white)
                            .submitLabel(.search)
                            .onSubmit { openCatalog("Tous", query); query = "" }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button(action: openPremium) {
                        HStack(spacing: 12) {
                            Image(systemName: store.isPremium ? "checkmark.seal.fill" : "lock.open.fill")
                                .font(.title2)
                                .foregroundColor(store.isPremium ? .green : Color(red: 0.93, green: 0.72, blue: 0.15))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.isPremium ? "Premium actif" : "Débloquer toutes les fiches")
                                    .font(.headline).foregroundColor(.white)
                                Text(store.isPremium ? "Toutes les fiches, hors ligne" : "Lecture complète, achat unique")
                                    .font(.caption).foregroundColor(.white.opacity(0.65))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.4))
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(tiles) { tile in
                            Button(action: tile.action) { tileView(tile) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
    }

    private func tileView(_ tile: Tile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Group {
                    if let g = tile.glyph {
                        Text(g).font(.system(size: 14, weight: .heavy, design: .rounded))
                    } else {
                        Image(systemName: tile.symbol).font(.system(size: 20, weight: .semibold))
                    }
                }
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(tile.color)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
                if let n = tile.count {
                    Text("\(n)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            Spacer(minLength: 0)
            Text(tile.title)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            Text(tile.subtitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.65))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 140, maxHeight: 140, alignment: .topLeading)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}
