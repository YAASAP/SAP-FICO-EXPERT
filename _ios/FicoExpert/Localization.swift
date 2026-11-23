import Foundation

/// Texte de l'interface dans la langue de l'iPhone (français ou anglais).
func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }

/// Vrai si l'app doit afficher le catalogue en français.
var appUsesFrench: Bool { Bundle.main.preferredLocalizations.first == "fr" }
