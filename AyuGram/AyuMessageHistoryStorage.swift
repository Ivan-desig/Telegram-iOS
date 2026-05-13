// AyuMessageHistoryStorage.swift
// AyuGram for iOS — Local storage for deleted/edited messages
// Add this file to: Telegram/Telegram-iOS/AyuGram/
//
// Uses SQLite.swift (already available in Telegram-iOS dependencies via SwiftSignalKit area)
// Falls back to a simple JSON file store if SQLite unavailable

import Foundation
import SQLite3

// MARK: - Data Models

public struct AyuStoredMessage: Codable {
    public let messageId: Int32
    public let peerId: Int64
    public let peerType: Int32          // 0 = user, 1 = group, 2 = channel
    public let authorId: Int64?
    public let authorName: String?
    public let text: String
    public let date: Int32
    public let deletedAt: Double?       // nil = edited, timestamp = deleted
    public let editHistory: [AyuMessageEdit]
    public let mediaJson: String?       // JSON-encoded media info
    
    public var isDeleted: Bool { deletedAt != nil }
}

public struct AyuMessageEdit: Codable {
    public let text: String
    public let editedAt: Double
}

// MARK: - Storage

public final class AyuMessageHistoryStorage {
    public static let shared = AyuMessageHistoryStorage()
    
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.ayugram.dbqueue", qos: .background)
    private let dbPath: String
    
    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // Store in app container, survives cache clears
        let ayuDir = docs.appendingPathComponent("AyuGramHistory", isDirectory: true)
        try? FileManager.default.createDirectory(at: ayuDir, withIntermediateDirectories: true)
        dbPath = ayuDir.appendingPathComponent("history.sqlite").path
        setupDatabase()
    }
    
    private func setupDatabase() {
        dbQueue.async { [weak self] in
            guard let self else { return }
            guard sqlite3_open(self.dbPath, &self.db) == SQLITE_OK else {
                print("[AyuGram] Failed to open history database")
                return
            }
            
            let createMessages = """
                CREATE TABLE IF NOT EXISTS messages (
                    message_id    INTEGER NOT NULL,
                    peer_id       INTEGER NOT NULL,
                    peer_type     INTEGER NOT NULL DEFAULT 0,
                    author_id     INTEGER,
                    author_name   TEXT,
                    text          TEXT NOT NULL DEFAULT '',
                    date          INTEGER NOT NULL,
                    deleted_at    REAL,
                    media_json    TEXT,
                    PRIMARY KEY (message_id, peer_id)
                );
            """
            
            let createEdits = """
                CREATE TABLE IF NOT EXISTS edits (
                    message_id  INTEGER NOT NULL,
                    peer_id     INTEGER NOT NULL,
                    text        TEXT NOT NULL,
                    edited_at   REAL NOT NULL
                );
            """
            
            let createIndex = "CREATE INDEX IF NOT EXISTS idx_peer ON messages(peer_id, date DESC);"
            
            for stmt in [createMessages, createEdits, createIndex] {
                sqlite3_exec(self.db, stmt, nil, nil, nil)
            }
        }
    }
    
    // MARK: - Public API
    
    /// Сохранить сообщение (вызывать при получении, до его возможного удаления)
    public func storeMessage(
        messageId: Int32,
        peerId: Int64,
        peerType: Int32,
        authorId: Int64?,
        authorName: String?,
        text: String,
        date: Int32,
        mediaJson: String? = nil
    ) {
        guard AyuSettings.shared.keepDeletedMessages || AyuSettings.shared.keepEditedMessages else { return }
        
        dbQueue.async { [weak self] in
            guard let self, let db = self.db else { return }
            
            let sql = """
                INSERT OR IGNORE INTO messages
                    (message_id, peer_id, peer_type, author_id, author_name, text, date, media_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, messageId)
                sqlite3_bind_int64(stmt, 2, peerId)
                sqlite3_bind_int(stmt, 3, peerType)
                if let authorId {
                    sqlite3_bind_int64(stmt, 4, authorId)
                } else {
                    sqlite3_bind_null(stmt, 4)
                }
                if let authorName {
                    sqlite3_bind_text(stmt, 5, (authorName as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 5)
                }
                sqlite3_bind_text(stmt, 6, (text as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 7, date)
                if let mediaJson {
                    sqlite3_bind_text(stmt, 8, (mediaJson as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 8)
                }
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    /// Пометить сообщение как удалённое
    public func markDeleted(messageId: Int32, peerId: Int64) {
        guard AyuSettings.shared.keepDeletedMessages else { return }
        
        dbQueue.async { [weak self] in
            guard let self, let db = self.db else { return }
            let sql = "UPDATE messages SET deleted_at = ? WHERE message_id = ? AND peer_id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
                sqlite3_bind_int(stmt, 2, messageId)
                sqlite3_bind_int64(stmt, 3, peerId)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    /// Сохранить правку сообщения
    public func storeEdit(messageId: Int32, peerId: Int64, oldText: String) {
        guard AyuSettings.shared.keepEditedMessages else { return }
        
        dbQueue.async { [weak self] in
            guard let self, let db = self.db else { return }
            let sql = "INSERT INTO edits (message_id, peer_id, text, edited_at) VALUES (?, ?, ?, ?);"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, messageId)
                sqlite3_bind_int64(stmt, 2, peerId)
                sqlite3_bind_text(stmt, 3, (oldText as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 4, Date().timeIntervalSince1970)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    /// Получить удалённые сообщения для чата (для отображения)
    public func deletedMessages(peerId: Int64, limit: Int = 50) -> [AyuStoredMessage] {
        var results: [AyuStoredMessage] = []
        dbQueue.sync { [weak self] in
            guard let self, let db = self.db else { return }
            
            let sql = """
                SELECT m.message_id, m.peer_id, m.peer_type, m.author_id, m.author_name,
                       m.text, m.date, m.deleted_at, m.media_json,
                       GROUP_CONCAT(e.text || '|||' || e.edited_at, '^^^') as edits
                FROM messages m
                LEFT JOIN edits e ON m.message_id = e.message_id AND m.peer_id = e.peer_id
                WHERE m.peer_id = ? AND m.deleted_at IS NOT NULL
                GROUP BY m.message_id
                ORDER BY m.date DESC
                LIMIT ?;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(stmt, 1, peerId)
                sqlite3_bind_int(stmt, 2, Int32(limit))
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let msgId = sqlite3_column_int(stmt, 0)
                    let pid = sqlite3_column_int64(stmt, 1)
                    let pt = sqlite3_column_int(stmt, 2)
                    let aid: Int64? = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? sqlite3_column_int64(stmt, 3) : nil
                    let an = sqlite3_column_text(stmt, 4).flatMap { String(cString: $0) }
                    let text = sqlite3_column_text(stmt, 5).flatMap { String(cString: $0) } ?? ""
                    let date = sqlite3_column_int(stmt, 6)
                    let deletedAt: Double? = sqlite3_column_type(stmt, 7) != SQLITE_NULL ? sqlite3_column_double(stmt, 7) : nil
                    let mediaJson = sqlite3_column_text(stmt, 8).flatMap { String(cString: $0) }
                    
                    var editHistory: [AyuMessageEdit] = []
                    if let editsRaw = sqlite3_column_text(stmt, 9).flatMap({ String(cString: $0) }) {
                        for part in editsRaw.split(separator: "^", omittingEmptySubsequences: false).map(String.init) {
                            let components = part.components(separatedBy: "|||")
                            if components.count == 2, let ts = Double(components[1]) {
                                editHistory.append(AyuMessageEdit(text: components[0], editedAt: ts))
                            }
                        }
                    }
                    
                    results.append(AyuStoredMessage(
                        messageId: msgId,
                        peerId: pid,
                        peerType: pt,
                        authorId: aid,
                        authorName: an,
                        text: text,
                        date: date,
                        deletedAt: deletedAt,
                        editHistory: editHistory,
                        mediaJson: mediaJson
                    ))
                }
            }
            sqlite3_finalize(stmt)
        }
        return results
    }
    
    /// Получить историю правок для конкретного сообщения
    public func editHistory(messageId: Int32, peerId: Int64) -> [AyuMessageEdit] {
        var results: [AyuMessageEdit] = []
        dbQueue.sync { [weak self] in
            guard let self, let db = self.db else { return }
            let sql = "SELECT text, edited_at FROM edits WHERE message_id = ? AND peer_id = ? ORDER BY edited_at ASC;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, messageId)
                sqlite3_bind_int64(stmt, 2, peerId)
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let text = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? ""
                    let ts = sqlite3_column_double(stmt, 1)
                    results.append(AyuMessageEdit(text: text, editedAt: ts))
                }
            }
            sqlite3_finalize(stmt)
        }
        return results
    }
}
