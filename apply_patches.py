#!/usr/bin/env python3
# apply_patches.py
# AyuGram for iOS — автоматически применяет все патчи к исходникам Telegram-iOS
#
# Запуск: python3 apply_patches.py /path/to/Telegram-iOS
#
# Патчит следующие файлы:
#   1. submodules/TelegramCore/Sources/TelegramEngine/Messages/ReadMessages.swift
#      — Ghost Mode: не отправлять read receipts
#   2. submodules/TelegramCore/Sources/State/AccountStateManager.swift
#      — Ghost Mode: не обновлять статус online
#   3. submodules/TelegramCore/Sources/TelegramEngine/Messages/ChatInputState.swift
#      — Ghost Mode: не отправлять typing
#   4. submodules/TelegramCore/Sources/TelegramEngine/Messages/Messages.swift
#      — Message History: перехват удалённых/изменённых сообщений
#   5. Telegram/Telegram-iOS/SharedAccountContext.swift или AppDelegate
#      — Копирование наших Swift-файлов в проект (добавляется BUILD правило)
#   6. submodules/TelegramUI/Sources/ChatMessageItemView.swift
#      — Скрытие sponsored сообщений
#   7. Telegram/Telegram-iOS/SecretChatController или WindowManager
#      — Разрешить скриншоты в секретных чатах

import sys
import os
import re
import shutil

def patch_file(filepath, search, replacement, description):
    """Apply a single search/replace patch to a file."""
    if not os.path.exists(filepath):
        print(f"  ⚠️  ПРОПУЩЕНО (файл не найден): {filepath}")
        return False
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if search not in content:
        print(f"  ⚠️  ПРОПУЩЕНО (шаблон не найден в {os.path.basename(filepath)}): {description}")
        return False
    
    count = content.count(search)
    if count > 1:
        print(f"  ⚠️  ОСТОРОЖНО: шаблон найден {count} раз в {os.path.basename(filepath)}: {description}")
    
    new_content = content.replace(search, replacement, 1)
    
    # Backup original
    backup = filepath + '.ayu_backup'
    if not os.path.exists(backup):
        shutil.copy2(filepath, backup)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"  ✅ {description}")
    return True


def prepend_to_file(filepath, text, description):
    """Prepend text to a file (e.g. import statement)."""
    if not os.path.exists(filepath):
        print(f"  ⚠️  ПРОПУЩЕНО: {filepath}")
        return False
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    if text.strip() in content:
        print(f"  ⏩ Уже применено: {description}")
        return True
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(text + '\n' + content)
    print(f"  ✅ {description}")
    return True


def add_after(filepath, search, addition, description):
    """Insert code after a search string."""
    if not os.path.exists(filepath):
        print(f"  ⚠️  ПРОПУЩЕНО: {filepath}")
        return False
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    if search not in content:
        print(f"  ⚠️  ПРОПУЩЕНО (не найдено): {description}")
        return False
    if addition in content:
        print(f"  ⏩ Уже применено: {description}")
        return True
    new_content = content.replace(search, search + addition, 1)
    backup = filepath + '.ayu_backup'
    if not os.path.exists(backup):
        shutil.copy2(filepath, backup)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print(f"  ✅ {description}")
    return True


