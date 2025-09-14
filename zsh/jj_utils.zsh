alias jj=jj_guard.sh

alias j=jj
alias k=jj
alias kk=jj

alias je='jj edit -r'
alias jwip='je "wipcurrent()"'
# alias je='echo "Should you not be using new+squash?"'
# alias jer='jj edit -r'
# alias jer='echo "Should you not be using new+squash?"'
alias jsq='jj squash -i --keep-emptied'
alias jnext='je @+ && jj'
alias jn='jnext'
alias jnn='je @++ && jj'
alias jnnn='je @+++ && jj'
alias jprev='je @- && jj'
alias jp='jprev'
alias jpp='je @-- && jj'
alias jppp='je @--- && jj'
alias jsync='jj git fetch && jj retrunk && jj simplify && jj'
alias jsyncdev='jj git fetch && jj retrunkdev && jj simplify && jj'
alias jra='jj rebase -r @ -A @-'
alias jrb='jj rebase -r @ -B @-'
alias jdev='je DEV_CHANGES'
alias jrepush='jj tug && jj push && jj new -d DEV_CHANGES && jj'
alias jre='jrepush'
alias jrm='jj rebase-main && jj desc -m "Merge with main" && jj'
alias jrd='jj rebase-dev && jj desc -m "Merge with develop" && jj'
alias jprep='jj prepare -r @ && jj'
alias jpprep='jp && jprep'
alias jprepdev='jj preparedev -r @ && jj'
alias jfix='jj fix-pr'
alias jfp='jj fix-pr'
alias jdiffall='jj log -s -r "wipstack()" -T builtin_log_comfortable'
alias jstack='jj log -r "stack()"'
alias jdm='jj desc -m'
alias jd='jj desc'
alias js='jj squash'
alias jsu='jj squash -u'
alias jsdev='jj squash -i --into DEV_CHANGES'
alias jlogfridge='jj log -r "stack(FRIDGE)"'
alias jpark='jj new -d main@origin'


mkbranchname() {
  echo "$1" | tr "[:upper:]" "[:lower:]" |
    sed -E "s/[^a-z0-9._-]+/-/g" |
    sed -E "s/^[-.]+|[-.]+$//g" |
    sed -E "s/[-.]{2,}/-/g"
}

get_changeset_description() {
  jj st | sed -E 's/\x1b\[[0-9;]*m//g' |  # remove ANSI escape sequences
  awk -F' : ' '/^Working copy.*: / {
    # remove commit ID and change ID
    desc = $2
    n = split(desc, words, " ")
    if (n > 2) {
      # print from the third word onward
      for (i = 3; i <= n; i++) printf("%s%s", words[i], (i < n ? " " : "\n"))
    } else {
      print desc
    }
    exit
  }'
}

mkbranch() {
  local input="$*"
  if [[ -z "$input" ]]; then
    input=$(get_changeset_description)
  fi

  if [[ -z "$input" ]]; then
    echo "Error: No input and could not extract changeset description." >&2
    return 1
  fi

  local branch
  branch=$(mkbranchname "$input")
  jj bc "felipe/$branch"
}


jprfridge() {
  if [ -z "$1" ]; then
    echo "Usage: jjrebase <param>"
    return 1
  fi

  local param="$1"

  jj rebase -s "${param}+" -d "${param}+- ~ ${param}" \
    && jj rebase -s FRIDGE -d FRIDGE- -d "${param}"
}

junmerge() {
  jj rebase -s "description('WIP ALL')" -d "description('WIP ALL')- ~ $1"
}