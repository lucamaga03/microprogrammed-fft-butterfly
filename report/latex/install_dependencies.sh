#!/usr/bin/env bash
set -e

echo "[*] Aggiornamento lista pacchetti..."
sudo apt update

echo "[*] Installazione dipendenze TeX..."
sudo apt install -y \
    texlive \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-bibtex-extra \
    texlive-science \
    texlive-fonts-recommended \
    texlive-lang-european \
    texlive-lang-italian

echo "[✓] Done."
