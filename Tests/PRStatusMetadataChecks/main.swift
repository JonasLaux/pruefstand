import Foundation

func expect(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError(message)
    }
}

let json = """
{
  "number": 42,
  "title": "Expose review status metadata",
  "url": "https://github.com/acme/app/pull/42",
  "createdAt": "2026-06-04T10:15:00Z",
  "updatedAt": "2026-06-06T18:30:00Z",
  "reviewDecision": "REVIEW_REQUIRED",
  "additions": 21,
  "deletions": 4,
  "changedFiles": 3,
  "repository": { "nameWithOwner": "acme/app" },
  "author": { "login": "alice", "avatarUrl": null },
  "comments": { "totalCount": 3 },
  "reviewThreads": {
    "nodes": [
      {
        "isResolved": false,
        "comments": {
          "totalCount": 2,
          "nodes": [{ "author": { "login": "coderabbitai" } }]
        }
      },
      {
        "isResolved": false,
        "comments": {
          "totalCount": 1,
          "nodes": [{ "author": { "login": "codex" } }]
        }
      },
      {
        "isResolved": false,
        "comments": {
          "totalCount": 1,
          "nodes": [{ "author": { "login": "coderabbitai" } }]
        }
      },
      {
        "isResolved": true,
        "comments": {
          "totalCount": 4,
          "nodes": [{ "author": { "login": "alice" } }]
        }
      }
    ]
  },
  "labels": { "nodes": [] },
  "commits": {
    "nodes": [
      {
        "commit": {
          "statusCheckRollup": {
            "state": "FAILURE",
            "contexts": {
              "nodes": [
                {
                  "__typename": "CheckRun",
                  "name": "Unit tests",
                  "status": "COMPLETED",
                  "conclusion": "FAILURE"
                },
                {
                  "__typename": "CheckRun",
                  "name": "Lint",
                  "status": "COMPLETED",
                  "conclusion": "SUCCESS"
                },
                {
                  "__typename": "StatusContext",
                  "context": "deploy preview",
                  "state": "ERROR"
                },
                {
                  "__typename": "StatusContext",
                  "context": "coverage",
                  "state": "SUCCESS"
                }
              ]
            }
          }
        }
      }
    ]
  }
}
"""

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let node = try decoder.decode(Node.self, from: Data(json.utf8))
let pr = node.toPullRequest()!

expect(pr.commentCount == 3, "issue comment count should remain available")
expect(pr.reviewCommentCount == 8, "review comments should be counted from review threads")
expect(pr.totalCommentCount == 11, "display comment count should include issue and review comments")
expect(pr.unresolvedReviewThreadCount == 3, "unresolved review thread count")
expect(
    pr.unresolvedReviewThreadsByAuthor == [
        ReviewThreadAuthorCount(author: "coderabbitai", count: 2),
        ReviewThreadAuthorCount(author: "codex", count: 1)
    ],
    "unresolved review thread authors should be grouped and sorted"
)
expect(
    pr.unresolvedReviewThreadsTooltip == "Unresolved review comments\n- 2 coderabbitai\n- 1 codex",
    "unresolved tooltip should list grouped authors"
)
expect(
    pr.failedCIChecks == [
        FailedCICheck(name: "Unit tests"),
        FailedCICheck(name: "deploy preview")
    ],
    "failed CI contexts should be captured"
)
expect(
    pr.failedCIChecksTooltip == "Failed CI pipelines\n- Unit tests\n- deploy preview",
    "failed CI tooltip should list failed contexts"
)
