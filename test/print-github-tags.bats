#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  SCRIPT="${REPO_ROOT}/print-github-tags"
  TEST_BIN="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "${TEST_BIN}"
  export PATH="${TEST_BIN}:${PATH}"
}

mock_date() {
  cat > "${TEST_BIN}/date" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" = '-u +%s' ]]; then
  printf '%s\n' '1754956800'
else
  echo "unexpected arguments: $*" >&2
  exit 64
fi
MOCK
  chmod +x "${TEST_BIN}/date"
}

expected_version_output() {
  local command_name command_version

  command_name="$(grep '^COMMAND_NAME=' "${SCRIPT}" | cut -d "'" -f 2)"
  command_version="$(grep '^COMMAND_VERSION=' "${SCRIPT}" | cut -d "'" -f 2)"

  printf '%s: %s\n' "${command_name}" "${command_version}"
}

mock_curl() {
  cat > "${TEST_BIN}/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

url=''
for arg in "$@"; do
  url="${arg}"
done

case "${url}" in
  'https://api.github.com/repos/curl/curl/tags?per_page=100' )
    cat <<'JSON'
[
  {
    "name": "curl-8_14_1",
    "zipball_url": "https://api.github.com/repos/curl/curl/zipball/refs/tags/curl-8_14_1",
    "tarball_url": "https://api.github.com/repos/curl/curl/tarball/refs/tags/curl-8_14_1"
  },
  {
    "name": "curl-8_14_0",
    "zipball_url": "https://api.github.com/repos/curl/curl/zipball/refs/tags/curl-8_14_0",
    "tarball_url": "https://api.github.com/repos/curl/curl/tarball/refs/tags/curl-8_14_0"
  }
]
JSON
    ;;
  'https://api.github.com/repos/curl/curl/releases?per_page=100' | \
  'https://api.github.com/repos/curl/curl/releases?per_page=100&page=1' )
    cat <<'JSON'
[
  {
    "tag_name": "curl-8_13_0",
    "name": "curl 8.13.0",
    "published_at": "2025-08-05T00:00:00Z",
    "created_at": "2025-08-10T00:00:00Z",
    "draft": false,
    "prerelease": false
  },
  {
    "tag_name": "curl-8_14_0",
    "name": "curl 8.14.0",
    "published_at": "2025-08-11T00:00:00Z",
    "created_at": "2025-08-09T00:00:00Z",
    "draft": false,
    "prerelease": false
  },
  {
    "tag_name": "curl-8_14_rc1",
    "name": "curl 8.14.1 RC1",
    "published_at": "2025-08-10T00:00:00Z",
    "created_at": "2025-08-12T00:00:00Z",
    "draft": false,
    "prerelease": true
  },
  {
    "tag_name": "curl-8_14_draft",
    "name": "curl 8.14.1 draft",
    "published_at": "2025-08-09T00:00:00Z",
    "created_at": "2025-08-13T00:00:00Z",
    "draft": true,
    "prerelease": false
  },
  {
    "tag_name": "curl-8_14_1",
    "name": "curl 8.14.1",
    "published_at": "2025-08-11T00:00:01Z",
    "created_at": "2025-08-14T00:00:00Z",
    "draft": false,
    "prerelease": false
  },
  {
    "tag_name": "curl-8_12_0",
    "name": "curl 8.12.0",
    "published_at": null,
    "created_at": "2025-08-04T00:00:00Z",
    "draft": false,
    "prerelease": false
  }
]
JSON
    ;;
  'https://api.github.com/repos/curl/curl/releases/latest' )
    cat <<'JSON'
{
  "tag_name": "curl-8_14_1",
  "name": "curl 8.14.1"
}
JSON
    ;;
  * )
    echo "unexpected URL: ${url}" >&2
    exit 64
    ;;
esac
MOCK
  chmod +x "${TEST_BIN}/curl"
}

mock_paginated_curl() {
  cat > "${TEST_BIN}/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

url=''
for arg in "$@"; do
  url="${arg}"
done

printf '%s\n' "${url}" >> "${MOCK_REQUESTS_FILE}"

case "${url}" in
  'https://api.github.com/repos/curl/curl/releases?per_page=100&page=1' )
    page='['
    for ((i = 1; i <= 100; i++)); do
      [[ ${i} -gt 1 ]] && page+=','
      page+="{\"tag_name\":\"ineligible-${i}\",\"published_at\":\"2025-08-11T00:00:01Z\",\"created_at\":\"2025-08-01T00:00:00Z\",\"draft\":false,\"prerelease\":false}"
    done
    page+=']'
    printf '%s\n' "${page}"
    ;;
  'https://api.github.com/repos/curl/curl/releases?per_page=100&page=2' )
    case "${MOCK_PAGINATION_MODE}" in
      page2 )
        cat <<'JSON'
