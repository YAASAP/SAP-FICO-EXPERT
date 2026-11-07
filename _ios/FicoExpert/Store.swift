import SwiftUI
import StoreKit

/// Achat intégré (StoreKit 2) : un produit « Premium » non consommable.
/// À créer dans App Store Connect : Monétisation > Achats intégrés > Non consommable,
/// avec l'identifiant ci-dessous.
@MainActor
final class StoreManager: ObservableObject {
    static let premiumProductID = "com.yaasap.sapfico.premium"

    @Published private(set) var product: Product?
    @Published private(set) var isPremium = false
    @Published var message: String?
    @Published private(set) var isBusy = false

    init() {
        Task { [weak self] in
            await self?.start()
        }
    }

    private func start() async {
        await loadProduct()
        await refreshEntitlements()
        await listenForUpdates()
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.premiumProductID])
            product = products.first
            if product == nil {
                message = "Produit Premium introuvable pour le moment."
            }
        } catch {
            message = "Impossible de charger l'offre : \(error.localizedDescription)"
        }
    }

    func purchase() async {
        guard let product else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                } else {
                    message = "Achat non vérifié."
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            message = "Achat impossible : \(error.localizedDescription)"
        }
    }

    func restore() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPremium { message = "Aucun achat à restaurer." }
        } catch {
            message = "Restauration impossible : \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.premiumProductID,
               transaction.revocationDate == nil {
                active = true
            }
        }
        isPremium = active
    }

    private func listenForUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }
}

struct PaywallView: View {
    @ObservedObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: store.isPremium ? "checkmark.seal.fill" : "lock.open")
                    .font(.system(size: 44))
                    .foregroundColor(Color(red: 58/255, green: 95/255, blue: 143/255))

                if store.isPremium {
                    Text("Premium actif")
                        .font(.system(.title2, design: .serif).weight(.bold))
                    Text("Merci ! Toutes les fiches premium sont débloquées sur cet appareil.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                } else {
                    Text(store.product?.displayName ?? "FICO EXPERT Premium")
                        .font(.system(.title2, design: .serif).weight(.bold))
                    Text(store.product?.description ?? "Débloque toutes les fiches premium, atlas et modes opératoires.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)

                    Button {
                        Task { await store.purchase() }
                    } label: {
                        Text(store.product.map { "Débloquer · \($0.displayPrice)" } ?? "Débloquer")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 58/255, green: 95/255, blue: 143/255))
                    .disabled(store.product == nil || store.isBusy)

                    Button("Restaurer mes achats") {
                        Task { await store.restore() }
                    }
                    .disabled(store.isBusy)
                }

                if let message = store.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
