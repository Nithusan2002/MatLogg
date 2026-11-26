import Foundation
import SQLite3

nonisolated enum SQLiteReadValue {
    case text(String), number(Double), integer(Int), null
}

nonisolated struct SQLiteReadQuery {
    let sql: String
    let values: [SQLiteReadValue]
}

/// A checked statement scoped to one LocalStore queue operation. Never escapes the read closure.
nonisolated final class SQLiteReadStatement {
    private var statement: OpaquePointer?
    private let diagnostic: (LocalStoreDiagnostic) -> Void
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(database: OpaquePointer?, sql: String, values: [SQLiteReadValue], diagnostic: @escaping (LocalStoreDiagnostic) -> Void = { _ in }) throws {
        self.diagnostic = diagnostic
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            statement = nil
            throw LocalStoreError.sqlite("Kunne ikke lese lokale data.")
        }
        do {
            guard sqlite3_bind_parameter_count(statement) == values.count else { throw invalidData() }
            for (offset, value) in values.enumerated() {
                let index = Int32(offset + 1)
                let status: Int32
                switch value {
                case .text(let text): status = sqlite3_bind_text(statement, index, text, -1, Self.transient)
                case .number(let number):
                    guard number.isFinite else { throw invalidData() }
                    status = sqlite3_bind_double(statement, index, number)
                case .integer(let integer): status = sqlite3_bind_int64(statement, index, Int64(integer))
                case .null: status = sqlite3_bind_null(statement, index)
                }
                guard status == SQLITE_OK else { throw LocalStoreError.sqlite("Kunne ikke lese lokale data.") }
            }
        } catch {
            sqlite3_finalize(statement)
            statement = nil
            throw error
        }
    }

    deinit { sqlite3_finalize(statement) }

    func next() throws -> Bool {
        switch sqlite3_step(statement) {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw LocalStoreError.sqlite("Kunne ikke lese lokale data.")
        }
    }

    func text(_ column: Int32) throws -> String {
        guard sqlite3_column_type(statement, column) == SQLITE_TEXT,
              let text = sqlite3_column_text(statement, column) else { throw invalidData() }
        return String(cString: text)
    }

    func uuid(_ column: Int32) throws -> UUID {
        guard let id = UUID(uuidString: try text(column)) else { throw invalidData() }
        return id
    }

    func number(_ column: Int32) throws -> Double {
        let kind = sqlite3_column_type(statement, column)
        guard kind == SQLITE_INTEGER || kind == SQLITE_FLOAT else { throw invalidData() }
        let value = sqlite3_column_double(statement, column)
        guard value.isFinite else { throw invalidData() }
        return value
    }

    func decode<T: Decodable>(_ type: T.Type, column: Int32 = 0) throws -> T {
        guard let bytes = sqlite3_column_blob(statement, column) else { throw invalidData() }
        let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, column)))
        do { return try JSONDecoder().decode(type, from: data) }
        catch {
            let name = String(describing: type).replacingOccurrences(of: "([a-z])([A-Z])", with: "$1_$2", options: .regularExpression).lowercased()
            diagnostic(.decodingFailed(entity: name, reason: String(describing: Swift.type(of: error))))
            throw invalidData()
        }
    }

    private func invalidData() -> LocalStoreError {
        .invalidStoredData("Kunne ikke lese lagrede data. Dataene er ikke slettet.")
    }
}
