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

The visible tag name is filled at build time from the GitHub Releases API
and refreshed from GitHub when you open the page.

## News

`news/` is generated at build time from GitHub, not edited by hand:

- every published SPS live ISO release (`RobertFlexx/SPS` GitHub Releases)
- every commit on SPS, sps-core, sps-extra, and this repository that
  Git or the GitHub API can see

The Pages workflow rebuilds every five minutes, and also on push,
`workflow_dispatch`, and a `rebuild` repository dispatch. The news and
download pages also ask GitHub for anything newer when they load, so a
missed cron job cannot hide a new ISO. Atom feed: `/news/atom.xml`.

To rebuild immediately from another repository, send a
`repository_dispatch` of type `rebuild` to `RobertFlexx/splux-site`.
SPS does that after a live ISO release and on push to `main` when the
`SPLUX_SITE_TOKEN` secret is set (a PAT that can dispatch workflows on
this repo). Without that secret, the five-minute schedule and the
in-page GitHub refresh still pick releases up.

## GitHub Pages

The workflow rebuilds the package index and news feed every five minutes
and on push to `main`.
The custom domain is `https://splux.robertflexx.dev`. Point a DNS CNAME
for `splux` at `robertflexx.github.io`, then GitHub Pages serves this
repository there. `SITE_PREFIX` stays empty so links are rooted at `/`.
