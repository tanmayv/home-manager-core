#!/bin/bash
VCS=$(/google/bin/releases/piper-fig/vcstool/vcstool debug-vcs-string)
if [[ "$VCS" == "fig" ]]; then
  hg addremove
fi
