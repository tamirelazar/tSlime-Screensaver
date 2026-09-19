#!/bin/bash
# PROTOTYPE — throwaway. Downloads the candidate faces from ticket #4 into ./fonts.
# Nothing is installed system-wide; the prototype registers them per-process.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p fonts tmp

want() { [ -f "fonts/$1" ]; }

if ! want JuliaMono-Regular.ttf; then
  echo "==> JuliaMono v0.63.2"
  curl -fsSL -o tmp/JuliaMono.tar.gz \
    https://github.com/cormullion/juliamono/releases/download/v0.63.2/JuliaMono-ttf.tar.gz
  tar -xzf tmp/JuliaMono.tar.gz -C tmp
  cp tmp/JuliaMono-Regular.ttf tmp/JuliaMono-Bold.ttf fonts/
fi

nerd() { # <zip-name> <ttf-glob>
  local zip="$1" glob="$2"
  echo "==> Nerd Fonts v3.5.1 $zip"
  curl -fsSL -o "tmp/$zip.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/$zip.zip"
  rm -rf "tmp/$zip" && mkdir -p "tmp/$zip"
  unzip -qo "tmp/$zip.zip" -d "tmp/$zip"
  find "tmp/$zip" -name "$glob" -exec cp {} fonts/ \;
}

want DejaVuSansMNerdFontMono-Regular.ttf || nerd DejaVuSansMono 'DejaVuSansMNerdFontMono-Regular.ttf'
want JetBrainsMonoNLNerdFontMono-Regular.ttf || want JetBrainsMonoNerdFontMono-Regular.ttf || \
  nerd JetBrainsMono 'JetBrainsMonoNerdFontMono-Regular.ttf'

rm -rf tmp
ls -la fonts/
