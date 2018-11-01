print-github-tags
=================

Tiny command to fetch repository tags or releases from GitHub

Installation
------------

This command depends on curl.

```sh
$ cd /path/to/bin   # a path in ${PATH}
$ curl -SO https://raw.githubusercontent.com/dceoy/print-github-tags/master/print-github-tags
$ chmod +x print-github-tags
```

Example
-------

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

Usage
-----

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
  --latest          Print a latest tag or release
  --tar             Print tar file URLs (.tar.gz)
  --zip             Print zip file URLs (.zip)

Example:
  $ print-github-tags --release --latest --tar curl/curl
```
