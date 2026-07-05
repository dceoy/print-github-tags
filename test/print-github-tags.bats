#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  SCRIPT="${REPO_ROOT}/print-github-tags"
  TEST_BIN="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "${TEST_BIN}"
  export PATH="${TEST_BIN}:${PATH}"
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
  'https://api.github.com/repos/curl/curl/releases?per_page=100' )
    cat <<'JSON'
[
  {
    "tag_name": "curl-8_14_1",
    "name": "curl 8.14.1"
  },
  {
    "tag_name": "curl-8_14_0",
    "name": "curl 8.14.0"
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
  [ "${output}" = $'curl-8_14_1\ncurl-8_14_0' ]
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
