# This might seem backwards when you look at the "Bash startup files" reference
# <http://www.gnu.org/software/bash/manual/bashref.html#Bash-Startup-Files> or
# the "INVOCATION" section in the man page. However, my workflow typically is:
#
# * Open a terminal with four shells in tabs
# * Edit code in Vim, and shell out using ":sh"
#
# The initial four shells are login shells, so they source ~/.bash_profile.
# The shells spawned by Vim are not login shells, but they /are/ interactive.
# They look for .bashrc, but not .bash_profile. Because they are interactive,
# PS1 is set, so I know it is OK to run all the shell initialisation code.
#
# If I were to put the contents of ~/.bash_profile in ~/.bashrc and make the
# former source the latter, I would have to wrap the entire contents of the
# latter in a huge "if [ -n "$PS1" ]; then ... fi" block. That does not really
# help readability, does it?
#
# (Of course, I could also do "[ -z "$PS1" ] && return;" in ~/.bashrc and still
# source it from ~/.bash_profile, but way back when I started my .bash_profile
# customisations, I did not know about login vs. non-login shells, nor did I
# know you could do "return" in a sourced file. If I were to change things now,
# I would lose my blame history, which seems too high a price to pay.)
#
# The difference between a login shell and an interactive non-login shell is
# moot for me, so I consider all interactive shells to be equal and wanting
# the same treatment.
#
# If you're wondering what a non-interactive shell might be, i.e. when PS1
# might not be set, try this:
#
#     ssh localhost 'echo "PS1: >$PS1<"'
#

[ -n "$PS1" ] && source ~/.bash_profile;
