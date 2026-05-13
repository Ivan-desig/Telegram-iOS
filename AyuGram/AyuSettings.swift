// AyuSettings.swift
// AyuGram for iOS — Settings storage
// Add this file to: Telegram/Telegram-iOS/AyuGram/

import Foundation

public final class AyuSettings {
    public static let shared = AyuSettings()
    
    private let defaults: UserDefaults
    
    private init() {
        defaults = UserDefaults(suiteName: "com.ayugram.ios.settings") ?? .standard
    }
    
    // MARK: - Ghost Mode
    
    /// Не отправлять пакеты "прочитано" (синие галочки)
    public var sendReadPackets: Bool {
        get { defaults.value(forKey: "ayu_sendReadPackets") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "ayu_sendReadPackets"); notify() }
    }
    
    /// Не обновлять статус "онлайн" при использовании приложения
    public var sendOnlinePackets: Bool {
        get { defaults.value(forKey: "ayu_sendOnlinePackets") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "ayu_sendOnlinePackets"); notify() }
    }
    
    /// Не отправлять индикатор "печатает..."
    public var sendTypingPackets: Bool {
        get { defaults.value(forKey: "ayu_sendTypingPackets") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "ayu_sendTypingPackets"); notify() }
    }
    
    /// Не отправлять статус загрузки файла
    public var sendUploadProgress: Bool {
        get { defaults.value(forKey: "ayu_sendUploadProgress") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "ayu_sendUploadProgress"); notify() }
    }
    
    /// Мгновенный офлайн после отправки сообщения
    public var instantOfflineAfterSend: Bool {
        get { defaults.value(forKey: "ayu_instantOffline") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "ayu_instantOffline"); notify() }
    }
    
    /// Использовать scheduled messages чтобы оставаться офлайн (отправка через 1 сек)
    public var useScheduledForOffline: Bool {
        get { defaults.value(forKey: "ayu_useScheduledOffline") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "ayu_useScheduledOffline"); notify() }
    }
    
    // MARK: - Message History
    
    /// Сохранять удалённые сообщения локально
    public var keepDeletedMessages: Bool {
        get { defaults.value(forKey: "ayu_keepDeleted") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "ayu_keepDeleted"); notify() }
    }
    
    /// Сохранять историю редактирований
    public var keepEditedMessages: Bool {
        get { defaults.value(forKey: "ayu_keepEdited") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "ayu_keepEdited"); notify() }
    }
    
    // MARK: - Privacy / Misc
    
    /// Разрешить скриншоты в секретных чатах
    public var allowScreenshotsInSecretChats: Bool {
        get { defaults.value(forKey: "ayu_secretScreenshots") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "ayu_secretScreenshots"); notify() }
    }
    
    /// Скрывать спонсируемые сообщения
    public var hideSponsored: Bool {
        get { defaults.value(forKey: "ayu_hideSponsored") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "ayu_hideSponsored"); notify() }
    }
    
    // MARK: - Notification
    
    public static let didChangeNotification = Notification.Name("AyuSettingsDidChange")
    
    private func notify() {
        NotificationCenter.default.post(name: AyuSettings.didChangeNotification, object: nil)
    }
}
