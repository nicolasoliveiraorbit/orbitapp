//
//  OrbitLogger.swift
//  Orbit
//
//  Created for error logging and debugging.
//

import Foundation

final class OrbitLogger: @unchecked Sendable {

    nonisolated static let shared = OrbitLogger()

    private let logQueue = DispatchQueue(label: "com.orbit.logger", qos: .utility)
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private nonisolated var logFileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Orbit/Logs/orbit_debug.log")
    }

    private init() {
        try? FileManager.default.createDirectory(
            at: logFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    // MARK: - Public

    nonisolated func log(_ message: String, level: String = "INFO") {
        let timestamp = dateFormatter.string(from: Date())
        let entry = "[\(timestamp)] [\(level)] \(message)\n"

        logQueue.async { [self] in
            self.appendToFile(entry)
        }
    }

    nonisolated func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        let entry = "[\(timestamp)] [ERROR] \(filename):\(line) \(function) | \(message)\n"

        logQueue.async { [self] in
            self.appendToFile(entry)
        }
    }

    nonisolated func warn(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let entry = "[\(timestamp)] [WARN]  \(message)\n"

        logQueue.async { [self] in
            self.appendToFile(entry)
        }
    }

    nonisolated func clearLog() {
        logQueue.async { [self] in
            try? "".data(using: .utf8)?.write(to: self.logFileURL, options: .atomic)
        }
    }

    nonisolated func readLog() -> String? {
        try? String(contentsOf: logFileURL, encoding: .utf8)
    }

    nonisolated func logFilePath() -> String {
        logFileURL.path
    }

    // MARK: - Private

    private func appendToFile(_ text: String) {
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let fh = FileHandle(forWritingAtPath: logFileURL.path) {
                fh.seekToEndOfFile()
                if let data = text.data(using: .utf8) {
                    fh.write(data)
                }
                fh.closeFile()
            }
        } else {
            try? text.data(using: .utf8)?.write(to: logFileURL, options: .atomic)
        }
    }
}
