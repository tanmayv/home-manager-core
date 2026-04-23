{ pkgs, ... }:

let
  twatch = pkgs.writeScriptBin "twatch" ''
    #!${pkgs.nushell}/bin/nu

    def is_user_here [current_session: string, current_window: string] {
        let clients = (^${pkgs.tmux}/bin/tmux list-clients -F '#{client_session}' | lines)
        if ($clients | is-empty) { return false }
        
        for client_session in $clients {
            if $client_session == $current_session {
                let active_window = (^${pkgs.tmux}/bin/tmux display-message -p -t $client_session '#I' | str trim)
                if $active_window == $current_window {
                    return true
                }
            }
        }
        return false
    }

    def get_target_session [current_session: string] {
        let clients = (^${pkgs.tmux}/bin/tmux list-clients -F '#{client_session}' | lines)
        if ($clients | is-empty) { return null }
        
        # Try to find a session that isn't the current one
        for client in $clients {
            if $client != $current_session {
                return $client
            }
        }
        
        # Fallback to the first client
        return ($clients | first)
    }

    def main [
      ...cmd: string,  # The command to run
      --switch,        # Switch to Gemini window when done
      --ask            # Prompt user for input if away
    ] {
        let current_session = (^${pkgs.tmux}/bin/tmux display-message -p '#S' | str trim)
        let current_window = (^${pkgs.tmux}/bin/tmux display-message -p '#I' | str trim)
        let current_pane = (^${pkgs.tmux}/bin/tmux display-message -p '#P' | str trim)
        let cmd_str = ($cmd | str join " ")

        if $ask {
            if (is_user_here $current_session $current_window) {
                exit 0
            }

            let target_session = (get_target_session $current_session)
            if ($target_session == null) {
                exit 0
            }

            let message = if ($cmd_str | is-empty) { "Gemini is waiting for your input..." } else { $cmd_str }
            let content_lines = ($message | lines | length)
            let popup_height = $content_lines + 4

            let script = $"echo \"($message)\" && echo '--------------------------------------------------' && echo 'Press [Enter] to switch to Gemini window' && read"

            ^${pkgs.tmux}/bin/tmux display-popup -t $target_session -E -x R -y 0 -w 82 -h ($popup_height | into string) bash -c $script
            
            ^${pkgs.tmux}/bin/tmux switch-client -t $current_session
            ^${pkgs.tmux}/bin/tmux select-window -t $current_window
            ^${pkgs.tmux}/bin/tmux select-pane -t $current_pane
            exit 0
        }

        # Default watch behavior: run command and notify if away
        # We use `bash -c` to evaluate the command string properly as a shell command.
        let status = try {
            ^${pkgs.bash}/bin/bash -c $cmd_str
            0
        } catch { |err|
            1
        }

        if not (is_user_here $current_session $current_window) {
            let target_session = (get_target_session $current_session)
            if ($target_session != null) {
                let wrapped_cmd = ($cmd_str | ^${pkgs.coreutils}/bin/fold -s -w 76 | str trim)
                let message_body = $"CMD:\n($wrapped_cmd)\n--------------------------------------------------\nStatus: ($status) | Session: ($current_session)"
                let content_lines = ($message_body | lines | length)
                let popup_height = $content_lines + 3

                let script = $"echo \"($message_body)\" && read"
                ^${pkgs.tmux}/bin/tmux display-popup -t $target_session -E -x R -y 0 -w 82 -h ($popup_height | into string) bash -c $script
            }
        }

        if $switch {
            ^${pkgs.tmux}/bin/tmux switch-client -t $current_session
            ^${pkgs.tmux}/bin/tmux select-window -t $current_window
            ^${pkgs.tmux}/bin/tmux select-pane -t $current_pane
        }
    }
  '';
in
{
  home.packages = [ twatch ];
}
