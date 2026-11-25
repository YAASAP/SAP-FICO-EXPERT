import SwiftUI
import WebKit

final class WebModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    @Published var failed = false
    @Published var loading = true

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = AppConfig.nightBlue
        webView.scrollView.backgroundColor = AppConfig.nightBlue
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        let refresh = UIRefreshControl()
        refresh.tintColor = .white
        refresh.addTarget(self, action: #selector(pulled(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
        load()
    }

    func load() {
        failed = false
        loading = true
        webView.load(URLRequest(url: AppConfig.startURL))
    }

    @objc private func pulled(_ sender: UIRefreshControl) {
        webView.reload()
        sender.endRefreshing()
    }

    // MARK: WKNavigationDelegate
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "about" || scheme == "blob" || scheme == "data" {
            decisionHandler(.allow); return
        }
        if (scheme == "http" || scheme == "https"),
           let host = url.host?.lowercased(),
           AppConfig.allowedHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
            decisionHandler(.allow); return
        }
        // Lien externe : Safari
        decisionHandler(.cancel)
        UIApplication.shared.open(url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loading = false
        failed = false
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loading = false
        failed = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loading = false
        failed = true
    }

    // Les liens target=_blank s'ouvrent dans la même vue
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

struct WebHost: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ContentView: View {
    @StateObject private var model = WebModel()

    var body: some View {
        ZStack {
            Color(AppConfig.nightBlue).ignoresSafeArea()
            WebHost(webView: model.webView)
                .ignoresSafeArea()
            if model.loading && !model.failed {
                ProgressView().tint(.white)
            }
            if model.failed {
                VStack(spacing: 14) {
                    Text("Connexion impossible")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Vérifiez votre connexion internet puis réessayez.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Button("Réessayer") { model.load() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 184/255, green: 134/255, blue: 11/255))
                }
                .padding(28)
                .background(Color(AppConfig.nightBlue))
            }
        }
    }
}
