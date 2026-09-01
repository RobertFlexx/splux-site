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
For a project site the Pages URL is `/splux-site/`. Set `SITE_PREFIX=/splux-site`
in that workflow so the 404 page can still load CSS.
