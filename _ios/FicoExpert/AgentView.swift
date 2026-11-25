import SwiftUI
import WebKit

/// Agent IA « modes opératoires SAP FICO » : page GitHub Pages YAASAP affichée dans l'app.
/// L'agent est gratuit et indépendant de l'achat Premium (aucun contenu Premium n'y transite).
enum AgentConfig {
    static let url = URL(string: "https://yaasap.github.io/SAP-FICO-EXPERT/agent-modes-op/index.html")!
    static let allowedHosts: Set<String> = ["yaasap.github.io"]
}

final class AgentModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    @Published var failed = false
    @Published var loading = true

    override init() {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = AppConfig.nightBlue
        webView.scrollView.backgroundColor = AppConfig.nightBlue
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        load()
    }

    func load() {
        failed = false
        loading = true
        webView.load(URLRequest(url: AgentConfig.url))
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "about" || scheme == "blob" || scheme == "data" { decisionHandler(.allow); return }
        if (scheme == "http" || scheme == "https"), let host = url.host?.lowercased(),
           AgentConfig.allowedHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
            decisionHandler(.allow); return
        }
        decisionHandler(.cancel)
        UIApplication.shared.open(url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loading = false; failed = false }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { loading = false; failed = true }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { loading = false; failed = true }
}

struct AgentWebHost: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct AgentSheet: View {
    @StateObject private var model = AgentModel()
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0.88, green: 0.9, blue: 0.93))
                        .frame(minWidth: 44, minHeight: 40)
                }
                .accessibilityLabel(L("Fermer"))
                Spacer()
                Text(L("Agent IA modes op"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Color.clear.frame(width: 44, height: 40)
            }
            .padding(.horizontal, 12)
            .background(Color(AppConfig.nightBlue))

            ZStack {
                Color(AppConfig.nightBlue)
                AgentWebHost(webView: model.webView)
                if model.loading && !model.failed { ProgressView().tint(.white) }
                if model.failed {
                    VStack(spacing: 14) {
                        Text("Connexion impossible")
                            .font(.headline).foregroundColor(.white)
                        Text("Vérifie ta connexion Internet puis réessaie.")
                            .font(.subheadline).foregroundColor(.white.opacity(0.7))
                        Button("Réessayer") { model.load() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
        }
        .background(Color(AppConfig.nightBlue).ignoresSafeArea())
    }
}
