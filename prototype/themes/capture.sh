#!/bin/bash
# PROTOTYPE — throwaway. Captures one real tslime frame per candidate in a
# detached tmux pane at the saver's grid (190x56), with the candidate's flags.
# usage: ./capture.sh round-1.tsv [seconds] [fps] [stage]
# stage names a second capture of the same round (e.g. "late": more seconds at a
# higher fps, for the dense steady state a viewer sees after a minute).
set -euo pipefail
cd "$(dirname "$0")"
LIST=${1:-round-1.tsv}; SECS=${2:-8}; FPS=${3:-30}; STAGE=${4:-}
ROUND=$(basename "$LIST" .tsv)${STAGE:+-$STAGE}
TSLIME="$(cd ../.. && pwd)/AppexSaverMinimal/tslime"
mkdir -p "frames/$ROUND"
grep -v '^#' "$LIST" | while IFS=$'\t' read -r id name palette inner outer accent idea; do
  flags="--window-frame glow --fps $FPS --skip-warmup --seed 7 --palette $palette"
  [ "$inner" != "-" ] && flags="$flags --bg-color-inner $inner"
  [ "$outer" != "-" ] && flags="$flags --bg-color-outer $outer"
  [ "$accent" != "-" ] && flags="$flags --accent-color $accent"
  s="theme-$id"
  tmux kill-session -t "$s" 2>/dev/null || true
  tmux new-session -d -s "$s" -x 190 -y 56 "$TSLIME $flags"
  sleep "$SECS"
  tmux capture-pane -t "$s" -p -e -N > "frames/$ROUND/$id-$name.txt"
  tmux kill-session -t "$s"
  echo "$id $name: $(wc -l < "frames/$ROUND/$id-$name.txt") rows  [$flags]"
done
