#!/usr/bin/env bash
# chroute.sh GAME N: a drive.py route from the title to the start of chapter N (Chapter Select) with the
# chapter-unlocked test user (UCUSER=u2fight); U2 first turns the game and tutorial hints off. Ends 60 s after Start.
G=$1; N=$2; R=""
for i in $(seq 2 $N); do R="$R press right; wait 1.5;"; done
if [ $G = u2 ]; then
    echo "wait 45; press cross; wait 4; press down; wait 1; press down; wait 1; press right; wait 1; press cross; wait 3; press cross; wait 3; press down; wait 1; press right; wait 1; press down; wait 1; press right; wait 1; press circle; wait 2; press circle; wait 2; press left; wait 1; press up; wait 1; press cross; wait 3;$R press down; wait 1.5; press down; wait 1.5; press down; wait 1.5; press cross; wait 3; press down; wait 1.5; press down; wait 1.5; press down; wait 1.5; press cross; wait 60"
else
    echo "wait 50; press cross; wait 6; press down; wait 1.5; press cross; wait 4;$R press cross; wait 2; press down; wait 1.5; press down; wait 1.5; press down; wait 1.5; press cross; wait 3; press cross; wait 60"
fi
