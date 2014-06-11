## git-ldiff.sh

### Simple bash script for creating LaTeX diffs from git revisions

This is *yet another* wrapper script for compiling diff files between git revisions of a LaTeX document. There are
others which are more complicated and do all sorts of testing and checking. This one does not do much of that. It
checks out the two commit/branch refs that you specify on the command line into temporary folders, runs `latexdiff
--flatten` on them (as well as `--append-safecmd=$ROOT/.append-safecmd` if you have `.append-safecmd` in your root
document folder that you're running git-ldiff.sh from), compiles the diff, and moves the resulting pdf file back into the root document folder. 

    Usage: git-ldiff.sh OLD_REF NEW_REF 

The references can be any of the usual assortment of tags, hashes, and branches that are accepted by `git checkout`. 

The script probably doesn't have to default to using `--flatten`, but mostly I'm using this for complicated multi-file
documents where it's always needed. This also means you need a recent (1.0.1+) version of `latexdiff` (which you can
get [at CTAN](http://www.ctan.org/tex-archive/support/latexdiff/)). 