[
  {
    "tag_name": "page-two-release",
    "published_at": "2025-08-05T00:00:00Z",
    "created_at": "2025-08-10T00:00:00Z",
    "draft": false,
    "prerelease": false
  }
]
JSON
        ;;
      empty )
        printf '%s\n' '[]'
        ;;
      failure )
        echo 'page 2 failure' >&2
        exit 22
        ;;
      * )
        echo "unexpected pagination mode: ${MOCK_PAGINATION_MODE}" >&2
        exit 64
        ;;
    esac
    ;;
  * )
    echo "unexpected URL: ${url}" >&2
    exit 64
    ;;
esac
MOCK
  chmod +x "${TEST_BIN}/curl"
}

@test "prints version" {
  run "${SCRIPT}" --version

  [ "${status}" -eq 0 ]
  [ "${output}" = "$(expected_version_output)" ]
}

@test "prints usage" {
  run "${SCRIPT}" --help

  [ "${status}" -eq 0 ]
  [[ "${output}" == *'Usage:'* ]]
  [[ "${output}" == *'--latest          Print the latest release, or the first tag returned by the GitHub API'* ]]
  [[ "${output}" == *'--cooldown        Exclude releases published within the given Nh, Nd, or Nw cooldown'* ]]
}

@test "rejects missing repository" {
  run "${SCRIPT}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *'Usage:'* ]]
}

@test "rejects invalid repository format" {
  run "${SCRIPT}" 'curl/curl;echo injected'

  [ "${status}" -eq 1 ]
  [[ "${output}" == *'invalid repository format'* ]]
}

@test "rejects mutually exclusive archive formats" {
  run "${SCRIPT}" --tar --zip curl/curl

  [ "${status}" -eq 1 ]
  [[ "${output}" == *'--tar and --zip are mutually exclusive'* ]]
}

@test "rejects cooldown without release" {
  run "${SCRIPT}" --cooldown 1d curl/curl

  [ "${status}" -eq 1 ]
  [[ "${output}" == *'--cooldown requires --release'* ]]
}

@test "rejects invalid cooldown durations" {
  for duration in 0h 01d 1.5d 7 7x -1d; do
    run "${SCRIPT}" --release --cooldown "${duration}" curl/curl

    [ "${status}" -eq 1 ]
    [[ "${output}" == *'invalid cooldown duration'* ]]
  done
}

@test "rejects cooldown durations that overflow epoch arithmetic" {
  run "${SCRIPT}" --release --cooldown 15250284452472w curl/curl

  [ "${status}" -eq 1 ]
  [[ "${output}" == *'cooldown duration is too large'* ]]
}

@test "rejects missing cooldown duration" {
  run "${SCRIPT}" --release --cooldown

  [ "${status}" -eq 1 ]
  [[ "${output}" == *'--cooldown requires a duration'* ]]
}

@test "prints tags from GitHub API response" {
  mock_curl

  run "${SCRIPT}" curl/curl

  [ "${status}" -eq 0 ]
  [ "${output}" = $'curl-8_14_1\ncurl-8_14_0' ]
}

@test "prints releases from GitHub API response" {
  mock_curl

  run "${SCRIPT}" --release curl/curl

  [ "${status}" -eq 0 ]
  [ "${output}" = $'curl-8_13_0\ncurl-8_14_0\ncurl-8_14_rc1\ncurl-8_14_draft\ncurl-8_14_1\ncurl-8_12_0' ]
}

@test "filters releases by an inclusive cooldown cutoff" {
  mock_curl
  mock_date

  run "${SCRIPT}" --cooldown 1d --release curl/curl

  [ "${status}" -eq 0 ]
  [ "${output}" = $'curl-8_13_0\ncurl-8_14_0\ncurl-8_14_rc1\ncurl-8_14_draft' ]
}

@test "selects the newest eligible release with latest cooldown" {
  mock_curl
  mock_date

  run "${SCRIPT}" --release --latest --cooldown 1d curl/curl

  [ "${status}" -eq 0 ]
  [ "${output}" = 'curl-8_13_0' ]
}

