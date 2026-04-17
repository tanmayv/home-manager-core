{ ... }: {
  programs.zsh.initContent = ''
    # Display current time in prompt
    function precmd_time() {
      print -P "%F{yellow}%*%f"
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd precmd_time
  '';
}
