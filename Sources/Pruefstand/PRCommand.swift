import Foundation
import Darwin

struct PRCommandError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

enum PRCommandContext {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let placeholders: [String: String] = [
        "title": "PR_TITLE",
        "url": "PR_URL",
        "repo": "PR_REPO",
        "number": "PR_NUMBER",
        "author": "PR_AUTHOR",
        "created_at": "PR_CREATED_AT",
        "updated_at": "PR_UPDATED_AT",
        "age_days": "PR_AGE_DAYS",
        "review_decision": "PR_REVIEW_DECISION",
        "comment_count": "PR_COMMENT_COUNT",
        "ci_state": "PR_CI_STATE",
        "additions": "PR_ADDITIONS",
        "deletions": "PR_DELETIONS",
        "changed_files": "PR_CHANGED_FILES",
        "labels": "PR_LABELS"
    ]

    static func environment(for pr: PullRequest, now: Date = Date()) -> [String: String] {
        [
            "PR_TITLE": pr.title,
            "PR_URL": pr.url,
            "PR_REPO": pr.repo,
            "PR_NUMBER": String(pr.number),
            "PR_AUTHOR": pr.authorLogin,
            "PR_CREATED_AT": isoFormatter.string(from: pr.createdAt),
            "PR_UPDATED_AT": isoFormatter.string(from: pr.updatedAt),
            "PR_AGE_DAYS": String(ageDays(from: pr.createdAt, to: now)),
            "PR_REVIEW_DECISION": pr.reviewDecision ?? "",
            "PR_COMMENT_COUNT": String(pr.commentCount),
            "PR_CI_STATE": pr.ci.rawValue,
            "PR_ADDITIONS": String(pr.diffStats.additions),
            "PR_DELETIONS": String(pr.diffStats.deletions),
            "PR_CHANGED_FILES": String(pr.diffStats.changedFiles),
            "PR_LABELS": pr.labels.map(\.name).joined(separator: ",")
        ]
    }

    static func interpolate(_ command: String, environment: [String: String]) -> String {
        var rendered = command
        for (placeholder, key) in placeholders {
            guard let value = environment[key] else { continue }
            rendered = rendered.replacingOccurrences(of: "{\(placeholder)}", with: shellQuote(value))
        }
        return rendered
    }

    static func shellQuote(_ value: String) -> String {
        guard !value.isEmpty else { return "''" }
        return "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private static func ageDays(from createdAt: Date, to now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(createdAt) / 86_400))
    }
}

actor PRCommandRunner {
    func run(command: String, for pr: PullRequest, timeoutSeconds: TimeInterval = 120) async throws {
        let commandEnvironment = PRCommandContext.environment(for: pr)
        let renderedCommand = PRCommandContext.interpolate(command, environment: commandEnvironment)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", renderedCommand]
        process.environment = environment(adding: commandEnvironment)

        let outputFiles = try makeOutputFiles()
        process.standardOutput = outputFiles.stdoutHandle
        process.standardError = outputFiles.stderrHandle

        do {
            try process.run()
        } catch {
            outputFiles.closeAndRemove()
            throw PRCommandError(message: error.localizedDescription)
        }

        let timedOut = await waitForExit(process, timeoutSeconds: timeoutSeconds)
        if timedOut {
            process.terminate()
            if await waitForExit(process, timeoutSeconds: 1) {
                Darwin.kill(process.processIdentifier, SIGKILL)
                _ = await waitForExit(process, timeoutSeconds: 1)
            }
        }

        outputFiles.close()
        let out = read(outputFiles.stdoutURL)
        let err = read(outputFiles.stderrURL)
        outputFiles.remove()

        if timedOut {
            throw PRCommandError(message: "Command timed out after \(Int(timeoutSeconds))s")
        }

        guard process.terminationStatus == 0 else {
            throw PRCommandError(
                message: "Command failed (exit \(process.terminationStatus)): \(Self.outputSummary(stdout: out, stderr: err))"
            )
        }
    }

    private func environment(adding commandEnvironment: [String: String]) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extraPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        env["PATH"] = env["PATH"].map { "\(extraPath):\($0)" } ?? extraPath
        for (key, value) in commandEnvironment {
            env[key] = value
        }
        return env
    }

    private func waitForExit(_ process: Process, timeoutSeconds: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning {
            if Date() >= deadline {
                return true
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    private func makeOutputFiles() throws -> CommandOutputFiles {
        let directory = FileManager.default.temporaryDirectory
        let base = "pruefstand-command-\(UUID().uuidString)"
        let stdoutURL = directory.appendingPathComponent("\(base)-stdout.txt")
        let stderrURL = directory.appendingPathComponent("\(base)-stderr.txt")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        return CommandOutputFiles(
            stdoutURL: stdoutURL,
            stderrURL: stderrURL,
            stdoutHandle: try FileHandle(forWritingTo: stdoutURL),
            stderrHandle: try FileHandle(forWritingTo: stderrURL)
        )
    }

    private func read(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private static func outputSummary(stdout: String, stderr: String) -> String {
        let preferred = stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? stdout : stderr
        let oneLine = preferred
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .joined(separator: " ")
        guard !oneLine.isEmpty else { return "No output" }
        if oneLine.count <= 240 { return oneLine }
        return String(oneLine.prefix(237)) + "..."
    }
}

private struct CommandOutputFiles {
    let stdoutURL: URL
    let stderrURL: URL
    let stdoutHandle: FileHandle
    let stderrHandle: FileHandle

    func close() {
        try? stdoutHandle.close()
        try? stderrHandle.close()
    }

    func remove() {
        try? FileManager.default.removeItem(at: stdoutURL)
        try? FileManager.default.removeItem(at: stderrURL)
    }

    func closeAndRemove() {
        close()
        remove()
    }
}
