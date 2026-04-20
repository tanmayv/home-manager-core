{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "hg-cl";
  runtimeInputs = with pkgs; [
    coreutils
    bash
    gnused
  ];

  text = ''
    # Add /usr/bin to PATH to find system hg/fig if needed, 
    # but writeShellApplication usually isolates PATH.
    # CitC hg is often a wrapper.
    export PATH="/usr/bin:/usr/local/bin:$PATH"

    if hg root > /dev/null 2>&1; then
      info=$(hg log -r . -T '{cl}|{desc|firstline}' 2>/dev/null)
      
      if [ -n "$info" ]; then
        cl=$(echo "$info" | cut -d'|' -f1)
        desc=$(echo "$info" | cut -d'|' -f2)
        
        if [ -z "$cl" ]; then
          cl="no-cl"
        fi
        
        max_len=25
        if [ ''${#desc} -gt "$max_len" ]; then
          desc="''${desc:0:$((max_len-3))}..."
        fi
        
        if [ -n "$desc" ]; then
          echo "CL:$cl [$desc]"
        else
          echo "CL:$cl"
        fi
      fi
    fi
  '';
}
