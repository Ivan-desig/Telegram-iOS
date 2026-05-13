// AyuSettingsController.swift
// AyuGram for iOS — Settings UI
// Add this file to: Telegram/Telegram-iOS/AyuGram/
//
// This is a standard Telegram-style controller using ItemListController
// (the same pattern used throughout Telegram-iOS settings)
//
// Integration: In SettingsController.swift, add an "AyuGram" row
// that pushes AyuSettingsController onto the navigation stack.

import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI

// MARK: - Entries

private enum AyuSettingsSection: Int32 {
    case ghostMode = 0
    case messageHistory = 1
    case privacy = 2
}

private enum AyuSettingsEntry: ItemListNodeEntry {
    // Ghost Mode Header + Items
    case ghostModeHeader(PresentationTheme, String)
    case sendReadPackets(PresentationTheme, String, Bool)
    case sendOnlinePackets(PresentationTheme, String, Bool)
    case sendTypingPackets(PresentationTheme, String, Bool)
    case sendUploadProgress(PresentationTheme, String, Bool)
    case instantOffline(PresentationTheme, String, Bool)
    case ghostModeFooter(PresentationTheme, String)
    
    // Message History Header + Items
    case messageHistoryHeader(PresentationTheme, String)
    case keepDeletedMessages(PresentationTheme, String, Bool)
    case keepEditedMessages(PresentationTheme, String, Bool)
    case messageHistoryFooter(PresentationTheme, String)
    
    // Privacy Header + Items
    case privacyHeader(PresentationTheme, String)
    case allowScreenshots(PresentationTheme, String, Bool)
    case hideSponsored(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .ghostModeHeader, .sendReadPackets, .sendOnlinePackets,
             .sendTypingPackets, .sendUploadProgress, .instantOffline, .ghostModeFooter:
            return AyuSettingsSection.ghostMode.rawValue
        case .messageHistoryHeader, .keepDeletedMessages, .keepEditedMessages, .messageHistoryFooter:
            return AyuSettingsSection.messageHistory.rawValue
        case .privacyHeader, .allowScreenshots, .hideSponsored:
            return AyuSettingsSection.privacy.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .ghostModeHeader:       return 0
        case .sendReadPackets:       return 1
        case .sendOnlinePackets:     return 2
        case .sendTypingPackets:     return 3
        case .sendUploadProgress:    return 4
        case .instantOffline:        return 5
        case .ghostModeFooter:       return 6
        case .messageHistoryHeader:  return 7
        case .keepDeletedMessages:   return 8
        case .keepEditedMessages:    return 9
        case .messageHistoryFooter:  return 10
        case .privacyHeader:         return 11
        case .allowScreenshots:      return 12
        case .hideSponsored:         return 13
        }
    }
    
    static func < (lhs: AyuSettingsEntry, rhs: AyuSettingsEntry) -> Bool {
        lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! AyuSettingsArguments
        
        switch self {
        case let .ghostModeHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
        case let .ghostModeFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
        case let .messageHistoryHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
        case let .messageHistoryFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
        case let .privacyHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: section)
            
        case let .sendReadPackets(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData, title: text, value: value,
                sectionId: section,
                style: .blocks,
                updated: { args.toggleReadPackets($0) }
            )
        case let .sendOnlinePackets(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData, title: text, value: value,
                sectionId: section, style: .blocks,
                updated: { args.toggleOnlinePackets($0) }
            )
        case let .sendTypingPackets(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData, title: text, value: value,
                sectionId: section, style: .blocks,
                updated: { args.toggleTypingPackets($0) }
            )
        case let .sendUploadProgress(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData, title: text, value: value,
                sectionId: section, style: .blocks,
                updated: { args.toggleUploadProgress($0) }
            )
        case let .instantOffline(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData, title: text, value: value,
                sectionId: section, style: .blocks,
                updated: { args.toggleInstantOffline($0) }
            )
        case let .keepDeletedMessages(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData, title: text, value: value,
                sectionId: section, style: .blocks,
                updated: { args.toggleKeepDeleted($0) }
            )
        case let .keepEditedMessages(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData, title: text, value: value,
                sectionId: section, style: .blocks,
                updated: { args.toggleKeepEdited($0) }
            )
        case let .allowScreenshots(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData, title: text, value: value,
                sectionId: section, style: .blocks,
                updated: { args.toggleScreenshots($0) }
            )
        case let .hideSponsored(_, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData, title: text, value: value,
                sectionId: section, style: .blocks,
                updated: { args.toggleHideSponsored($0) }
            )
        }
    }
}

// MARK: - Arguments

private struct AyuSettingsArguments {
    let toggleReadPackets: (Bool) -> Void
    let toggleOnlinePackets: (Bool) -> Void
    let toggleTypingPackets: (Bool) -> Void
    let toggleUploadProgress: (Bool) -> Void
    let toggleInstantOffline: (Bool) -> Void
    let toggleKeepDeleted: (Bool) -> Void
    let toggleKeepEdited: (Bool) -> Void
    let toggleScreenshots: (Bool) -> Void
    let toggleHideSponsored: (Bool) -> Void
}

