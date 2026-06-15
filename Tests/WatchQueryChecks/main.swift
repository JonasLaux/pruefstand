import Foundation

func expect(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError(message)
    }
}

let noDraftBase = PullRequestSearchQuery.base(includeDrafts: false)
expect(noDraftBase == "is:open is:pr -is:draft", "base query should exclude drafts by default")

let draftBase = PullRequestSearchQuery.base(includeDrafts: true)
expect(draftBase == "is:open is:pr", "base query should include drafts when requested")

let teamQueries = PullRequestSearchQuery.reviewQueries(
    direct: false,
    teams: true,
    mentioned: false,
    includeDrafts: false
)
expect(teamQueries == ["is:open is:pr -is:draft review-requested:@me"], "team query should include team review requests")

let directMentionQueries = PullRequestSearchQuery.reviewQueries(
    direct: true,
    teams: false,
    mentioned: true,
    includeDrafts: true
)
expect(
    directMentionQueries == [
        "is:open is:pr user-review-requested:@me",
        "is:open is:pr mentions:@me"
    ],
    "direct and mentioned queries should preserve requested scopes"
)

let contributorQueries = PullRequestSearchQuery.watchedContributorQueries(
    repos: ["bobsled-inc/bobsled-nl-sql", "bobsled-inc/bobsled-ai"],
    contributors: [" @Alice ", "bob", "alice"],
    includeDrafts: false
)
expect(
    contributorQueries == [
        "is:open is:pr -is:draft repo:bobsled-inc/bobsled-ai author:alice",
        "is:open is:pr -is:draft repo:bobsled-inc/bobsled-ai author:bob",
        "is:open is:pr -is:draft repo:bobsled-inc/bobsled-nl-sql author:alice",
        "is:open is:pr -is:draft repo:bobsled-inc/bobsled-nl-sql author:bob"
    ],
    "watched contributor queries should expand stable repo/login combinations"
)

let globalContributorQueries = PullRequestSearchQuery.watchedContributorQueries(
    repos: [],
    contributors: ["carol"],
    includeDrafts: true
)
expect(
    globalContributorQueries == ["is:open is:pr author:carol"],
    "empty repo scope should watch contributors across all accessible repos"
)
