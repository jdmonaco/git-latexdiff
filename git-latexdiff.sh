#!/bin/bash
#
# Create LaTeX diffs from git revisions
#
# Requires: latexdiff, pdflatex (or xelatex), git, and rsync (for working copy
# diffs).
#
# Notes: (1) Latexdiff is required, preferably version 1.0.1+ so that
# included files are handled correctly. (2) The script will pick up on
# .append-safecmd and .text-safecmd files in the main document folder to use for
# the corresponding latexdiff options.
#
# Author: Joseph Monaco <jmonaco@jhu.edu> Last updated: December 18, 2018.
#

set -ue
NAME=$(basename "$0")

function usage {
cat <<USAGE
Usage: git-ldiff [-m <name>] [-x] [-o <opts>] [-b] <base> [-r <revision>]

Arguments:
-m,--main       main document name (default, 'main')
-x,--xelatex    use xelatex instead of pdflatex
-o,--options    addtional latexdiff arguments (--flatten is handled)
-b,--base       git commit reference for comparison point
-r,--revision   revision commit (default, working copy)

Only the <base> commit reference is required.
USAGE
}

# Assert latexdiff on path and running from repo root
[[ -z $(which "latexdiff") ]] && echo "Requires latexdiff." && exit 1
[[ -z $(which "git") ]] && echo "Requires git." && exit 2
[[ ! -d ".git" ]] && echo "Run from repository root." && exit 3

MAIN="main"
LATEX="pdflatex"
LTXARGS="-nonstopmode interaction"
BTXARGS="-terse"
LDARGS=""
BASEREF=""
REVREF="WC"

# Parse options
while (( $# )); do
    if   [[ "$1" = "-h" ]] || [[ "$1" = "--help" ]]; then
        usage && exit 0
    elif [[ "$1" = "-m" ]] || [[ "$1" = "--main" ]]; then
        MAIN="$2"
        shift; shift
    elif [[ "$1" = "-x" ]] || [[ "$1" = "--xelatex" ]]; then
        LATEX="xelatex"
        shift
    elif [[ "$1" = "-o" ]] || [[ "$1" = "--options" ]]; then
        LDARGS="$2"
        shift; shift
    elif [[ "$1" = "-b" ]] || [[ "$1" = "--base" ]]; then
        BASEREF="$2"
        shift; shift
    elif [[ "$1" = "-r" ]] || [[ "$1" = "--revised" ]]; then
        REVREF="$2"
        shift; shift
    else
        BASEREF="$1"
        shift
    fi
done

# Assert that the base commit was specified
[[ -z "$BASEREF" ]] && usage && exit 0

# Assert *latex and rsync (if needed) are on path
[[ -z $(which "$LATEX") ]] && echo "Unable to find $LATEX." && exit 4
[[ "$REVREF" = "WC" ]] && [[ -z $(which "rsync") ]] && \
    echo "Working copy diff requires rsync." && exit 5

# Apply --flatten if documents uses \include or \input
if [[ -n $(grep -Ewe '\\(include|input)' $MAIN.tex) ]]; then
    LDARGS="--flatten $LDARGS"
fi

# Add file of safe commands that can be annotated
ROOT=$(pwd)
SAFECMD="$ROOT/.append-safecmd"
if [[ -f "$SAFECMD" ]]; then
    LDARGS="--append-safecmd=\"$SAFECMD\" $LDARGS"
fi

# Add file of text commands whose last argument should be processed
TEXTCMD="$ROOT/.append-textcmd"
if [[ -f "$TEXTCMD" ]]; then
    LDARGS="--append-textcmd=\"$TEXTCMD\" $LDARGS"
fi

# Make the temporary directories
TMP=$(mktemp -d -t "$NAME")
BASE="$TMP/old"
REV="$TMP/new"

# Checkout base commit
echo "Cloning base commit ("$BASE")..."
echo " -> $BASE"
(  git clone "$ROOT/.git" "$BASE"
   cd "$BASE"
   git checkout "$BASEREF" ) > /dev/null 2>&1

# Checkout revised commit (or rsync working copy)
if [[ "$REVREF" = "WC" ]]; then
    echo "Copying working copy..."
    echo " -> $REV"
    mkdir -p "$REV" && \
        rsync -avhi --exclude=".git*" "$ROOT/" "$REV" > /dev/null 2>&1
else
    echo "Cloning revision commit..."
    echo " -> $REV"
    (
    git clone "$ROOT/.git" "$REV"
    cd "$REV"
    git checkout "$REVREF"
    ) > /dev/null 2>&1
fi

echo "Running latexdiff..."
(
cd "$TMP"
latexdiff $LDARGS "$BASE/$MAIN.tex" "$REV/$MAIN.tex" > "$REV/diff.tex"
) > /dev/null 2>&1

echo "Compiling the diff..."
(
cd "$REV";
$LATEX "$LTXARGS" diff.tex
if [[ -n "$(cat *.aux */*.aux 2>/dev/null | grep 'citation')" ]]; then
    bibtex "$BTXARGS" diff.aux
    $LATEX "$LTXARGS" diff.tex
fi
$LATEX "$LTXARGS" diff.tex
$LATEX "$LTXARGS" diff.tex
) > /dev/null 2>&1

if [[ -e "$REV/diff.pdf" ]] && [[ -s "$REV/diff.pdf" ]]; then

    # Export diff pdf to the original document directory
    DESTPDF="$ROOT/diff-$BASEREF-$REVREF.pdf"
    mv "$REV/diff.pdf" "$DESTPDF" && \
        echo "Diff saved to:" && echo " -> $DESTPDF"

    [[ $(which "open") ]] && open "$DESTPDF"
    rm -rf "$TMP" > /dev/null 2>&1

else
    echo 'Something went wrong! PDF file not produced.'
    exit 6
fi
