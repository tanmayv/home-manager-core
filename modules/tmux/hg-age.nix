{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "hg-age";
  runtimeInputs = with pkgs; [
    coreutils
    bash
    mercurial
  ];

  text = ''
    export PATH="/usr/bin:/usr/local/bin:$PATH"
    if hg root > /dev/null 2>&1; then
      commit_timestamp=$(hg log -r p4head -T '{date}' 2>/dev/null | cut -d. -f1 || true)

      if [ -n "$commit_timestamp" ]; then
        current_timestamp=$(date +%s)
        diff_seconds=$((current_timestamp - commit_timestamp))

        age_str=""
        if [ "$diff_seconds" -lt 60 ]; then
          age_str="<1m"
        elif [ "$diff_seconds" -lt 3600 ]; then
          age_str="$((diff_seconds / 60))m"
        elif [ "$diff_seconds" -lt 86400 ]; then
          age_str="$((diff_seconds / 3600))h"
        else
          age_str="$((diff_seconds / 86400))d"
        fi
        
        display_str="Last Sync: $age_str ago"
        echo "#[range=user|ageinfo]$display_str#[norange]"
      fi
    fi
  '';
}
