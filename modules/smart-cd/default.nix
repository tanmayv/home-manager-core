{ pkgs, lib, config, ... }:

with lib;

let
  cfg = config.programs.smart-cd;
in
{
  options.programs.smart-cd = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable smart-cd feature";
    };
    maxParents = mkOption {
      type = types.int;
      default = 4;
      description = "Maximum number of parent directories to show in cd --cs display";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.writeScriptBin "cd-cs" ''
        #!${pkgs.nushell}/bin/nu

        def main [...query: string] {
          let query_list = if ($query | is-empty) {
            let q = (input "CodeSearch Query: ")
            if ($q | is-empty) { exit 0 }
            [$q]
          } else if ($query | length) == 1 {
            # If single argument, it might be a quoted string containing multiple filters
            $query | get 0 | split row ' ' | each { str trim -c '"' }
          } else {
            # If multiple arguments, they are already split
            $query
          }
          
          let pwd = $env.PWD
          if not ($pwd | str contains "/google3") {
            print -e "Error: Must be run from within a google3 workspace."
            exit 1
          }
          
          let ws_root = ($pwd | str replace -r "/google3.*" "/google3")
          
          let full_query = ($query_list | append "trait:dir")
          
          # Run cs with --dirs and splat query
          # Use 'do { ... } | complete' to hide stderr noise from cs
          let res = (do { ^cs --dirs -- ...$full_query } | complete)
          let lines = ($res.stdout | lines | str replace -r "^.*/google3/" "")
              
          if ($lines | is-empty) {
            exit 0
          }

          let max_parents = ${toString cfg.maxParents}

          # Format paths for display
          let fzf_input = ($lines | each {|path|
            let stripped = ($path | str replace -r "/$" "")
            let parts = ($stripped | split row "/")
            let len = ($parts | length)
            let short = if $len > $max_parents {
              let last_parts = ($parts | last $max_parents | str join "/")
              $".../($last_parts)/"
            } else {
              $path
            }
            $"($path)|($short)"
          } | str join "\n")
              
          let selected = ($fzf_input | ^${pkgs.fzf}/bin/fzf --delimiter="\|" --with-nth 2 --prompt="Results> ")
            
          if ($selected | is-empty) {
            exit 0
          }
          
          let full_selected = ($selected | split row "|" | get 0)
          let dir = ($full_selected | str replace -r "/$" "")
          
          # Save result to file instead of printing
          ($ws_root | path join $dir) | save -f /tmp/cd-cs-result
        }
      '')
    ];
  };
}
