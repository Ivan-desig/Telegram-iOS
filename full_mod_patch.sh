#!/bin/bash
echo "🔥 АКТИВАЦИЯ ВСЕХ ФУНКЦИЙ МОДА..."

# 1. ЛОГИРОВАНИЕ (Удаленки и Редакты)
find . -name "MessageHistoryTable.swift" -exec sed -i '' 's/DELETE FROM messages/UPDATE messages SET local_tags = 777/g' {} +
find . -name "MessageHistoryTable.swift" -exec sed -i '' 's/func updateMessage/func updateMessageOriginal/g' {} +

# 2. РЕЖИМ ПРИЗРАКА (Скрытие статусов)
find . -name "SendMessageAction.swift" -exec sed -i '' 's/case .typing/case .none/g' {} +
find . -name "SendMessageAction.swift" -exec sed -i '' 's/case .recordingAudio/case .none/g' {} +
find . -name "SendMessageAction.swift" -exec sed -i '' 's/case .recordingVideo/case .none/g' {} +
find . -name "SendMessageAction.swift" -exec sed -i '' 's/case .uploading/case .none/g' {} +
find . -name "SendMessageAction.swift" -exec sed -i '' 's/case .choosingSticker/case .none/g' {} +

# 3. НЕЧИТАЛКА И СТОРИС
find . -name "ApiUtils.swift" -exec sed -i '' 's/markMessagesAsRead/disabledRead/g' {} +
find . -name "EngineStoryUpdate.swift" -exec sed -i '' 's/markAsRead = true/markAsRead = false/g' {} +

# 4. ЗАЩИТА (Анти-скриншот и сохранение)
find . -name "Message.swift" -exec sed -i '' 's/var isContentProtected: Bool { return true }/var isContentProtected: Bool { return false }/g' {} +
find . -name "WindowView.swift" -exec sed -i '' 's/isSecure = true/isSecure = false/g' {} +

# 5. КРЯК PRO И ЛОКАЛЬНЫЙ ПРЕМИУМ
find . -name "SwiftgramPro.swift" -exec sed -i '' 's/return .none/return .active/g' {} +
find . -name "PremiumConfiguration.swift" -exec sed -i '' 's/isPremium: Bool = false/isPremium: Bool = true/g' {} +
find . -name "UserLimits.swift" -exec sed -i '' 's/return 5/return 100/g' {} +

echo "✅ ВСЕ ФУНКЦИИ ВНЕДРЕНЫ!"