def main():
    if len(sys.argv) < 2:
        print("Использование: python3 apply_patches.py /path/to/Telegram-iOS")
        sys.exit(1)
    
    root = sys.argv[1]
    if not os.path.isdir(root):
        print(f"Директория не существует: {root}")
        sys.exit(1)
    
    print(f"\n🔧 AyuGram for iOS — применяю патчи к: {root}\n")
    
    # ─── Paths ───────────────────────────────────────────────────────────────
    
    read_messages = os.path.join(root, "submodules/TelegramCore/Sources/TelegramEngine/Messages/ReadMessages.swift")
    account_state  = os.path.join(root, "submodules/TelegramCore/Sources/State/AccountStateManager.swift")
    messages_main  = os.path.join(root, "submodules/TelegramCore/Sources/TelegramEngine/Messages/Messages.swift")
    message_list   = os.path.join(root, "submodules/TelegramUI/Sources/ChatMessageItemView.swift")
    secret_screen  = os.path.join(root, "submodules/TelegramUI/Sources/SecretMediaPreviewController.swift")
    window_manager = os.path.join(root, "Telegram/Telegram-iOS/WindowManager.swift")
    
    # Also search for typing indicator
    chat_typing_candidates = [
        os.path.join(root, "submodules/TelegramCore/Sources/TelegramEngine/Messages/RequestChatContextResults.swift"),
        os.path.join(root, "submodules/TelegramCore/Sources/TelegramEngine/Messages/SetTyping.swift"),
        os.path.join(root, "submodules/TelegramCore/Sources/ApiUtils/SendMessagesHelpers.swift"),
    ]
    
    # ─── Copy our Swift files ─────────────────────────────────────────────────
    
    print("📁 Копирую AyuGram Swift-файлы...")
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    ayu_src = os.path.join(script_dir, "AyuGram")
    ayu_dst = os.path.join(root, "Telegram/Telegram-iOS/AyuGram")
    
    if os.path.isdir(ayu_src):
        os.makedirs(ayu_dst, exist_ok=True)
        for fname in os.listdir(ayu_src):
            if fname.endswith('.swift'):
                shutil.copy2(os.path.join(ayu_src, fname), os.path.join(ayu_dst, fname))
                print(f"  ✅ Скопирован: {fname}")
    else:
        print(f"  ⚠️  Папка AyuGram не найдена рядом со скриптом")
    
    # ─── PATCH 1: Read Receipts ───────────────────────────────────────────────
    
    print("\n👻 Ghost Mode — патчу read receipts...")
    
    # Pattern 1: readHistory call - wrap with guard
    patch_file(
        read_messages,
        search='return account.network.request(Api.messages.readHistory(',
        replacement='''if !AyuSettings.shared.sendReadPackets { return .complete() }
        return account.network.request(Api.messages.readHistory(''',
        description="Блокировка read history пакетов"
    )
    
    # Pattern 2: readMessageContents
    patch_file(
        read_messages,
        search='account.network.request(Api.messages.readMessageContents(',
        replacement='''if AyuSettings.shared.sendReadPackets {
            account.network.request(Api.messages.readMessageContents(''',
        description="Блокировка readMessageContents"
    )
    
    # ─── PATCH 2: Online Status ───────────────────────────────────────────────
    
    print("\n👻 Ghost Mode — патчу online status...")
    
    # The updateStatus call - always send offline when setting is disabled
    patch_file(
        account_state,
        search='|> mapToSignal { _ -> Signal<Never, NoError> in\n            return account.network.request(Api.account.updateStatus(offline: .boolFalse))',
        replacement='''|> mapToSignal { _ -> Signal<Never, NoError> in
            if !AyuSettings.shared.sendOnlinePackets { return .complete() }
            return account.network.request(Api.account.updateStatus(offline: .boolFalse))''',
        description="Блокировка online status пакетов"
    )
    
    # Instant offline: immediately send offline after message sent
    # Find the "sent message" callback and add updateStatus(offline: true)
    patch_file(
        messages_main,
        search='// Mark: send message success',
        replacement='''// Mark: send message success
        if AyuSettings.shared.instantOfflineAfterSend {
            let _ = account.network.request(Api.account.updateStatus(offline: .boolTrue)).start()
        }''',
        description="Мгновенный офлайн после отправки (instant offline)"
    )
    
    # ─── PATCH 3: Typing Indicator ────────────────────────────────────────────
    
    print("\n👻 Ghost Mode — патчу typing indicator...")
    
    typing_patched = False
    for candidate in chat_typing_candidates:
        if os.path.exists(candidate):
            result = patch_file(
                candidate,
                search='account.network.request(Api.messages.setTyping(',
                replacement='''if !AyuSettings.shared.sendTypingPackets { break }
                    account.network.request(Api.messages.setTyping(''',
                description=f"Блокировка typing в {os.path.basename(candidate)}"
            )
            if result:
                typing_patched = True
                break
    
    if not typing_patched:
        # Generic grep-based search
        print("  🔍 Ищу setTyping в других файлах...")
        for dirpath, _, filenames in os.walk(os.path.join(root, "submodules/TelegramCore")):
            for fname in filenames:
                if fname.endswith('.swift'):
                    fpath = os.path.join(dirpath, fname)
                    with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                    if 'Api.messages.setTyping' in content and 'AyuSettings' not in content:
                        result = patch_file(
                            fpath,
                            search='Api.messages.setTyping(',
                            replacement='/* AyuGram: guard */ { guard AyuSettings.shared.sendTypingPackets else { return } }(); Api.messages.setTyping(',
                            description=f"Typing в {fname}"
                        )
                        if result:
                            typing_patched = True
                            break
            if typing_patched:
                break
    
    # ─── PATCH 4: Upload Progress ─────────────────────────────────────────────
    
    print("\n👻 Ghost Mode — патчу upload progress...")
    
    for dirpath, _, filenames in os.walk(os.path.join(root, "submodules/TelegramCore")):
        for fname in filenames:
            if 'Upload' in fname and fname.endswith('.swift'):
                fpath = os.path.join(dirpath, fname)
                with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                if 'uploadProgress' in content.lower() and 'setTyping' in content:
                    patch_file(
                        fpath,
                        search='Api.messages.setTyping(',
                        replacement='/* AyuGram upload guard */ { guard AyuSettings.shared.sendUploadProgress else { return } }(); Api.messages.setTyping(',
                        description=f"Upload progress typing в {fname}"
                    )
    
    # ─── PATCH 5: Message History — intercept deletions ───────────────────────
    
    print("\n📚 Message History — патчу перехват удалений...")
    
    # Find deleteMessages or similar
    for dirpath, _, filenames in os.walk(os.path.join(root, "submodules/TelegramCore")):
        for fname in filenames:
            if fname.endswith('.swift'):
                fpath = os.path.join(dirpath, fname)
                with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                
                # Hook incoming message updates to save to history
                if '_internal_deleteMessages' in content and 'AyuMessageHistoryStorage' not in content:
                    patch_file(
                        fpath,
                        search='public func _internal_deleteMessages(',
                        replacement='''public func _internal_deleteMessages_ayu_hook(messageIds: [MessageId]) {
        for msgId in messageIds {
            AyuMessageHistoryStorage.shared.markDeleted(
                messageId: msgId.id,
                peerId: msgId.peerId.toInt64()
            )
        }
    }
    
    public func _internal_deleteMessages(''',
                        description=f"Хук удаления сообщений в {fname}"
                    )
                
                # Hook message edits
                if '_internal_editMessage' in content and 'AyuMessageHistoryStorage' not in content:
                    patch_file(
                        fpath,
                        search='public func _internal_editMessage(',
                        replacement='''public func _internal_editMessage(''',
                        description=f"(edit hook placeholder в {fname})"
                    )
    
    # ─── PATCH 6: Sponsored Messages ─────────────────────────────────────────
    
    print("\n🚫 Скрытие рекламы — патчу sponsored messages...")
    
    # In ChatHistoryListNode or message list, filter sponsored messages
    for candidate in [
        os.path.join(root, "submodules/TelegramUI/Sources/ChatHistoryListNode.swift"),
        os.path.join(root, "submodules/TelegramUI/Sources/Chat/ChatControllerNode.swift"),
    ]:
        patch_file(
            candidate,
            search='case .sponsoredMessage:',
            replacement='''case .sponsoredMessage:
                    if AyuSettings.shared.hideSponsored { continue }''',
            description=f"Фильтрация sponsored в {os.path.basename(candidate)}"
        )
    
    # Also filter in the data source
    for dirpath, _, filenames in os.walk(os.path.join(root, "submodules/TelegramUI")):
        for fname in filenames:
            if fname.endswith('.swift'):
                fpath = os.path.join(dirpath, fname)
                with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                if 'sponsoredMessage' in content and 'isSponsored' in content and 'AyuSettings' not in content:
                    patch_file(
                        fpath,
                        search='if message.isSponsored {',
                        replacement='''if message.isSponsored {
                    if AyuSettings.shared.hideSponsored { return nil }''',
                        description=f"Sponsored фильтр в {fname}"
                    )
                    break
    
    # ─── PATCH 7: Secret Chat Screenshots ────────────────────────────────────
    
    print("\n📸 Секретные чаты — патчу скриншоты...")
    
    # Find where isSecureTextEntry or secure display is set for secret chats
    for dirpath, _, filenames in os.walk(os.path.join(root, "submodules/TelegramUI")):
        for fname in filenames:
            if fname.endswith('.swift'):
                fpath = os.path.join(dirpath, fname)
                with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                
                if 'isSecretChat' in content and 'isSecureTextEntry' in content and 'AyuSettings' not in content:
                    patch_file(
                        fpath,
                        search='view.isSecureTextEntry = true',
                        replacement='''view.isSecureTextEntry = !AyuSettings.shared.allowScreenshotsInSecretChats''',
                        description=f"Скриншоты в секретных чатах в {fname}"
                    )
    
    # WindowManager: prevent screenshot notification
    patch_file(
        window_manager,
        search='if case .secretChat = chatLocation {',
        replacement='''if case .secretChat = chatLocation, !AyuSettings.shared.allowScreenshotsInSecretChats {''',
        description="Screenshot lock в WindowManager"
    )
    
    # ─── PATCH 8: Add AyuGram entry to Settings ───────────────────────────────
    
    print("\n⚙️  Добавляю пункт 'AyuGram' в настройки...")
    
    settings_file = os.path.join(root, "submodules/TelegramUI/Sources/PeerInfo/PeerInfoScreen.swift")
    settings_alt   = os.path.join(root, "submodules/TelegramUI/Sources/Settings/SettingsController.swift")
    
    for sf in [settings_file, settings_alt]:
        if os.path.exists(sf):
            add_after(
                sf,
                search='case privacy',
                addition='''
    case ayuGram''',
                description=f"AyuGram entry в {os.path.basename(sf)}"
            )
    
    # ─── PATCH 9: BUILD file ──────────────────────────────────────────────────
    
    print("\n🔨 Патчу BUILD файл для включения AyuGram...")
    
    # Find main app BUILD file
    build_file = os.path.join(root, "Telegram/Telegram-iOS/BUILD")
    if os.path.exists(build_file):
        add_after(
            build_file,
            search='swift_sources = [',
            addition='''
        "AyuGram/AyuSettings.swift",
        "AyuGram/AyuMessageHistoryStorage.swift",
        "AyuGram/AyuSettingsController.swift",''',
            description="Добавление AyuGram файлов в BUILD"
        )
    
    # ─── Done ──────────────────────────────────────────────────────────────────
    
    print("\n" + "="*60)
    print("✅ Патчи применены!")
    print("\nСледующие шаги:")
    print("  1. Открой Telegram-iOS в VS Code / редакторе")
    print("  2. Убедись что 'import AyuSettings' добавлен в нужные файлы")
    print("  3. Запусти GitHub Actions build (смотри build.yml)")
    print("  4. Скачай .ipa из Artifacts")
    print("  5. Подпиши через ESign")
    print("="*60)


if __name__ == "__main__":
    main()
