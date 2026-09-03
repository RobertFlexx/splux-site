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

## Handbook

`docs/` and `install/` are a static handbook (sidebar plus tabs). The
install page covers guided `setup`, a full manual tty install without
`setup`, and the slim ISO. New handbook HTML under `site/docs/` must be
registered in `tools/build-site.sh` with the correct `@@ROOT@@` depth.

## News

`news/` is generated at build time from GitHub metadata and local git
history, not edited by hand:

- every published SPS live ISO release (`RobertFlexx/SPS` GitHub Releases)
- every commit on SPS, sps-core, sps-extra, and this repository that
  Git or the GitHub API can see, with author and whether GitHub verified
  the signature. Commit links point at Splux Git.

The news feed splits into pages of twenty items. Each page is a real
URL (`/news/`, `/news/2/`, ...). Times in the page HTML are UTC; the
browser rewrites them to the viewer's local timezone. There is a page
number field for jumping when the archive grows.

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

The workflow rebuilds the package index, news feed, and git browser
every fifteen minutes and on push to `main`.
The custom domain is `https://splux.robertflexx.dev`. Point a DNS CNAME
for `splux` at `robertflexx.github.io`, then GitHub Pages serves this
repository there. `SITE_PREFIX` stays empty so links are rooted at `/`.

## Git

`/git/` is a live HTML mirror of SPS, sps-core, sps-extra, and this
repository. Languages match GitHub Linguist. Open a language to see
how many files use it (`/git/<repo>/lang/<Lang>/`). Source files are
highlighted per language. Markdown files, README notes, and GitHub
release bodies render as HTML. Commits show the GitHub account that
uploaded them, with avatars. In a repository, People lists that tree's
commit authors (`/git/<repo>/people/`). `/git/users/` holds profiles
across all official trees.

Tags are `/git/<repo>/tags/` and `/git/<repo>/tags/<name>/`. Releases
are `/git/<repo>/releases/`, `/git/<repo>/releases/tag/<name>/`, and
`/git/<repo>/releases/latest/`. Those pages follow GitHub's lists and
notes, with this site's URLs and layout. Source zip and tar.gz links
point at GitHub. ISO files and other release assets stay on GitHub
Releases.

The Pages workflow rebuilds those pages; the browser also asks GitHub
for anything newer. There is no git server and no pull requests. Clone
from GitHub:

```sh
git clone https://github.com/RobertFlexx/SPS.git
git clone https://github.com/RobertFlexx/sps-core.git
git clone https://github.com/RobertFlexx/sps-extra.git
git clone https://github.com/RobertFlexx/splux-site.git
```

News commit links point at `/git/<repo>/commit/<sha>/`. Author names
point at `/git/users/<login>/`. Recipe pages link into `/git/sps-core/`
and `/git/sps-extra/`. Live ISO files stay on GitHub Releases.

`git.splux.robertflexx.dev` is not a separate service. GitHub Pages
allows one custom domain on this repository (`splux.robertflexx.dev`).
The git UI is `https://splux.robertflexx.dev/git/`.
