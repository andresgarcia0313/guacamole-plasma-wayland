# shellcheck shell=bash disable=SC2016
# Startup file of the web terminal (bash --rcfile <this file> -i).
# Loads the normal user environment but not the systemd OSC 3008 context of
# /etc/profile.d/80-systemd-osc-context.sh, which the Guacamole terminal prints as text
# ("start=...;machineid=..."). ~/.profile already loads ~/.bashrc for bash.
[ -f "$HOME/.profile" ] && . "$HOME/.profile"

# In case another profile installed it anyway
unset -f __systemd_osc_context_precmdline __systemd_osc_context_ps0 2>/dev/null
PS0=${PS0//'$(__systemd_osc_context_ps0)'/}
if declare -p PROMPT_COMMAND 2>/dev/null | grep -q '^declare -a'; then
    PROMPT_COMMAND=("${PROMPT_COMMAND[@]/__systemd_osc_context_precmdline/}")
fi
