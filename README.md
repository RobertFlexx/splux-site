# Splux website

Static site for Splux Linux and the official SPS package collections.

This site was fully handmade by RobertFlexx.

## Build (for maintainers)

```sh
CORE=/tmp/sps-core EXTRA=/tmp/sps-extra SPS=/path/to/SPS ./tools/build-site.sh
```

If `CORE`, `EXTRA`, or `SPS` are unset, the script clones
`sps-core`, `sps-extra`, and `SPS` into `vendor/`.

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

## News

`news/` is generated at build time from GitHub, not edited by hand:

- SPS live ISO releases (`RobertFlexx/SPS` GitHub Releases)
- recent commits on SPS, sps-core, sps-extra, and this repository

The Pages workflow rebuilds about every twenty minutes, and also on
push and `workflow_dispatch`. A new ISO tag shows up here without
committing to splux-site. Atom feed: `/news/atom.xml`.

To rebuild immediately from another repository, send a
`repository_dispatch` of type `rebuild` to `RobertFlexx/splux-site`.
SPS does that after a live ISO release when the `SPLUX_SITE_TOKEN`
secret is set (a PAT that can dispatch workflows on this repo).
Without that secret, the schedule still picks releases up.

## GitHub Pages

The workflow rebuilds the package index and news feed on a schedule
and on push to `main`.
The custom domain is `https://splux.robertflexx.dev`. Point a DNS CNAME
for `splux` at `robertflexx.github.io`, then GitHub Pages serves this
repository there. `SITE_PREFIX` stays empty so links are rooted at `/`.
