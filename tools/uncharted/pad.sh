#!/usr/bin/env bash
# pad.sh "TOKENS" SECONDS: hold pad tokens on U2's pad file, then release.
F=/h/uncharted_pc/out/try/u2/pad.txt
printf '%s' "$1" > $F.tmp; mv $F.tmp $F; python -c "import time; time.sleep(float('$2'))"; printf '' > $F.tmp; mv $F.tmp $F
