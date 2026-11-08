import Foundation
import WebKit
import CryptoKit
import CommonCrypto

/// Déchiffre les fiches Premium pour le site, après un achat intégré valide.
/// Même format que le site : fiches (code Base32 de 26 caractères, AES-GCM)
/// et Atlas (e-mail + code, PBKDF2 puis AES-GCM). Les codes viennent de PremiumSecrets.
actor PremiumVault {
    static let shared = PremiumVault()
    private var cache: [String: [String: Any]] = [:]

    func content(for id: String) async -> String? {
        guard PremiumSecrets.isConfigured, let payload = await fetchPayload(for: id) else { return nil }
        switch payload["type"] as? String {
        case "public": return payload["html"] as? String
        case "fiche": return openFiche(payload)
        case "atlas": return openAtlas(payload)
        default: return nil
        }
    }

    // MARK: Réseau

    private func fetchPayload(for id: String) async -> [String: Any]? {
        if let cached = cache[id] { return cached }
        guard let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: AppConfig.startURL.absoluteString + "/content/\(encoded).json"),
              let result = try? await URLSession.shared.data(from: url),
              (result.1 as? HTTPURLResponse)?.statusCode == 200,
              let object = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any]
        else { return nil }
        cache[id] = object
        return object
    }

    // MARK: Fiches

    private func openFiche(_ payload: [String: Any]) -> String? {
        guard let e = payload["e"] as? String else { return nil }
        let code = Array(Self.normalize(PremiumSecrets.ficheCodes))
        guard code.count >= 26, code.count % 26 == 0 else { return nil }
        for start in stride(from: 0, to: code.count, by: 26) {
            guard let key = Self.base32(String(code[start..<(start + 26)])), key.count == 16 else { continue }
            if let data = Self.decrypt(key: key, combined: e), let text = String(data: data, encoding: .utf8) {
                return text
            }
            if let w = payload["w"] as? String,
               let ficheKey = Self.decrypt(key: key, combined: w),
               let data = Self.decrypt(key: ficheKey, combined: e),
               let text = String(data: data, encoding: .utf8) {
                return text
            }
        }
        return nil
    }

    // MARK: Atlas

    private func openAtlas(_ payload: [String: Any]) -> String? {
        guard let gs = payload["GS"] as? String,
              let pi = payload["PI"] as? String,
              let pl = payload["PL"] as? String,
              let wrappers = payload["WR"] as? [[String: Any]],
              let iv = Data(base64Encoded: pi),
              let sealed = Data(base64Encoded: pl)
        else { return nil }
        for entry in PremiumSecrets.atlasEntries {
            let email = entry.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let code = entry.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !email.isEmpty else { continue }
            let digest = SHA256.hash(data: Data((gs + email).utf8))
            let hex = digest.map { String(format: "%02x", $0) }.joined()
            let id = String(hex.prefix(12))
            guard let wrapper = wrappers.first(where: { ($0["id"] as? String) == id }),
                  let s = wrapper["s"] as? String, let salt = Data(base64Encoded: s),
                  let i = wrapper["i"] as? String, let wrapIV = Data(base64Encoded: i),
                  let w = wrapper["w"] as? String, let wrapped = Data(base64Encoded: w),
                  let wrappingKey = Self.pbkdf2("\(email):\(code)", salt: salt),
                  let rawKey = Self.open(key: wrappingKey, iv: wrapIV, sealed: wrapped),
                  let data = Self.open(key: rawKey, iv: iv, sealed: sealed),
                  let text = String(data: data, encoding: .utf8)
            else { continue }
            return text
        }
        return nil
    }

    // MARK: Outils

    static func normalize(_ code: String) -> String {
        let alphabet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        return String(code.uppercased().filter { alphabet.contains($0) })
    }

    static func base32(_ code: String) -> Data? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var bits = 0
        var value = 0
        var output = [UInt8]()
        for character in code {
            guard let index = alphabet.firstIndex(of: character) else { return nil }
            value = (value << 5) | index
            bits += 5
            if bits >= 8 {
                output.append(UInt8((value >> (bits - 8)) & 255))
                bits -= 8
                value &= (1 << bits) - 1
            }
        }
        return Data(output)
    }

    /// Format du site : base64( IV 12 octets | texte chiffré | tag 16 octets ).
    static func decrypt(key: Data, combined: String) -> Data? {
        guard let raw = Data(base64Encoded: combined), raw.count > 28 else { return nil }
        return open(key: key, iv: raw.prefix(12), sealed: raw.dropFirst(12))
    }

    /// `sealed` = texte chiffré suivi du tag de 16 octets (sortie de WebCrypto).
    static func open(key: Data, iv: Data, sealed: Data) -> Data? {
        let ivData = Data(iv)
        let body = Data(sealed)
        guard body.count > 16, [16, 24, 32].contains(key.count),
              let nonce = try? AES.GCM.Nonce(data: ivData),
              let box = try? AES.GCM.SealedBox(nonce: nonce,
                                               ciphertext: body.dropLast(16),
                                               tag: body.suffix(16)),
              let plain = try? AES.GCM.open(box, using: SymmetricKey(data: key))
        else { return nil }
        return plain
    }

    static func pbkdf2(_ password: String, salt: Data) -> Data? {
        var derived = Data(count: 32)
        let status = derived.withUnsafeMutableBytes { out -> Int32 in
            salt.withUnsafeBytes { saltBytes -> Int32 in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    password, password.utf8.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    200_000,
                    out.bindMemory(to: UInt8.self).baseAddress, 32)
            }
        }
        return status == Int32(kCCSuccess) ? derived : nil
    }
}

/// Réponse aux appels JavaScript `FICO_NATIVE.getPremiumContent(id)` : refuse sans achat valide.
final class PremiumHandler: NSObject, WKScriptMessageHandlerWithReply {
    var isPremium = false

    @MainActor
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) async -> (Any?, String?) {
        guard isPremium, let id = message.body as? String else { return (nil, "Premium requis") }
        if let html = await PremiumVault.shared.content(for: id) { return (html, nil) }
        return (nil, "Contenu indisponible")
    }
}
