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

    get_cl_info() {
      # Extract CL number from verbose log
      local cl
      cl=$(hg log -r . -v 2>/dev/null | grep -oEi "cl/[0-9]+" | head -n 1 | cut -d/ -f2 || true)
      
      if [ -z "$cl" ]; then
        cl=$(hg log -r . -v 2>/dev/null | grep -oEi "change-[0-9]+" | head -n 1 || true)
      fi

      if [ -z "$cl" ]; then
        cl="no-cl"
      fi
      echo "$cl"
    }

    if [[ "''${1:-}" == "--copy" ]]; then
      cl=$(get_cl_info)
      if [[ "$cl" != "no-cl" ]]; then
        # Use OSC 52 logic directly or call cl-copy
        # We'll just call cl-copy as it's already defined
        cl-copy "$cl"
      fi
      exit 0
    fi

    if hg root > /dev/null 2>&1; then
      cl=$(get_cl_info)

      # Get first line of description
      desc=$(hg log -r . -T '{desc|firstline}' 2>/dev/null || echo "")
      
      # Truncate description if too long
      max_len=25
      if [ ''${#desc} -gt "$max_len" ]; then
        desc="''${desc:0:$((max_len-3))}..."
      fi
      
      cl_display="CL:$cl"
      # Wrap CL in a range for clicking. argument: clinfo
      cl_part="#[range=user|clinfo]$cl_display#[norange]"

      if [ -n "$desc" ]; then
        echo "$cl_part [$desc]"
      else
        echo "$cl_part"
      fi
    fi
  '';
}
