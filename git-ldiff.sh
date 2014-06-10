#!/bin/bash

if [[ ! -d ".git" ]]; then
    echo please run from the root of your document repository
    exit 1
fi

ROOT=`pwd`
REPO="$ROOT/.git"
PROG=`basename $0`
TMP=`mktemp -d -t ${PROG}XXXXXX` || exit 2
echo compiling to $TMP

exit 0

OLD=$ROOT/old
NEW=$ROOT/new
TEX=main.tex
DIFF=diff.tex
AUX=diff.aux
PDF=diff.pdf
SAFE=.append-safecmd

MAKE="make"
GIT="git"
LATEXDIFF="latexdiff"
PDFLATEX="pdflatex"
BIBTEX="bibtex"
CD="cd"
MV="mv"
OPEN="open"

$MAKE clean
$GIT clone $1/.git $OLD
$GIT clone $1/.git $NEW

$CD $OLD;
$GIT checkout $2

$CD $NEW;
$GIT checkout $3

$CD $ROOT;
$LATEXDIFF --append-safecmd=$ROOT/$SAFE --flatten $OLD/$TEX $NEW/$TEX > $NEW/$DIFF

$CD $NEW;
$PDFLATEX -interaction batchmode $DIFF
$BIBTEX -terse $AUX
$PDFLATEX -interaction batchmode $DIFF
$PDFLATEX -interaction batchmode $DIFF

$CD $ROOT;
$MV $NEW/$PDF .;

$OPEN $PDF -a /Applications/Skim.app
