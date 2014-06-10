#!/bin/bash

TEX=main.tex
DIFFBASE=diff

if [[ ! -d ".git" ]]; then
    echo please run from the root of your document repository
    exit 1
fi

ROOT=`pwd`
REPO=${ROOT}/.git
PROG=`basename $0`
TMP=`mktemp -d -t ${PROG}` || exit 2
echo compiling diff in $ROOT

OLD=$TMP/old
NEW=$TMP/new
DIFF=$DIFFBASE.tex
AUX=$DIFFBASE.aux
PDF=$DIFFBASE.pdf

LD_OPTS="--flatten"
SAFEFILE=$ROOT/.append-safecmd
if [[ -e "$SAFEFILE" ]]; then
    LD_OPTS="--append-safecmd=$SAFECMD $LD_OPTS"
fi

GIT="git"
LATEXDIFF="echo latexdiff"
PDFLATEX="pdflatex"
BIBTEX="bibtex"
CD="cd"
MV="mv"
OPEN="open"

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
