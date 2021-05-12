#!/usr/bin/env bash
#
# Easily create LaTeX diffs from git revisions
#
# Requires: git, latexdiff, pdflatex (or xelatex), and rsync (for working copy
# diffs).
#
# Notes: (1) The latexdiff script should be version 1.0.1+ so that included
# files are handled correctly. (2) The script will pick up on .append-safecmd,
# .exclude-safecmd, .append-textcmd, and .exclude-texcmd files in the main
# document folder to use for the corresponding latexdiff options.
#
# Author: Joseph Monaco <jmonaco@jhu.edu>
# Last updated: May 12, 2021.
#

set -ue
NAME=$(basename "$0")

function usage {
cat <<USAGE
Usage: git-ldiff [-m <path>] [-p|-x] [-o <opts>] [-b] <base> [-r <revision>]

Options:
-m,--main       repository path to main document (default, 'main')
-p,--pdflatex   use pdflatex (default)
-x,--xelatex    use xelatex instead of pdflatex
-o,--options    additional latexdiff arguments (--flatten is handled)
-b,--base       git commit reference for comparison point
-r,--revision   revision commit (default, working copy)

Only the <base> commit reference is required.
USAGE
}

# Assert latexdiff and git are on the path
[[ -z "$(which latexdiff)" ]] && echo "Error: Requires latexdiff." && \
    usage && exit 1
[[ -z "$(which git)" ]] && echo "Error: Requires git." && \
    usage && exit 2

# Make sure we are running from a repository and change to root
WDSTART="$(pwd)"
while [[ ! -d ".git" ]]; do
    if [[ "$(pwd)" == "/" ]] || [[ "$(pwd)" == "$HOME" ]]; then
        echo "Error: Not in a repository: $WDSTART" && usage && exit 3
    fi
    cd ..;
done
ROOT="$(pwd)"
echo "Found repository: $ROOT"

DOCPATH="manuscript"
LATEX="pdflatex"
LTXARGS="-interaction=nonstopmode"
BTXARGS="-terse"
LDARGS="--type=CFONT --floattype=FLOATSAFE --disable-citation-markup"
BASEREF=""
REVREF="WC"

