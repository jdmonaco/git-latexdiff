## git-ldiff.sh

### Simple bash script for creating LaTeX diffs from git revisions

This is *yet another* wrapper script for compiling diff files between git revisions of a LaTeX document. There are
others which are more complicated and do all sorts of testing and checking. This one does not do much of that. It
checks out the two commit/branch refs that you specify on the command line into temporary folders, runs `latexdiff` on
them, compiles the diff, and moves the resulting pdf file back into the root document folder.

    Usage: git-ldiff.sh [main_base] old_ref new_ref 

You can optionally provide the basename of the main `.tex` file, which defaults to `main`. The old and new references can be any of the usual assortment of tags, hashes, and branches that are accepted by `git checkout`. 

Some notes:

- The script passes the option `--append-safecmd=$ROOT/.append-safecmd` if you have a file called `.append-safecmd` in your root document folder; see `man latexdiff` for more about safe commands
- If you have `\include` or `\input` commands to bring in other files, the script will use `latexdiff --flatten`, meaning that you will also need a recent `latexdiff` (1.0.1+, which you can get [at CTAN](http://www.ctan.org/tex-archive/support/latexdiff/)).

