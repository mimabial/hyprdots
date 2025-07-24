#  Startup 
# Commands to execute on startup (before the prompt is shown)
# Check if the interactive shell option is set
if [[ $- == *i* ]]; then
    # This is a good place to load graphic/ascii art, display system information, etc.
fi

#  Plugins 
# manually add your oh-my-zsh plugins here
plugins=(
    "sudo"
)

#   Overrides 
unset DENV_ZSH_NO_PLUGINS # Set to 1 to disable loading of oh-my-zsh plugins, useful if you want to use your zsh plugins system 
# unset DENV_ZSH_PROMPT # Uncomment to unset/disable loading of prompts from DENv and let you load your own prompts
# DENV_ZSH_COMPINIT_CHECK=1 # Set 24 (hours) per compinit security check // lessens startup time
# DENV_ZSH_OMZ_DEFER=1 # Set to 1 to defer loading of oh-my-zsh plugins ONLY if prompt is already loaded
