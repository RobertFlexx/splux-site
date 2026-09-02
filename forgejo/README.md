# Splux Git

Forgejo themed to match the Splux handbook. The live process lives in
`/home/robert/splux-forge`. This directory is the theme, example config,
and installer that the static site ships so the forge and the handbook
stay in the same style.

```sh
sh forgejo/install.sh
```

That copies the theme, writes `app.ini`, and starts port 3000. Create
the admin account yourself (the installer does not set a password):

```sh
/home/robert/splux-forge/bin/forgejo -w /home/robert/splux-forge/data \
  admin user create --username RobertFlexx --email ohf9ck@gmail.com \
  --admin --password 'your-password'
```

Then in the web UI, migrate SPS, sps-core, sps-extra, and splux-site
from GitHub.

The public handbook page is `/git/`. Clone URLs on the internet still
use GitHub until `git.splux.robertflexx.dev` has DNS and TLS in front of
this process. LAN:

```sh
git clone http://10.0.0.139:3000/RobertFlexx/SPS.git
git clone ssh://robert@10.0.0.139:2222/RobertFlexx/SPS.git
```

Push mirrors to GitHub are a per-repo setting in the forge UI. They
need a GitHub PAT. Issues and pull requests stay on Splux Git.
