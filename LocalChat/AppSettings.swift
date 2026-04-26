import Foundation
import LocalChatKit

// MARK: - Protocol

protocol AppSettingsProtocol {
    var lastSelectedModel: LocalChatKit.Model { get set }
}

// MARK: - UserDefaults implementation

final class AppSettings: AppSettingsProtocol {
    static let shared = AppSettings()

    private let defaults: UserDefaults
    private let lastModelKey = "lastSelectedModel"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastSelectedModel: LocalChatKit.Model {
        get {
            guard let raw = defaults.string(forKey: lastModelKey),
                  let model = LocalChatKit.Model(rawValue: raw) else {
                return .gemma4_e2b
            }
            return model
        }
        set {
            defaults.set(newValue.rawValue, forKey: lastModelKey)
        }
    }
}
