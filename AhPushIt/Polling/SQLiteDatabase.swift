import Foundation
import SQLite3

final class SQLiteDatabase {
    private var db: OpaquePointer?
    let path: String

    enum DatabaseError: LocalizedError {
        case openFailed(String)
        case queryFailed(String)
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .openFailed(let msg): return "Failed to open database: \(msg)"
            case .queryFailed(let msg): return "Query failed: \(msg)"
            case .permissionDenied: return "Permission denied. Grant Full Disk Access in System Settings > Privacy & Security."
            }
        }
    }

    init(path: String) throws {
        self.path = path
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(path, &db, flags, nil)
        if result != SQLITE_OK {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(db)
            db = nil
            if result == SQLITE_CANTOPEN || result == SQLITE_AUTH {
                throw DatabaseError.permissionDenied
            }
            throw DatabaseError.openFailed(msg)
        }
        sqlite3_busy_timeout(db, 5000)
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func fetchRecord(offset: Int) throws -> NotificationRecord? {
        let sql = "SELECT rec_id, data, request_date, delivered_date FROM record ORDER BY rec_id DESC LIMIT 1 OFFSET ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(offset))

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        let recID = sqlite3_column_int64(stmt, 0)

        let dataLength = sqlite3_column_bytes(stmt, 1)
        var data = Data()
        if let dataPointer = sqlite3_column_blob(stmt, 1) {
            data = Data(bytes: dataPointer, count: Int(dataLength))
        }

        let requestDate: Double? = sqlite3_column_type(stmt, 2) != SQLITE_NULL
            ? sqlite3_column_double(stmt, 2) : nil
        let deliveredDate: Double? = sqlite3_column_type(stmt, 3) != SQLITE_NULL
            ? sqlite3_column_double(stmt, 3) : nil

        let timestamp = deliveredDate ?? requestDate ?? 0

        return NotificationRecord(
            id: recID,
            data: data,
            requestDate: requestDate,
            deliveredDate: deliveredDate,
            timestamp: timestamp
        )
    }

    func fetchDistinctBundleIDs() throws -> [String] {
        let sql = "SELECT DISTINCT data FROM record ORDER BY rec_id DESC LIMIT 500"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var bundleIDs = Set<String>()
        while sqlite3_step(stmt) == SQLITE_ROW {
            let dataLength = sqlite3_column_bytes(stmt, 0)
            if let dataPointer = sqlite3_column_blob(stmt, 0) {
                let data = Data(bytes: dataPointer, count: Int(dataLength))
                if let parsed = PlistParser.parseBundleIdentifier(from: data) {
                    bundleIDs.insert(parsed)
                }
            }
        }
        return bundleIDs.sorted()
    }

    static func databasePath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Group Containers/group.com.apple.usernoted/db2/db"
    }

    static func checkAccess() -> Bool {
        let path = databasePath()
        guard FileManager.default.fileExists(atPath: path) else { return false }
        // Actually try opening — isReadableFile can lie about Full Disk Access
        guard let fh = FileHandle(forReadingAtPath: path) else { return false }
        fh.closeFile()
        return true
    }
}
