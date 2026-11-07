import SwiftUI
import WebKit

/// Pont entre SwiftUI et la WebView : page courante, titre, navigation.
final class WebModel: ObservableObject {
    @Published var title = ""
    @Published var url: URL?
    @Published var canGoBack = false
    weak var webView: WKWebView?

    func goBack() { webView?.goBack() }
    func load(_ url: URL) { webView?.load(URLRequest(url: url)) }
    func home() { load(AppConfig.startURL) }
}

struct ContentView: View {
    @StateObject private var model = WebModel()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var store = StoreManager()

    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var reloadToken = 0
    @State private var showFavorites = false
    @State private var showPremium = false

    private let accent = Color(red: 58/255, green: 95/255, blue: 143/255)

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ZStack {
                Color(AppConfig.nightBlue)

                WebView(model: model,
                        isLoading: $isLoading,
                        loadFailed: $loadFailed,
                        isPremium: store.isPremium,
                        reloadToken: reloadToken)

                if isLoading && !loadFailed {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.3)
                }

                if loadFailed {
                    VStack(spacing: 14) {
                        Text("Connexion impossible")
                            .font(.system(.title3, design: .serif).weight(.bold))
                            .foregroundColor(.white)
                        Text("Vérifie ta connexion Internet puis réessaie.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        Button("Réessayer") {
                            loadFailed = false
                            isLoading = true
                            reloadToken += 1
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                    }
                    .padding()
                }
            }
        }
        .background(Color(AppConfig.nightBlue).ignoresSafeArea())
        .sheet(isPresented: $showFavorites) {
            FavoritesView(favorites: favorites) { url in model.load(url) }
        }
        .sheet(isPresented: $showPremium) {
            PaywallView(store: store)
        }
    }

    /// Barre d'en-tête native, icônes seules. La navigation principale
    /// (Accueil, Catalogue, Atlas, Formations, Accès) reste la barre du bas du site.
    private var topBar: some View {
        HStack(spacing: 6) {
            barButton("chevron.backward", label: "Retour", enabled: model.canGoBack) {
                model.goBack()
            }
            Spacer()
            barButton(favorites.contains(model.url) ? "star.fill" : "star",
                      label: favorites.contains(model.url) ? "Retirer des favoris" : "Ajouter aux favoris") {
                favorites.toggle(title: model.title, url: model.url)
            }
            barButton("list.star", label: "Favoris") { showFavorites = true }
            if let url = model.url {
                ShareLink(item: url, subject: Text(model.title)) {
                    barIcon("square.and.arrow.up", label: "Partager")
                }
            } else {
                barIcon("square.and.arrow.up", label: "Partager").opacity(0.35)
            }
            barButton(store.isPremium ? "checkmark.seal.fill" : "lock.open", label: "Premium") {
                showPremium = true
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Color(AppConfig.nightBlue))
        .overlay(Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1), alignment: .bottom)
    }

    private func barButton(_ symbol: String, label: String, enabled: Bool = true,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            barIcon(symbol, label: label)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    private func barIcon(_ symbol: String, label: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18))
            .foregroundColor(Color(red: 0.88, green: 0.9, blue: 0.93))
            .frame(minWidth: 44, minHeight: 40)
            .accessibilityLabel(label)
    }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var model: WebModel
    @Binding var isLoading: Bool
    @Binding var loadFailed: Bool
    var isPremium: Bool
    var reloadToken: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private static func nativeScript(premium: Bool) -> String {
        "window.FICO_NATIVE = { platform: 'ios', premium: \(premium ? "true" : "false") };"
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        // Le code d'accès chiffré reste stocké sur l'appareil (localStorage persistant).
        config.websiteDataStore = .default()

        // Expose l'état natif au site : window.FICO_NATIVE.premium
        let script = WKUserScript(source: Self.nativeScript(premium: isPremium),
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: true)
        config.userContentController.addUserScript(script)

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.isOpaque = false
        web.backgroundColor = AppConfig.nightBlue
        web.scrollView.backgroundColor = AppConfig.nightBlue

        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.refresh(_:)), for: .valueChanged)
        web.scrollView.refreshControl = refresh

        model.webView = web
        context.coordinator.lastPremium = isPremium
        web.load(URLRequest(url: AppConfig.startURL))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            web.load(URLRequest(url: AppConfig.startURL))
        }
        if context.coordinator.lastPremium != isPremium {
            context.coordinator.lastPremium = isPremium
            let js = Self.nativeScript(premium: isPremium)
                + " window.dispatchEvent(new Event('fico-native'));"
            web.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        var lastReloadToken = 0
        var lastPremium = false

        init(_ parent: WebView) { self.parent = parent }

        @objc func refresh(_ sender: UIRefreshControl) {
            parent.model.webView?.reload()
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { return decisionHandler(.allow) }

            // mailto:, tel:, etc. -> système
            let scheme = url.scheme ?? ""
            if scheme != "http" && scheme != "https" {
                UIApplication.shared.open(url)
                return decisionHandler(.cancel)
            }

            // Domaines externes -> Safari
            let host = url.host ?? ""
            let allowed = AppConfig.allowedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
            if !allowed && action.navigationType == .linkActivated {
                UIApplication.shared.open(url)
                return decisionHandler(.cancel)
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = true }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.refreshControl?.endRefreshing()
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.loadFailed = false
                self.parent.model.url = webView.url
                self.parent.model.title = webView.title ?? ""
                self.parent.model.canGoBack = webView.canGoBack
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            fail(webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            fail(webView)
        }

        private func fail(_ webView: WKWebView) {
            webView.scrollView.refreshControl?.endRefreshing()
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.loadFailed = true
            }
        }
    }
}
