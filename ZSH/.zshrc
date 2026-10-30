# zsh config shared by Linux (Debian/Ubuntu) and FreeBSD.
# Settings for both come first; OS-specific ones are in the 'case $OSTYPE'
# blocks for the environment and for aliases/functions.

# ---- settings ----
SUBNET='10.0.0.0/24'            # network scanned by 'netscan' (FreeBSD)

# start tmux with shell
#[[ -z $TMUX ]] && exec tmux

# autologout when no commands were entered for 60 min.
#export TMOUT=3600

export EDITOR='vi'
export PAGER='less'
export LESS='-giAMR'
# Debian/Ubuntu name the less preprocessor 'lesspipe' (elsewhere it's 'lesspipe.sh')
if (( $+commands[lesspipe] )); then
	export LESSOPEN='| lesspipe %s'
elif (( $+commands[lesspipe.sh] )); then
	export LESSOPEN='| lesspipe.sh %s'
fi
export LS_COLORS='di=32:ln=35:so=33:pi=31:ex=34:bd=34;40:cd=35;40:su=30;42:sg=37;42:tw=30;46:ow=31;46'
export LSCOLORS='cxfxdxbxexeafaachcagbg'
export CLICOLOR='1'

case $OSTYPE in
  linux*)
    export SYSTEMD_EDITOR='vi'
    export GREP_COLORS='mt=1;31'
    export PATH="${PATH}:$HOME/.local/bin"
    export XAUTHORITY=~/.Xauthority
    ;;
  freebsd*)
    #export GREP_COLOR='mt=1;31'
    # user-installed Ruby gems, for whichever Ruby versions are present
    # ((N) makes the pattern expand to nothing if the folder doesn't exist)
    path=($HOME/.local/share/gem/ruby/*/bin(N) $path)
    ;;
esac

PROMPT='%B%F{green}%n@%m:%/%f%b%#'
HISTFILE=$HOME/.zhistory
HISTSIZE=100000                 # lines kept in memory
SAVEHIST=100000                 # lines saved to $HISTFILE
LISTMAX=999

setopt notify                   # report the status of background jobs immediately
setopt correct                  # try to correct the spelling of commands
setopt auto_cd                  # if the command is the name of a directory, perform cd
setopt auto_list                # automatically list choices on an ambiguous completion
setopt auto_continue            # unsuspend suspended jobs on `disown' command
setopt chase_links              # resolve symlink to its real value when cd into it
setopt inc_append_history       # history lines are added to the $HISTFILE as soon as they are entered
setopt extended_history         # save command beginning timestamp and the duration
setopt hist_reduce_blanks       # remove superfluous blanks from history
setopt hist_ignore_all_dups     # if new command duplicates an older one, remove the older from history
setopt hist_save_no_dups        # when writing history, older commands that duplicate newer ones are omitted
setopt hist_ignore_space        # do not save line to the history list when first character is a space
setopt hist_verify              # perform history expansion and reload the line into the editing buffer
#setopt share_history           # share history between all sessions
setopt bang_hist                # perform textual history expansion, treating the character `!' specially
setopt rec_exact                # recognize exact matches even if they are ambiguous
setopt auto_pushd               # cd push the old directory onto the directory stack
setopt pushd_ignore_dups        # don't push multiple copies of the same directory onto the directory stack
setopt check_jobs               # report the status of jobs before exiting
setopt long_list_jobs           # list jobs in long format by default
setopt glob_complete            # do not insert all the words resulting from the wildcard expansion
setopt extended_glob            # treat the `#', `~' and `^' characters as part of patterns
#setopt dot_glob                # completion shows filenames beginning with a dot
setopt csh_null_glob            # report an error when all the patterns in a command have no matches
#unsetopt nomatch               # do not show an error when using glob without quotes
unsetopt hup                    # do not kill running jobs when shell exits
unsetopt auto_remove_slash      # disable automatic removing of slash
unsetopt prompt_sp              # do not preserve a partial line
unsetopt auto_menu              # do not use menu completion
#unsetopt always_last_prompt    # print completion suggestions above prompt
#unsetopt check_jobs            # don't complain about still running background jobs on exit
unsetopt beep                   # disable beep

autoload -Uz compinit; compinit
zstyle ':completion:*' verbose true
zstyle ':completion:*' use-cache true
zstyle ':completion:*' cache-path ~/.zsh/
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' completer _expand _complete _match
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*' file-sort links reverse
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:commands' rehash true
zstyle ':completion:*:functions' ignored-patterns '_*'
if [[ $OSTYPE = freebsd* ]]; then
zstyle ':completion:*:kill:*'   command "ps -U $USER"; else
zstyle ':completion:*:kill:*'   command "ps -u $USER"; fi
autoload -U select-word-style; select-word-style b

# select emacs keymap
bindkey -e

# alt+z/shift+alt+z
bindkey '\ez' undo
bindkey '\eZ' redo

# del key
bindkey '\e[3~' delete-char

# alt+del
bindkey '\e[3;3~' kill-word

# alt+left/right
bindkey '\e[1;3D' backward-kill-word
bindkey '\e[1;3C' kill-word

# alt+up/down
bindkey '\e[1;3A' backward-kill-line
bindkey '\e[1;3B' kill-line

# ctrl+left/right
bindkey '\e[1;5D' backward-word
bindkey '\e[1;5C' forward-word

# ctrl+up/down
bindkey '\e[1;5A' beginning-of-line
bindkey '\e[1;5B' end-of-line

# end/home
bindkey '\e[1~' beginning-of-line
bindkey '\e[4~' end-of-line
bindkey '\e[H' beginning-of-line
bindkey '\e[F' end-of-line

# pgup/pgdown
bindkey '\e[5~' up-line-or-history
bindkey '\e[6~' down-line-or-history

# up/down to autocomplete from history, moving cursor to end of line
autoload -U history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey '\e[A' history-beginning-search-backward-end
bindkey '\e[B' history-beginning-search-forward-end
bindkey '\eOA' history-beginning-search-backward-end
bindkey '\eOB' history-beginning-search-forward-end

# ctrl+alt+up/down to search history
bindkey '\e[1;7A' history-incremental-search-backward
bindkey '\e[1;7B' history-incremental-search-forward

# shift+tab - reverse menu
bindkey '\e[Z' reverse-menu-complete

# list dir with TAB, when there are only spaces/no text before cursor,
# or complete text, that is before cursor only (like in tcsh)
_tcsh_autolist() { if [[ -z ${LBUFFER// } ]]
        then BUFFER='ls ' CURSOR=3 zle list-choices
        else zle expand-or-complete-prefix; fi }
zle -N _tcsh_autolist
bindkey '\CI' _tcsh_autolist

# ctrl+b - return to previous dir
_back() { pushd +1 &> /dev/null && zle reset-prompt && zle -M "dirs: $(dirs)" }
zle -N _back
bindkey '\Cb' _back

# ctrl+f - resume job
_foreground() { CURSOR=0 LBUFFER+=' fg %' && zle accept-line }
zle -N _foreground
bindkey '\CF' _foreground

# ctrl+r - update shell history
_read_hist() { fc -R && zle -M 'history updated' }
zle -N _read_hist
bindkey '\CR' _read_hist

# alt+h - last 25 history lines
_last_hist() { zle -M "$(fc -rld -25)"}
zle -N _last_hist
bindkey "\eh" _last_hist

# alt+j - list jobs
_list_jobs() { zle -M "$(jobs -l)"}
zle -N _list_jobs
bindkey "\ej" _list_jobs

# ctrl+del - delete character from beginning of line
_del_first_char() { CURSOR=0 zle delete-char }
zle -N _del_first_char
bindkey "\e[3;5~" _del_first_char
bindkey "\e[3^" _del_first_char

# copy the current line with xclip, which needs an X display (not plain SSH).
# print -rn copies the line exactly; echo would turn \n, \t etc. into real ones.
_xclip_copy() {  # $1 = clipboard | primary
  [[ -n $BUFFER ]] || return
  if (( ! $+commands[xclip] )) || [[ -z $DISPLAY ]]; then
    zle -M ' copy needs xclip and an X display'
  elif print -rn -- "$BUFFER" | xclip -in -selection $1 &> /dev/null; then
    zle -M " copied to ${(U)1}"
  else
    zle -M ' copy failed'
  fi
}

# alt+c - copy current line to CLIPBOARD
_clipcopy() { _xclip_copy clipboard }
zle -N _clipcopy
bindkey "\ec" _clipcopy

# ctrl+insert - copy current line to PRIMARY
_primcopy() { _xclip_copy primary }
zle -N _primcopy
bindkey "\e[2;5~" _primcopy
bindkey "\e[2^" _primcopy

# alias -es
alias	c='cat'
alias	r='readlink -f'
alias	history='fc -l -E 1'
alias	...='../..'
alias	....='../../..'
alias	.....='../../../..'
alias	grep='grep --color'
alias	g='grep -i'
alias	l='less'
alias	la='ls -a'
alias	rm='rm -I'
alias	v='vi'
alias	e='builtin echo'
alias	du='du -h'
alias	mkdir='mkdir -p'
alias	tkill='tmux kill-session -t'

# sudo shortcuts
alias	chown='sudo chown'
alias	chmod='sudo chmod'
alias	srm='sudo rm'
alias	svi='sudo vi'
alias	reboot='sudo reboot'
alias	service='sudo service'

case $OSTYPE in
  linux*)
    alias	ll='ls -lhAF --color'
    alias	s='sudo '  # trailing space: also expand an alias after it, e.g. 's ll'
    alias	ups='upsc ups@localhost'
    alias	logg='sudo tail -f'
    alias	upgrade='apt update && apt upgrade -y'

    # sudo shortcuts
    alias	apt='sudo apt'
    alias	dpkg='sudo dpkg'
    ;;
  freebsd*)
    alias	p='cd /usr/ports && cd'  # use it like "p www/firefox"
    alias	gnugrep='/usr/local/bin/grep --color'
    alias	ls='ls -FG'
    alias	ll='ls -lhTAF'
    alias	stat='stat -x'
    alias	cputemp='sysctl -a | grep "dev.cpu.*.temperature"'
    alias	logg='tail -f'
    alias	netscan='nmap -v -sn -n "$SUBNET" -oG - | awk '\''/Status: Down/{print $2}'\'

    # iocage shortcuts
    alias	iolist='iocage list -l'
    alias	iopkg='sudo iocage exec ALL pkg upgrade'
    alias	ioupdate='sudo iocage update ALL'
    alias	ioautoremove='sudo iocage exec ALL "pkg autoremove"'

    # sudo shortcuts
    alias	scat='sudo cat'
    alias	ss='sudo su'
    alias	pkg='sudo pkg'
    alias	apt='sudo pkg'
    alias	portmaster='sudo portmaster'
    alias	freebsd-update='sudo freebsd-update'

    # not to be disturbed by ctrl-s ctrl-q while using terminals:
    stty -ixon
    ;;
esac

# ---- Linux shell functions ----
if [[ $OSTYPE == linux* ]]; then

  # systemctl runs with sudo, except for --user, which must run as you
  systemctl() {
    if (( ${argv[(Ie)--user]} )); then
      command systemctl "$@"
    else
      sudo systemctl "$@"
    fi
  }

  # plain 'ps' shows full format (-f); with options, run them as given
  # (an alias would turn 'ps aux' into 'ps -f aux', mixing option styles)
  ps() {
    if (( $# )); then
      command ps "$@"
    else
      command ps -f
    fi
  }

  # snapremove [-r] <dataset>
  #   Destroy ALL snapshots of <dataset>. With -r, also every dataset beneath it.
  #   Shows counts and space to reclaim, then asks before deleting.
  snapremove() {
    local recurse=0 ds list d first last n ranges="" ans r
    [ "$1" = "-r" ] && { recurse=1; shift; }
    ds="${1%/}"
    [ -n "$ds" ] || { echo "usage: snapremove [-r] <dataset>"; return 1; }
    case "$ds" in *@*) echo "pass a dataset, not a snapshot"; return 1;; esac
    zfs list -H -o name "$ds" >/dev/null 2>&1 || { echo "no such dataset: $ds"; return 1; }

    if [ "$recurse" = 1 ]; then list=$(zfs list -H -o name -r "$ds"); else list="$ds"; fi

    echo "Would destroy:"
    while read -r d; do
      first=$(zfs list -H -t snapshot -o name -s creation -d 1 "$d" | head -1 | cut -d@ -f2)
      [ -n "$first" ] || continue
      last=$(zfs list -H -t snapshot -o name -s creation -d 1 "$d" | tail -1 | cut -d@ -f2)
      n=$(zfs list -H -t snapshot -o name -d 1 "$d" | wc -l | tr -d ' ')
      echo "  $d: $n snapshot(s), $(sudo zfs destroy -nv "$d@$first%$last" | tail -1)"
      ranges+="$d@$first%$last"$'\n'
    done <<< "$list"

    [ -n "$ranges" ] || { echo "  (no snapshots found)"; return 0; }
    printf "Destroy all of these? [y/N] "
    read -r ans
    case "$ans" in y|Y) ;; *) echo "cancelled"; return 1;; esac
    printf '%s' "$ranges" | while read -r r; do
      [ -n "$r" ] && sudo zfs destroy -v "$r"
    done
  }

fi
