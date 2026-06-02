# Pruefstand

A small macOS menu bar app for tracking GitHub pull requests that need your review.

It uses the locally authenticated `gh` CLI, polls for open review requests, shows them in a popover, and can send native notifications for newly surfaced PRs.

## Build

```sh
swift build
```

To assemble a local `.app` bundle:

```sh
./scripts/bundle.sh
```
