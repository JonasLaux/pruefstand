extension PullRequest {
    var ignoreKey: String {
        PRIgnoreKey.make(repo: repo, number: number)
    }
}

extension Settings {
    func ignore(pr: PullRequest) {
        ignore(repo: pr.repo, number: pr.number)
    }

    func isIgnored(_ pr: PullRequest) -> Bool {
        ignoredPRKeys.contains(pr.ignoreKey)
    }
}