@test "finds an eligible release on a later latest cooldown page" {
  mock_paginated_curl
  mock_date
  export MOCK_PAGINATION_MODE='page2' MOCK_REQUESTS_FILE="${BATS_TEST_TMPDIR}/requests"

  run "${SCRIPT}" --release --latest --cooldown 1d curl/curl

  [ "${status}" -eq 0 ]
  [ "${output}" = 'page-two-release' ]
  [ "$(cat "${MOCK_REQUESTS_FILE}")" = $'https://api.github.com/repos/curl/curl/releases?per_page=100&page=1\nhttps://api.github.com/repos/curl/curl/releases?per_page=100&page=2' ]
}

@test "stops latest cooldown pagination after an empty page" {
  mock_paginated_curl
  mock_date
  export MOCK_PAGINATION_MODE='empty' MOCK_REQUESTS_FILE="${BATS_TEST_TMPDIR}/requests"

  run "${SCRIPT}" --release --latest --cooldown 1d curl/curl

  [ "${status}" -eq 0 ]
  [ -z "${output}" ]
  [ "$(cat "${MOCK_REQUESTS_FILE}")" = $'https://api.github.com/repos/curl/curl/releases?per_page=100&page=1\nhttps://api.github.com/repos/curl/curl/releases?per_page=100&page=2' ]
}

@test "fails when a later latest cooldown page cannot be fetched" {
  mock_paginated_curl
  mock_date
  export MOCK_PAGINATION_MODE='failure' MOCK_REQUESTS_FILE="${BATS_TEST_TMPDIR}/requests"

  run "${SCRIPT}" --release --latest --cooldown 1d curl/curl

  [ "${status}" -ne 0 ]
  [[ "${output}" == *'page 2 failure'* ]]
}

@test "prints no output when no release meets the cooldown" {
  mock_curl
  mock_date

  run "${SCRIPT}" --release --cooldown 1000d curl/curl

  [ "${status}" -eq 0 ]
  [ -z "${output}" ]
}

@test "formats cooldown releases as archive URLs" {
  mock_curl
  mock_date

  run "${SCRIPT}" --release --cooldown 1d --tar curl/curl

  [ "${status}" -eq 0 ]
  [ "${output}" = $'https://github.com/curl/curl/archive/curl-8_13_0.tar.gz\nhttps://github.com/curl/curl/archive/curl-8_14_0.tar.gz\nhttps://github.com/curl/curl/archive/curl-8_14_rc1.tar.gz\nhttps://github.com/curl/curl/archive/curl-8_14_draft.tar.gz' ]

  run "${SCRIPT}" --release --cooldown 1d --zip curl/curl

  [ "${status}" -eq 0 ]
  [ "${output}" = $'https://github.com/curl/curl/archive/curl-8_13_0.zip\nhttps://github.com/curl/curl/archive/curl-8_14_0.zip\nhttps://github.com/curl/curl/archive/curl-8_14_rc1.zip\nhttps://github.com/curl/curl/archive/curl-8_14_draft.zip' ]
}

@test "requires jq only for cooldown" {
  mock_curl
  mock_date
  jq_path="$(command -v jq)"
  ln -s "$(command -v bash)" "${TEST_BIN}/bash"
  PATH="${TEST_BIN}" run "${SCRIPT}" --release --cooldown 1d curl/curl

  [ "${status}" -eq 1 ]
  [[ "${output}" == *'--cooldown requires jq'* ]]

  PATH="${TEST_BIN}:${jq_path%/*}" run "${SCRIPT}" --release curl/curl

  [ "${status}" -eq 0 ]
  [ "${output}" = $'curl-8_13_0\ncurl-8_14_0\ncurl-8_14_rc1\ncurl-8_14_draft\ncurl-8_14_1\ncurl-8_12_0' ]
}

@test "prints archive URL for the first tag returned by the tags API" {
  mock_curl

  run "${SCRIPT}" --latest --tar curl/curl

  [ "${status}" -eq 0 ]
  [ "${output}" = 'https://github.com/curl/curl/archive/curl-8_14_1.tar.gz' ]
}

@test "prints archive URL for the latest release" {
  mock_curl

  run "${SCRIPT}" --release --latest --zip curl/curl

  [ "${status}" -eq 0 ]
  [ "${output}" = 'https://github.com/curl/curl/archive/curl-8_14_1.zip' ]
}
