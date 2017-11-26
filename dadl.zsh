# dadl
# by Sean Liao
# https://github.com/seankhliao/dadl
# MIT License
# heavily inspired (copied from)
# Pure
# by Sindre Sorhus
# https://github.com/sindresorhus/pure
# MIT License

# For my own and others sanity
# prompt:
# %F => color dict
# %f => reset color
# %~ => current path
# %* => time
# %n => username
# %m => shortname host
# %(?..) => prompt conditional - %(condition.true.false)
# terminal codes:
# \e7   => save cursor position
# \e[2A => move cursor 2 lines up
# \e[1G => go to position 1 in terminal
# \e8   => restore cursor position
# \e[K  => clears everything after the cursor on the current line
# \e[2K => clear everything on the current line


dadl_preexec() {
    # create/store current time in (global) var
    # starts before command exec
    # total_time = finish_time (next_prompt_cmd_time) - this_time_stamp
    typeset -g dadl_timestamp=$EPOCHSECONDS
}


dadl_render() {
    setopt localoptions noshwordsplit

    # Initialize the preprompt array.
    local -a preprompt_parts

    # Set the path.
    preprompt_parts+=('%F{blue}%~%f')

    # Username and machine, if applicable.
    [[ -n $dadl_userhost ]] && preprompt_parts+=('$dadl_userhost')
    # Execution time.
    [[ -n $dadl_exectime ]] && preprompt_parts+=('%F{yellow}${dadl_exectime}%f')

    local cleaned_ps1=$PROMPT
    local -H MATCH MBEGIN MEND
    if [[ $PROMPT = *$prompt_newline* ]]; then
        # When the prompt contains newlines, we keep everything before the first
        # and after the last newline, leaving us with everything except the
        # preprompt. This is needed because some software prefixes the prompt
        # (e.g. virtualenv).
        cleaned_ps1=${PROMPT%%${prompt_newline}*}${PROMPT##*${prompt_newline}}
    fi
    unset MATCH MBEGIN MEND

    # Construct the new prompt with a clean preprompt.
    local -ah ps1
    ps1=(
    $prompt_newline           # Initial newline, for spaciousness.
    ${(j. .)preprompt_parts}  # Join parts, space separated.
    $prompt_newline           # Separate preprompt and prompt.
    $cleaned_ps1
    )

    PROMPT="${(j..)ps1}"
}

dadl_precmd() {
    # calculates exectime (or 0) and stores it in dadl_exectime
    # also clears dadl_timestamp
    integer elapsed
    (( elapsed = EPOCHSECONDS - ${dadl_timestamp:-$EPOCHSECONDS} ))

    # turns seconds into human readable time
    # 165392 => 1d 21h 56m 32s
    # https://github.com/sindresorhus/pretty-time-zsh
    local human
    local days=$(( elapsed / 60 / 60 / 24 ))
    local hours=$(( elapsed / 60 / 60 % 24 ))
    local minutes=$(( elapsed / 60 % 60 ))
    local seconds=$(( elapsed % 60 ))
    (( days > 0 )) && human+="${days}d "
    (( hours > 0 )) && human+="${hours}h "
    (( minutes > 0 )) && human+="${minutes}m "
    human+="${seconds}s"
    # store human readable time in variable as specified by caller
    typeset -g dadl_exectime="${human}"
    unset dadl_timestamp

    # if activated, store screen address in psvar
    psvar[10]=
    [[ -n $STY ]] && psvar[10]="${STY%.*}"

    # store name of virtualenv in psvar if activated
    psvar[12]=
    [[ -n $VIRTUAL_ENV ]] && psvar[12]="${VIRTUAL_ENV:t}"

    # show username@host if logged in through SSH
    [[ "$SSH_CONNECTION" != '' ]] && dadl_userhost='%F{242}%n@%m%f'

    dadl_render
}

dadl_prompt() {
    # ==================== Cleanup
    # Prevent percentage showing up if output doesn't end with a newline.
    export PROMPT_EOL_MARK=''

    # disallow python virtualenvs from updating the prompt
    export VIRTUAL_ENV_DISABLE_PROMPT=1

    # ==================== Safeguard Initialization
    prompt_opts=(subst percent)
    # borrowed from promptinit, sets the prompt options in case pure was not
    # initialized via promptinit.
    setopt noprompt{bang,cr,percent,subst} "prompt${^prompt_opts[@]}"
    if [[ -z $prompt_newline ]]; then
        # This variable needs to be set, usually set by promptinit.
        typeset -g prompt_newline=$'\n%{\r%}'
    fi

    # ==================== Hooks
    zmodload zsh/datetime
    zmodload zsh/zle
    zmodload zsh/parameter

    autoload -Uz add-zsh-hook

    add-zsh-hook precmd  dadl_precmd
    add-zsh-hook preexec dadl_preexec

    # ==================== Vars that affect prompt

    # if screen is activated, display it
    PROMPT='%(10V.%F{242}%10v%f .)'
    # if a virtualenv is activated, display it in grey
    PROMPT+='%(12V.%F{242}%12v%f .)'

    # prompt turns red if the previous command didn't exit with 0
    PROMPT+='%(?.%F{magenta}.%F{red})'
    # add hostname to prompt if not local
    [[ "$SSH_CONNECTION" != '' ]] && PROMPT+='%m'
    # prompt symbol
    PROMPT+='»%f '
}


dadl_prompt
