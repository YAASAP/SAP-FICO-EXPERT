// Fichier de remplacement : le workflow GitHub Actions le réécrit au build
// à partir des secrets FICO_PREMIUM_CODES et FICO_ATLAS_ENTRIES.
// Ne jamais écrire de vrais codes ici : le dépôt est public.
enum PremiumSecrets {
    static let ficheCodes = ""
    static let atlasEntries: [(email: String, code: String)] = []
    static var isConfigured: Bool { !ficheCodes.isEmpty || !atlasEntries.isEmpty }
}
