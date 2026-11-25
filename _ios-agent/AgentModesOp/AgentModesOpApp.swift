import SwiftUI

enum AppConfig {
    /// Page de l'agent (GitHub Pages YAASAP).
    static let startURL = URL(string: "https://yaasap.github.io/SAP-FICO-EXPERT/agent-modes-op/index.html")!

    /// Domaines ouverts dans l'app. Tout le reste s'ouvre dans Safari.
    /// Le serveur de l'agent (replit.app) est appelé par la page, pas navigué.
    static let allowedHosts: Set<String> = ["yaasap.github.io"]

    /// Bleu nuit de la charte YAASAP (#0B1A2E)
    static let nightBlue = UIColor(red: 11/255, green: 26/255, blue: 46/255, alpha: 1)
}

@main
struct AgentModesOpApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
