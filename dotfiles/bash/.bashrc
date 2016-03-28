parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# Display a ^_^ on successful exit codes, or 0_0 on failed exit codes.
#PS1="\`if [ \$? = 0 ]; then echo \[\e[32m\]^_^\[\e[0m\]; else echo \[\e[31m\]O_O\[\e[0m\]; fi\`[\u@\h:\w]\\$ "

# Set the prompt to display current Git branch.
PS1="\u@\h \[\033[32m\]\w\[\033[33m\]\$(parse_git_branch)\[\033[00m\] $ "

