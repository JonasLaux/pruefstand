import Foundation

struct GHError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Talks to the local `gh` CLI. Runs off the main actor.
actor GHClient {

    private static let graphQL = """
    query($q: String!) {
      search(query: $q, type: ISSUE, first: 50) {
        nodes {
          ... on PullRequest {
            number
            title
            url
            createdAt
            updatedAt
            reviewDecision
            additions
            deletions
            changedFiles
            repository { nameWithOwner }
            author { login avatarUrl }
            comments { totalCount }
            reviewThreads(first: 100) {
              nodes {
                isResolved
                comments(first: 1) {
                  totalCount
                  nodes { author { login } }
                }
              }
            }
            labels(first: 50) {
              nodes { name color }
            }
            commits(last: 1) {
              nodes {
                commit {
                  statusCheckRollup {
                    state
                    contexts(first: 100) {
                      nodes {
                        __typename
                        ... on CheckRun {
                          name
                          status
                          conclusion
                        }
                        ... on StatusContext {
                          context
                          state
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    """

    /// Fetch review-needed PRs for the given toggles, merged and deduped by id.
    func fetch(direct: Bool, teams: Bool, mentioned: Bool) async throws -> [PullRequest] {
        let ghPath = try resolveGH()
        let base = "is:open is:pr"
        var queries: [String] = []

        // Teams is a superset of direct; only fall back to the direct-only
        // qualifier when teams is off.
        if teams {
            queries.append("\(base) review-requested:@me")
        } else if direct {
            queries.append("\(base) user-review-requested:@me")
        }
        if mentioned {
            queries.append("\(base) mentions:@me")
        }
        if queries.isEmpty {
            queries.append("\(base) review-requested:@me")
        }

        var byId: [String: PullRequest] = [:]
        for q in queries {
            for pr in try runSearch(ghPath: ghPath, q: q) {
                byId[pr.id] = pr
            }
        }
        return Array(byId.values)
    }

    func perform(action: PRAction, onURL url: String) async throws {
        let ghPath = try resolveGH()
        let (out, err, status) = try run(ghPath: ghPath, args: action.ghArguments(for: url))
        guard status == 0 else {
            let detail = err.isEmpty ? out : err
            throw GHError(message: "gh failed (exit \(status)): \(detail.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    // MARK: - gh process

    private func runSearch(ghPath: String, q: String) throws -> [PullRequest] {
        let (out, err, status) = try run(
            ghPath: ghPath,
            args: ["api", "graphql", "-f", "query=\(Self.graphQL)", "-f", "q=\(q)"]
        )

        guard status == 0 else {
            let detail = err.isEmpty ? out : err
            if detail.lowercased().contains("auth") || detail.lowercased().contains("logged in") {
                throw GHError(message: "Not authenticated. Run `gh auth login`.")
            }
            throw GHError(message: "gh failed (exit \(status)): \(detail.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        guard let data = out.data(using: .utf8) else {
            throw GHError(message: "gh returned non-UTF8 output")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let resp: GQLResponse
        do {
            resp = try decoder.decode(GQLResponse.self, from: data)
        } catch {
            throw GHError(message: "Failed to decode gh response: \(error.localizedDescription)")
        }

        if let errors = resp.errors, !errors.isEmpty, resp.data == nil {
            throw GHError(message: errors.map(\.message).joined(separator: "; "))
        }

        return resp.data?.search.nodes.compactMap { $0.toPullRequest() } ?? []
    }

    /// Run a process, returning (stdout, stderr, exitCode).
    private func run(ghPath: String, args: [String]) throws -> (String, String, Int32) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ghPath)
        proc.arguments = args

        var env = ProcessInfo.processInfo.environment
        // GUI apps inherit a minimal PATH; ensure gh can find git and itself.
        let extra = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        env["PATH"] = env["PATH"].map { "\(extra):\($0)" } ?? extra
        proc.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        try proc.run()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        return (
            String(data: outData, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? "",
            proc.terminationStatus
        )
    }

    /// Locate the `gh` binary.
    private func resolveGH() throws -> String {
        let fm = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh"
        ]
        for c in candidates where fm.isExecutableFile(atPath: c) {
            return c
        }
        // Last resort: ask the login shell where gh lives.
        if let viaWhich = try? whichGH(), fm.isExecutableFile(atPath: viaWhich) {
            return viaWhich
        }
        throw GHError(message: "Could not find the `gh` CLI. Install it: brew install gh")
    }

    private func whichGH() throws -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = ["gh"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try proc.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (path?.isEmpty == false) ? path : nil
    }
}
