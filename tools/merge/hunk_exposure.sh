#!/bin/bash
# Conflict exposure of the fork's hunks in upstream files (see 10-multiview-merge-audit.md).
#
# For every hunk of `git diff BASE REF` in a file that exists at BASE, counts the upstream commits
# in the year before BASE that changed lines within 3 of the hunk (git log -L on BASE). A hunk with
# exposure 0 sits in code upstream did not touch all year; a high number is where the next merge
# is likely to conflict.
#
# usage: hunk_exposure.sh [-C rpcs3-checkout] BASE REF [files...]
#   REF may be WORKTREE (the working tree). Without files: every file changed between BASE and REF.
#   The checkout needs the year of history before BASE (git fetch --shallow-since=... if shallow).
# output (TSV): file  base_start  base_len  fork_lines  upstream_commits
# example: tools/merge/hunk_exposure.sh -C ../rpcs3 master openxr | sort -t$'\t' -k5,5nr | head

if [ "$1" = "-C" ]; then cd "$2" || exit 1; shift 2; fi
BASE=$(git rev-parse "$1") || exit 1
REF=$2
shift 2
SINCE=$(date -d "$(git log -1 --format=%ci "$BASE") - 1 year" +%Y-%m-%d)
# git diff OPTIONS BASE [REF] [-- FILE]
diff_ref() {
	local opts=() paths=()
	while [ $# -gt 0 ] && [ "$1" != -- ]; do opts+=("$1"); shift; done
	[ "$1" = -- ] && shift && paths=(-- "$@")
	if [ "$REF" = WORKTREE ]; then git diff "${opts[@]}" "$BASE" "${paths[@]}"; else git diff "${opts[@]}" "$BASE" "$REF" "${paths[@]}"; fi
}
files=("$@")
[ ${#files[@]} -eq 0 ] && mapfile -t files < <(diff_ref --name-only)
for f in "${files[@]}"; do
	git cat-file -e "$BASE:$f" 2>/dev/null || continue
	total=$(git show "$BASE:$f" | wc -l)
	diff_ref -U0 -- "$f" | awk '
		/^@@/ { if (h) print a, n, fl; split($2, o, ","); a = substr(o[1], 2); n = (o[2] == "" ? 1 : o[2]); fl = 0; h = 1; next }
		/^[+-]/ && !/^(\+\+\+|---)/ { fl++ }
		END { if (h) print a, n, fl }' | while read -r a n fl; do
		s=$((a - 3)); e=$((a + n + 3))
		[ $s -lt 1 ] && s=1
		[ $e -gt "$total" ] && e=$total
		[ $e -lt $s ] && e=$s
		c=$(git log --since="$SINCE" --format='%H' -L "$s,$e:$f" "$BASE" 2>/dev/null | grep -cE '^[0-9a-f]{40}$')
		printf '%s\t%s\t%s\t%s\t%s\n' "$f" "$a" "$n" "$fl" "$c"
	done
done
