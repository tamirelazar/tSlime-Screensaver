#!/bin/bash
# PROTOTYPE — throwaway. Captures one real tslime frame per candidate in a
# detached tmux pane at the saver's grid (190x56), with the candidate's flags.
# Sessions run in parallel batches of 8 (tslime is ~30% of a core each).
# usage: ./capture.sh round-N.tsv [seconds] [stage]
#   stage names a second capture of the same round: frames/<round>-<stage>.
#   Round 2 uses 30 s for the mature frame (the state a viewer mostly sees:
#   fewer, brighter trails spanning the whole palette) and 8 s for "young".
set -euo pipefail
cd "$(dirname "$0")"
# A private tmux server, so a dying default server never swallows a new session.
tmux() { command tmux -L themes "$@"; }
tmux kill-server 2>/dev/null || true; sleep 0.5
LIST=${1:-round-1.tsv}; SECS=${2:-30}; STAGE=${3:-}
ROUND=$(basename "$LIST" .tsv)${STAGE:+-$STAGE}
TSLIME="$(cd ../.. && pwd)/AppexSaverMinimal/tslime"
mkdir -p "frames/$ROUND"
batch=(); names=()
flush() {
  [ ${#batch[@]} -gt 0 ] || return 0
  sleep "$SECS"
  for i in "${!batch[@]}"; do
    tmux capture-pane -t "${batch[$i]}" -p -e -N > "frames/$ROUND/${names[$i]}.txt"
    tmux kill-session -t "${batch[$i]}"
    echo "${names[$i]}: $(wc -l < "frames/$ROUND/${names[$i]}.txt") rows"
  done
  batch=(); names=()
}
grep -v '^#' "$LIST" | while IFS=$'\t' read -r id name palette inner outer accent idea chosen; do
  flags="--window-frame glow --fps 30 --skip-warmup --seed 7 --palette '$palette'"
  [ "$inner" != "-" ] && flags="$flags --bg-color-inner $inner"
  [ "$outer" != "-" ] && flags="$flags --bg-color-outer $outer"
  [ "$accent" != "-" ] && flags="$flags --accent-color $accent"
  s="theme-$id"
  tmux kill-session -t "$s" 2>/dev/null || true
  tmux new-session -d -s "$s" -x 190 -y 56 "$TSLIME $flags"
  batch+=("$s"); names+=("$id-$name")
  [ ${#batch[@]} -lt 8 ] || flush
done
# the while loop runs in a subshell: flush the last batch by listing what is still alive
left=$(tmux list-sessions -F '#S' 2>/dev/null | grep '^theme-' || true)
if [ -n "$left" ]; then
  sleep "$SECS"
  for s in $left; do
    id=${s#theme-}
    name=$(grep -v '^#' "$LIST" | awk -F'\t' -v id="$id" '$1==id {print $1"-"$2}')
    tmux capture-pane -t "$s" -p -e -N > "frames/$ROUND/$name.txt"
    tmux kill-session -t "$s"
    echo "$name: $(wc -l < "frames/$ROUND/$name.txt") rows"
  done
fi
tmux kill-server 2>/dev/null || true
