    # denvctl tab completion
    if command -v denvctl &>/dev/null; then
        compdef _denvctl denvctl
        eval "$(denvctl completion zsh)"
    fi
