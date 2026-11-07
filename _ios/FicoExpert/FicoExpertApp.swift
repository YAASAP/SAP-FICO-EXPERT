import SwiftUI

enum AppConfig {
    /// URL de départ : app Replit publiée de YAASAP.
    static let startURL = URL(string: "https://defiant-vengeful-lamp.replit.app")!

    /// Domaines ouverts dans l'app. Tout le reste s'ouvre dans Safari.
    static let allowedHosts: Set<String> = [
        "yaasap.github.io",
        "replit.app",
        "replit.dev"
    ]

    /// Bleu nuit de la charte YAASAP (#0B1A2E)
    static let nightBlue = UIColor(red: 11/255, green: 26/255, blue: 46/255, alpha: 1)
}

@main
struct FicoExpertApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
