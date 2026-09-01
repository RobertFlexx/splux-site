# Splux website

Static site for Splux Linux and the official SPS package collections.

This site was fully handmade by RobertFlexx.

## Build

```sh
CORE=/tmp/sps-core EXTRA=/tmp/sps-extra ./tools/build-site.sh
```

If `CORE` and `EXTRA` are unset, the script clones
`https://github.com/RobertFlexx/sps-core` and
`https://github.com/RobertFlexx/sps-extra` into `vendor/`.

Output is `_site/`. Preview:

```sh
python3 -m http.server -d _site
```

Python is only for local preview. The generator is POSIX shell and AWK.

## Download links

ISO names are stable:

- https://github.com/RobertFlexx/SPS/releases/latest/download/sps-live-tty.iso
- https://github.com/RobertFlexx/SPS/releases/latest/download/sps-live-tty-slim.iso
- https://github.com/RobertFlexx/SPS/releases/latest/download/sps-live-plasma.iso
- https://github.com/RobertFlexx/SPS/releases/latest/download/SHA256SUMS

The visible tag name is filled at build time from the GitHub Releases API.

## GitHub Pages

The workflow rebuilds the package index on a schedule and on push to `main`.
The custom domain is `https://splux.robertflexx.dev`. Point a DNS CNAME
for `splux` at `robertflexx.github.io`, then GitHub Pages serves this
repository there. `SITE_PREFIX` stays empty so links are rooted at `/`.
