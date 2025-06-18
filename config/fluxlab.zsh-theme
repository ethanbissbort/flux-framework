# oh-my-zsh FluxLabs Theme

_PATH="%U%F{white}%2~%f%u"

if [[ $EUID -eq 0 ]]; then
  _USERNAME="%F{red}%n%f"
  _LIBERTY="%F{red}#%f"
else
  _USERNAME="%F{130}%n%f"
  _LIBERTY="%F{116}$%f"
fi
_USERNAME="$_USERNAME%F{10}@%m%f"
_LIBERTY="$_LIBERTY"


get_space () {
  local STR=$1$2
  local zero='%([BSUbfksu]|([FB]|){*})'
  local LENGTH=${#${(S%%)STR//$~zero/}}
  local SPACES=$(( COLUMNS - LENGTH - ${ZLE_RPROMPT_INDENT:-1} ))

  (( SPACES > 0 )) || return
  printf ' %.0s' {1..$SPACES}
}

_1LEFT="%B%K{153}$_USERNAME%k %K{57}$_PATH%k%b"
_1RIGHT="[%* %w]"

fluxlabs_precmd () {
  _1SPACES=`get_space $_1LEFT $_1RIGHT`
  print
  print -rP "$_1LEFT$_1SPACES$_1RIGHT"
}

setopt prompt_subst
PROMPT='> $_LIBERTY '
# RPROMPT='$_1LEFT $_1RIGHT'


autoload -U add-zsh-hook
add-zsh-hook precmd fluxlabs_precmd
