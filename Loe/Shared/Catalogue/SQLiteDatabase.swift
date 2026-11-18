import Foundation
import SQLite3

/// A read-only SQLite connection. Owned by one actor, never shared.
nonisolated final class SQLiteDatabase {
    enum Value {
        case text(String)
        case integer(Int)
    }

    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    struct Row {
        fileprivate let statement: OpaquePointer

        func text(_ column: Int32) -> String? {
            sqlite3_column_text(statement, column).map { String(cString: $0) }
        }

        func integer(_ column: Int32) -> Int? {
            sqlite3_column_type(statement, column) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(statement, column))
        }

        func double(_ column: Int32) -> Double {
            sqlite3_column_double(statement, column)
        }
    }

    private let handle: OpaquePointer

    init(readOnly url: URL) throws {
        var connection: OpaquePointer?
        let status = sqlite3_open_v2(url.path, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        guard status == SQLITE_OK, let connection else {
            let message = connection.map { String(cString: sqlite3_errmsg($0)) } ?? "out of memory"
            sqlite3_close(connection)
            throw Failure(description: message)
        }
        handle = connection
    }

    deinit {
        sqlite3_close(handle)
    }

    func rows<T>(_ sql: String, _ values: [Value] = [], map: (Row) -> T) throws -> [T] {
        var prepared: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &prepared, nil) == SQLITE_OK, let statement = prepared else {
            throw Failure(description: String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(statement) }
        // SQLite copies the text, because Swift's buffer only lives for the call.
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case .text(let text): sqlite3_bind_text(statement, position, text, -1, transient)
            case .integer(let number): sqlite3_bind_int64(statement, position, Int64(number))
            }
        }
        var results: [T] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW: results.append(map(Row(statement: statement)))
            case SQLITE_DONE: return results
            default: throw Failure(description: String(cString: sqlite3_errmsg(handle)))
            }
        }
    }
}
