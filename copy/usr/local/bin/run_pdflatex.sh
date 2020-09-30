#!/bin/bash

export PATH=/usr/local/texlive/2020/bin/x86_64-linux:$PATH
hash -r

exec pdflatex "$@"
