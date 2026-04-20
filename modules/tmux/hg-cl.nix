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
      cl=$(hg log -r . -v 2>/dev/null | grep -oEi "cl/[0-9]+" | head -n 1 | cut -d/ -f2 || true)
      
      if [ -z "$cl" ]; then
        cl=$(hg log -r . -v 2>/dev/null | grep -oEi "change-[0-9]+" | head -n 1 || true)
      fi

      if [ -z "$cl" ]; then
        cl="no-cl"
      fi

      desc=$(hg log -r . -T '{desc|firstline}' 2>/dev/null || echo "")
      
      max_len=25
      if [ ''${#desc} -gt "$max_len" ]; then
        desc="''${desc:0:$((max_len-3))}..."
      fi
      
      cl_display="CL:$cl"
      # Wrap CL in a range for clicking. format: cl:NUMBER
      cl_part="#[range=user|cl:$cl]$cl_display#[norange]"

      if [ -n "$desc" ]; then
        echo "$cl_part [$desc]"
      else
        echo "$cl_part"
      fi
    fi
  '';
}
