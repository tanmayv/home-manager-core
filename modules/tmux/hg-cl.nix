{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "hg-cl";
  runtimeInputs = with pkgs; [
    coreutils
    bash
    gnused
    gnugrep
    mercurial
  ];

  text = ''
    export PATH="/usr/bin:/usr/local/bin:$PATH"

    if hg root > /dev/null 2>&1; then
      # Extract CL number from verbose log
      # Look for 'cl/12345' format in pending or submitted CL lines
      cl=$(hg log -r . -v 2>/dev/null | grep -oEi "cl/[0-9]+" | head -n 1 | cut -d/ -f2 || true)
      
      if [ -z "$cl" ]; then
        # Fallback to change-N if no cl/NNN found
        cl=$(hg log -r . -v 2>/dev/null | grep -oEi "change-[0-9]+" | head -n 1 || true)
      fi

      if [ -z "$cl" ]; then
        cl="no-cl"
      fi

      # Get first line of description
      desc=$(hg log -r . -T '{desc|firstline}' 2>/dev/null || echo "")
      
      # Truncate description if too long
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
  '';
}
