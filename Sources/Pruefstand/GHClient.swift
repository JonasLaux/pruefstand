import Foundation

enum PullRequestSearchQuery {
    static func base(includeDrafts: Bool) -> String {
        includeDrafts ? "is:open is:pr" : "is:open is:pr -is:draft"
    }

    static func reviewQueries(direct: Bool, teams: Bool, mentioned: Bool, includeDrafts: Bool) -> [String] {
        let base = base(includeDrafts: includeDrafts)
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
        return queries
    }

    static func watchedContributorQueries(
        repos: Set<String>,
        contributors: [String],
        includeDrafts: Bool
    ) -> [String] {
        let base = base(includeDrafts: includeDrafts)
        let normalizedRepos = repos.compactMap(normalizedRepo).sorted()
        let normalizedLogins = normalizedLogins(from: contributors)

        if normalizedRepos.isEmpty {
            return normalizedLogins.map { "\(base) author:\($0)" }
        }

        return normalizedRepos.flatMap { repo in
            normalizedLogins.map { "\(base) repo:\(repo) author:\($0)" }
        }
    }

    static func authoredByMeQuery(includeDrafts: Bool) -> String {
        "\(base(includeDrafts: includeDrafts)) author:@me"
    }

    private static func normalizedLogins(from logins: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for login in logins {
            let normalized = login
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingPrefix("@")
                .lowercased()
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
            result.append(normalized)
        }
        return result.sorted()
    }

    private static func normalizedRepo(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let withoutHost = trimmed
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: "http://github.com/", with: "")
        let parts = withoutHost
            .split(separator: "/")
            .prefix(2)
            .map(String.init)

        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }) else { return nil }
        return parts.joined(separator: "/")
    }
}

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
              totalCount
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

    /// Fetch authored PRs plus review-needed and watched-contributor PRs.
    func fetch(
        direct: Bool,
        teams: Bool,
        mentioned: Bool,
        includeDrafts: Bool,
        watchedRepos: Set<String>,
        watchedContributors: [String]
    ) async throws -> PRFetchResult {
        let ghPath = try resolveGH()
        let myPullRequests = try runSearch(ghPath: ghPath, q: PullRequestSearchQuery.authoredByMeQuery(includeDrafts: includeDrafts))
        var queries = PullRequestSearchQuery.reviewQueries(
            direct: direct,
            teams: teams,
            mentioned: mentioned,
            includeDrafts: includeDrafts
        )
        queries.append(
            contentsOf: PullRequestSearchQuery.watchedContributorQueries(
                repos: watchedRepos,
                contributors: watchedContributors,
                includeDrafts: includeDrafts
            )
        )
        if queries.isEmpty {
            queries.append("\(PullRequestSearchQuery.base(includeDrafts: includeDrafts)) review-requested:@me")
        }

        var byId: [String: PullRequest] = [:]
        for q in dedupe(queries) {
            for pr in try runSearch(ghPath: ghPath, q: q) {
                byId[pr.id] = pr
            }
        }
        let contributorCandidates = fetchContributorCandidates(ghPath: ghPath, repos: watchedRepos)
        return PRFetchResult(
            myPullRequests: myPullRequests,
            reviewNeeded: Array(byId.values),
            contributorCandidates: contributorCandidates
        )
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

    private func fetchContributorCandidates(ghPath: String, repos: Set<String>) -> [RepositoryContributor] {
        repos.sorted().flatMap { repo -> [RepositoryContributor] in
            (try? runContributorSearch(ghPath: ghPath, repo: repo)) ?? []
        }
    }

    private func runContributorSearch(ghPath: String, repo: String) throws -> [RepositoryContributor] {
        let parts = repo.split(separator: "/")
        guard parts.count == 2 else { return [] }

        let (out, err, status) = try run(
            ghPath: ghPath,
            args: ["api", "--method", "GET", "repos/\(repo)/contributors", "-f", "per_page=100"]
        )

        guard status == 0 else {
            let detail = err.isEmpty ? out : err
            throw GHError(message: "gh failed (exit \(status)): \(detail.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        guard let data = out.data(using: .utf8), !data.isEmpty else {
            return []
        }

        let nodes = try JSONDecoder().decode([RESTContributor].self, from: data)
        return nodes.compactMap { node in
            guard let login = node.login?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !login.isEmpty else {
                return nil
            }
            return RepositoryContributor(
                repo: repo,
                login: login.lowercased(),
                contributions: node.contributions ?? 0
            )
        }
    }

    private func dedupe(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
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

private struct RESTContributor: Decodable {
    let login: String?
    let contributions: Int?
}

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