// MARK: - State

private struct AyuSettingsState: Equatable {
    var sendReadPackets: Bool
    var sendOnlinePackets: Bool
    var sendTypingPackets: Bool
    var sendUploadProgress: Bool
    var instantOffline: Bool
    var keepDeleted: Bool
    var keepEdited: Bool
    var allowScreenshots: Bool
    var hideSponsored: Bool
    
    static func fromShared() -> AyuSettingsState {
        let s = AyuSettings.shared
        return AyuSettingsState(
            sendReadPackets: s.sendReadPackets,
            sendOnlinePackets: s.sendOnlinePackets,
            sendTypingPackets: s.sendTypingPackets,
            sendUploadProgress: s.sendUploadProgress,
            instantOffline: s.instantOfflineAfterSend,
            keepDeleted: s.keepDeletedMessages,
            keepEdited: s.keepEditedMessages,
            allowScreenshots: s.allowScreenshotsInSecretChats,
            hideSponsored: s.hideSponsored
        )
    }
}

// MARK: - Entries builder

private func ayuSettingsEntries(state: AyuSettingsState, theme: PresentationTheme) -> [AyuSettingsEntry] {
    var entries: [AyuSettingsEntry] = []
    
    // Ghost Mode
    entries.append(.ghostModeHeader(theme, "GHOST MODE"))
    entries.append(.sendReadPackets(theme, "Отправлять 'прочитано'", state.sendReadPackets))
    entries.append(.sendOnlinePackets(theme, "Показывать статус 'онлайн'", state.sendOnlinePackets))
    entries.append(.sendTypingPackets(theme, "Показывать 'печатает...'", state.sendTypingPackets))
    entries.append(.sendUploadProgress(theme, "Показывать прогресс загрузки", state.sendUploadProgress))
    entries.append(.instantOffline(theme, "Мгновенный офлайн после отправки", state.instantOffline))
    entries.append(.ghostModeFooter(theme, "Отключи всё выше для полного режима призрака. Другие не увидят твой онлайн, факт прочтения и индикатор набора."))
    
    // Message History
    entries.append(.messageHistoryHeader(theme, "ИСТОРИЯ СООБЩЕНИЙ"))
    entries.append(.keepDeletedMessages(theme, "Сохранять удалённые сообщения", state.keepDeleted))
    entries.append(.keepEditedMessages(theme, "Сохранять историю правок", state.keepEdited))
    entries.append(.messageHistoryFooter(theme, "Сообщения сохраняются локально и не исчезают даже после очистки кеша."))
    
    // Privacy
    entries.append(.privacyHeader(theme, "ПРИВАТНОСТЬ"))
    entries.append(.allowScreenshots(theme, "Скриншоты в секретных чатах", state.allowScreenshots))
    entries.append(.hideSponsored(theme, "Скрывать рекламные сообщения", state.hideSponsored))
    
    return entries
}

// MARK: - Controller factory

public func ayuSettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(AyuSettingsState.fromShared(), ignoreRepeated: true)
    let stateValue = Atomic(value: AyuSettingsState.fromShared())
    
    let updateState: ((AyuSettingsState) -> AyuSettingsState) -> Void = { f in
        statePromise.set(stateValue.modify(f))
    }
    
    let arguments = AyuSettingsArguments(
        toggleReadPackets: { v in
            AyuSettings.shared.sendReadPackets = v
            updateState { s in var s = s; s.sendReadPackets = v; return s }
        },
        toggleOnlinePackets: { v in
            AyuSettings.shared.sendOnlinePackets = v
            updateState { s in var s = s; s.sendOnlinePackets = v; return s }
        },
        toggleTypingPackets: { v in
            AyuSettings.shared.sendTypingPackets = v
            updateState { s in var s = s; s.sendTypingPackets = v; return s }
        },
        toggleUploadProgress: { v in
            AyuSettings.shared.sendUploadProgress = v
            updateState { s in var s = s; s.sendUploadProgress = v; return s }
        },
        toggleInstantOffline: { v in
            AyuSettings.shared.instantOfflineAfterSend = v
            updateState { s in var s = s; s.instantOffline = v; return s }
        },
        toggleKeepDeleted: { v in
            AyuSettings.shared.keepDeletedMessages = v
            updateState { s in var s = s; s.keepDeleted = v; return s }
        },
        toggleKeepEdited: { v in
            AyuSettings.shared.keepEditedMessages = v
            updateState { s in var s = s; s.keepEdited = v; return s }
        },
        toggleScreenshots: { v in
            AyuSettings.shared.allowScreenshotsInSecretChats = v
            updateState { s in var s = s; s.allowScreenshots = v; return s }
        },
        toggleHideSponsored: { v in
            AyuSettings.shared.hideSponsored = v
            updateState { s in var s = s; s.hideSponsored = v; return s }
        }
    )
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries = ayuSettingsEntries(state: state, theme: presentationData.theme)
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("AyuGram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    return controller
}
