import Dispatch
import Foundation

func expect(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError(message)
    }
}

let formatter = ISO8601DateFormatter()

func samplePR() -> PullRequest {
    PullRequest(
        id: "https://github.com/acme/app/pull/42",
        number: 42,
        title: "Tighten \"review\" flow",
        url: "https://github.com/acme/app/pull/42",
        repo: "acme/app",
        authorLogin: "alice",
        authorAvatarURL: nil,
        createdAt: formatter.date(from: "2026-06-04T10:15:00Z")!,
        updatedAt: formatter.date(from: "2026-06-06T18:30:00Z")!,
        reviewDecision: "REVIEW_REQUIRED",
        commentCount: 7,
        ci: .success,
        labels: [PRLabel(name: "needs-review", colorHex: "fbca04")],
        diffStats: PRDiffStats(additions: 428, deletions: 91, changedFiles: 12)
    )
}

func runChecks() async {
    let pr = samplePR()
    let runner = PRCommandRunner()
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("pruefstand-command-runner-\(UUID().uuidString).txt")

    do {
        let pathArg = PRCommandContext.shellQuote(outputURL.path)
        try await runner.run(
            command: "printf '%s|%s|%s' \"$PR_TITLE\" \"$PR_URL\" {number} > \(pathArg)",
            for: pr,
            timeoutSeconds: 5
        )
        let output = try String(contentsOf: outputURL, encoding: .utf8)
        expect(
            output == "Tighten \"review\" flow|https://github.com/acme/app/pull/42|42",
            "runner should expose env vars and placeholders"
        )
        try? FileManager.default.removeItem(at: outputURL)
    } catch {
        fatalError("runner success path failed: \(error)")
    }

    do {
        try await runner.run(command: "echo broken >&2; exit 7", for: pr, timeoutSeconds: 5)
        fatalError("failing command should throw")
    } catch let error as PRCommandError {
        expect(error.message == "Command failed (exit 7): broken", "failing command message")
    } catch {
        fatalError("unexpected error type: \(error)")
    }
}

Task {
    await runChecks()
    exit(0)
}

dispatchMain()