# Parse options
while (( $# )); do
    if   [[ "$1" = "-h" ]] || [[ "$1" = "--help" ]]; then
        usage && exit 0
    elif [[ "$1" = "-m" ]] || [[ "$1" = "--main" ]]; then
        DOCPATH="$2"
        shift 2
    elif [[ "$1" = "-x" ]] || [[ "$1" = "--xelatex" ]]; then
        LATEX="xelatex"
        shift
    elif [[ "$1" = "-p" ]] || [[ "$1" = "--pdflatex" ]]; then
        LATEX="pdflatex"
        shift
    elif [[ "$1" = "-o" ]] || [[ "$1" = "--options" ]]; then
        LDARGS="$LDARGS $2"
        shift 2
    elif [[ "$1" = "-b" ]] || [[ "$1" = "--base" ]]; then
        BASEREF="$2"
        shift 2
    elif [[ "$1" = "-r" ]] || [[ "$1" = "--revised" ]]; then
        REVREF="$2"
        shift 2
    else
        BASEREF="$1"
        shift
    fi
done

# Process document path into components and verify main file exists
DOCPATH="${DOCPATH%.*}"
TEXPATH="$DOCPATH.tex"
MAINBASE="${DOCPATH##*/}"
MAINTEX="$MAINBASE.tex"
MAINPATH="./"
if [[ "$DOCPATH" == */* ]]; then
    MAINPATH="${DOCPATH%/*}"
fi
if [[ ! -f "$TEXPATH" ]]; then
    echo "Error: Missing main document: $TEXPATH" && usage && exit 4
fi

# Assert that the base commit was specified
[[ -z "$BASEREF" ]] && echo "Error: Missing base reference." && usage && exit 5

# Check for XeLaTeX commands or directives
if [[ "$LATEX" == "pdflatex" ]]; then
    if [[ "$(head -1 $TEXPATH)" == *xelatex* ]]; then
        echo "Warning: Forcing xelatex because of program directive"
        LATEX="xelatex"
    elif grep -E '\\(setmainfont|setmathsfont|fontspec)' "$TEXPATH" \
            > /dev/null 2>&1; then
        echo "Warning: Forcing xelatex because of font commands"
        LATEX="xelatex"
    fi
fi

# Assert *latex and rsync (if needed) are on path
[[ -z $(which "$LATEX") ]] && echo "Unable to find $LATEX." && exit 6
[[ "$REVREF" = "WC" ]] && [[ -z $(which "rsync") ]] && \
    echo "Working copy diff requires rsync." && exit 7

# Apply --flatten if documents uses \include or \input
if [[ -n $(grep -Ewe '\\(include|input)' "$TEXPATH") ]]; then
    LDARGS="--flatten $LDARGS"
fi

# Add file of safe commands that can be annotated
SAFECMD="$ROOT/$MAINPATH/.append-safecmd"
if [[ -f "$SAFECMD" ]]; then
    echo "Found $SAFECMD"
    LDARGS="--append-safecmd=\"$SAFECMD\" $LDARGS"
fi

# Add file of safe commands that should not be annotated
EXSAFECMD="$ROOT/$MAINPATH/.exclude-safecmd"
if [[ -f "$EXSAFECMD" ]]; then
    echo "Found $EXSAFECMD"
    LDARGS="--exclude-safecmd=\"$EXSAFECMD\" $LDARGS"
fi

# Add file of text commands whose last argument should be processed
TEXTCMD="$ROOT/$MAINPATH/.append-textcmd"
if [[ -f "$TEXTCMD" ]]; then
    echo "Found $TEXTCMD"
    LDARGS="--append-textcmd=\"$TEXTCMD\" $LDARGS"
fi

# Add file of text commands that should not be annotated
EXTEXTCMD="$ROOT/$MAINPATH/.exclude-textcmd"
if [[ -f "$EXTEXTCMD" ]]; then
    echo "Found $EXTEXTCMD"
    LDARGS="--exclude-textcmd=\"$EXTEXTCMD\" $LDARGS"
fi

# Make the temporary directories
TMP=$(mktemp -d -t "$NAME")
BASE="$TMP/old"
REV="$TMP/new"

# Checkout base commit
echo "Cloning base commit ("$BASE")..."
echo " -> $BASE"
(
git clone "$ROOT/.git" "$BASE"
cd "$BASE"
git checkout "$BASEREF"
) > /dev/null 2>&1

# Update base to include path to main latex docs
if [[ "$MAINPATH" != "./" ]]; then
    BASE="$BASE/$MAINPATH"
fi

# Compile bibtex for bbl file in base if necessary
if grep '^\w*\\begin{thebibliography}' "$BASE/$MAINTEX" > /dev/null 2>&1; then
    echo "Found embedded bibliography..."
elif grep '\\cite' "$BASE/$MAINTEX" > /dev/null 2>&1; then
    echo "Compiling base bibtex..."
    echo " -> $BASE/$MAINBASE.bbl"
    (
    cd "$BASE"
    $LATEX "$LTXARGS" $MAINTEX
    bibtex "$BTXARGS" $MAINBASE
    ) > /dev/null
fi

# Checkout revised commit (or rsync working copy)
if [[ "$REVREF" == "WC" ]]; then
    echo "Copying working copy..."
    echo " -> $REV"
    mkdir -p "$REV" && \
        rsync -avhi --exclude="build/" --exclude=".git*" \
            "$ROOT/" "$REV" > /dev/null
else
    echo "Cloning revision commit..."
    echo " -> $REV"
    (
    git clone "$ROOT/.git" "$REV"
    cd "$REV"
    git checkout "$REVREF"
    ) > /dev/null 2>&1
fi

# Update revision to include path to main latex docs
if [[ "$MAINPATH" != "./" ]]; then
    REV="$REV/$MAINPATH"
fi

# Compile bibtex for bbl file in revision if necessary
if grep '^\w*\\begin{thebibliography}' "$REV/$MAINTEX" > /dev/null 2>&1; then
    echo "Found embedded bibliography..."
elif grep '\\cite' "$REV/$MAINTEX" > /dev/null 2>&1; then
    echo "Compiling revision bibtex..."
    echo " -> $REV/$MAINBASE.bbl"
    (
    cd "$REV"
    $LATEX "$LTXARGS" $MAINTEX
    bibtex "$BTXARGS" $MAINBASE
    ) > /dev/null
fi

echo "Running latexdiff (tex)..."
(
cd "$TMP"
latexdiff $LDARGS "$BASE/$MAINTEX" "$REV/$MAINTEX" > "$REV/diff.tex"
) > /dev/null

if [[ -f "$BASE/$MAINBASE.bbl" ]] && [[ -f "$REV/$MAINBASE.bbl" ]]; then
    echo "Running latexdiff (bbl)..."
    (
    cd "$TMP"
    latexdiff $LDARGS "$BASE/$MAINBASE.bbl" "$REV/$MAINBASE.bbl" \
        > "$REV/diff.bbl"
    ) > /dev/null
fi

echo "Compiling the diff..."
(
cd "$REV";
$LATEX "$LTXARGS" diff.tex
$LATEX "$LTXARGS" diff.tex
$LATEX "$LTXARGS" diff.tex
) > /dev/null

if [[ -s "$REV/diff.pdf" ]]; then

    # Export diff pdf to the original document directory
    DESTPDF="$ROOT/$MAINPATH/diff-$BASEREF-$REVREF.pdf"
    mv "$REV/diff.pdf" "$DESTPDF" && \
        echo "Saved diff:" && echo " -> $DESTPDF"

    # Export diff aux file also, which could contain useful references (e.g.,
    # for cross-referencing to other documents using the xr package)
    DESTAUX="$ROOT/$MAINPATH/diff-$BASEREF-$REVREF.aux"
    mv "$REV/diff.aux" "$DESTAUX" && \
        echo "Saved aux:" && echo " -> $DESTAUX"

    [[ $(which "open") ]] && open "$DESTPDF"
    rm -rf "$TMP" > /dev/null 2>&1

else
    echo 'Something went wrong! PDF file not produced.'
    exit 8
fi
