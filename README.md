# print-github-tags

Tiny command to fetch repository tags or releases from GitHub

[![CI/CD](https://github.com/dceoy/print-github-tags/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/print-github-tags/actions/workflows/ci.yml)

## Installation

This command depends on curl. jq is additionally required only when using `--cooldown`.

```sh
$ git clone https://github.com/dceoy/print-github-tags.git
$ cp -a print-github-tags/print-github-tags /path/to/bin  # a path in ${PATH}
```

## Example

Fetch the tags of [`curl/curl`](https://github.com/curl/curl) from GitHub.

```sh
$ print-github-tags curl/curl
```

Fetch the releases.

```sh
$ print-github-tags --release curl/curl
```

Fetch the latest release.

```sh
$ print-github-tags --release --latest curl/curl
```

Fetch the URL for the source code of the latest release.

```sh
$ print-github-tags --release --latest --tar curl/curl
```

Fetch releases older than a one-week cooldown.

```sh
$ print-github-tags --release --cooldown 1w curl/curl
```

## Notes

- Tag and release list commands request up to 100 items from the GitHub API.
- `--latest --release` uses GitHub's latest-release API.
- `--latest` without `--release` prints the first tag returned by the GitHub tags API; it does not perform semantic-version sorting.
- `--cooldown <duration>` requires `--release` and accepts a positive integer followed by `h` (hours), `d` (days), or `w` (weeks).
- Cooldown filtering uses `published_at` and includes releases published at or before the cutoff. Releases with no `published_at` are excluded.
- `--release --latest --cooldown` uses the release-list API and selects the newest eligible release; no eligible releases produce no output and a successful exit.
- `--tar` and `--zip` format the releases after cooldown filtering.

## Usage

```sh
$ print-github-tags --help
Tiny command to fetch repository tags or releases from GitHub

Usage:
  print-github-tags -h|--help
  print-github-tags -v|--version
  print-github-tags [--release] [--latest] [--tar|--zip] <owner>/<repo>

Options:
  -h, --help        Print usage
  -v, --version     Print version information
  --release         Print only releases
  --latest          Print the latest release, or the first tag returned by the GitHub API
  --cooldown        Exclude releases published within the given Nh, Nd, or Nw cooldown
  --tar             Print tar file URLs (.tar.gz)
  --zip             Print zip file URLs (.zip)

Example:
  $ print-github-tags --release --latest --tar curl/curl
```
