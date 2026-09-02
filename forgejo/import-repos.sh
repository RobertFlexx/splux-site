#!/bin/sh
# Import official GitHub trees into Splux Git. No tokens.
# Usage: sh forgejo/import-repos.sh
set -eu

FORGE=${FORGE:-/home/robert/splux-forge}
BIN=$FORGE/bin/forgejo
DATA=$FORGE/data
DUMP=${DUMP:-/tmp/fj-dump}
FJ() {
	"$BIN" -w "$DATA" "$@"
}

already() {
	curl -sf -o /dev/null "http://127.0.0.1:3000/api/v1/repos/RobertFlexx/$1"
}

import_one() {
	name=$1
	url=$2
	if already "$name"
	then
		printf '%s\n' "already in forge: $name" >&2
		return 0
	fi
	unitdir=$DUMP/RobertFlexx/$name
	if [ ! -f "$unitdir/repo.yml" ]; then
		workdir=$(mktemp -d "$DUMP/work.XXXXXX")
		printf '%s\n' "dumping $name" >&2
		FJ dump-repo \
			--git_service github \
			--clone_addr "$url" \
			--owner_name RobertFlexx \
			--repo_name "$name" \
			--repo_dir "$workdir" \
			--units labels,releases,milestones
		mkdir -p "$DUMP/RobertFlexx"
		if [ -d "$workdir/RobertFlexx/$name" ]; then
			rm -rf "$unitdir"
			mv "$workdir/RobertFlexx/$name" "$unitdir"
		fi
		rm -rf "$workdir"
	fi
	[ -f "$unitdir/repo.yml" ] || {
		printf '%s\n' "dump missing $unitdir/repo.yml" >&2
		return 1
	}
	printf '%s\n' "restoring $name" >&2
	FJ restore-repo \
		--owner_name RobertFlexx \
		--repo_name "$name" \
		--repo_dir "$unitdir" \
		--units labels,releases,milestones
	printf '%s\n' "imported $name" >&2
}

mkdir -p "$DUMP"
import_one SPS https://github.com/RobertFlexx/SPS.git
import_one sps-core https://github.com/RobertFlexx/sps-core.git
import_one sps-extra https://github.com/RobertFlexx/sps-extra.git
import_one splux-site https://github.com/RobertFlexx/splux-site.git
printf '%s\n' "import done" >&2
