{ pkgs, ... }:
let
  googPromptContent = ''
########################################
# go/goog_prompt
#
# version: 3.0
# author: Justin Bishop
# email: jubi@google.com
########################################

##### BEGIN ENV settings #####

# Space reserved between left and right prompt
export -i PROMPT_SPACE=''${PROMPT_SPACE:-41}

# The start of our left prompt
export PROMPT_PREFIX=''${PROMPT_PREFIX:-$USER}

# The end of our left prompt
export PROMPT_SUFFIX="''${PROMPT_SUFFIX:-#>}"

# Maxmimum length of our left prompt
export MAX_PROMPT_LENGTH=80

# Hours before we care about staleness
export -i STALENESS_THRESHOLD=''${STALENESS_THRESHOLD:-20}

# Check the status of go/alices on every enter
export ALWAYS_UPDATE_ALICES=true

# Prompt colors
typeset -Ag clr=(
  path 123
  wkspace 207
  src 39
  home 154
  prefix 190
  merge_warn white
  p4head 1
  tip 154
  patched 165
  rollback 214
  stale 207
  author 45
  div white
  cl_updated green
  cl_willupdate yellow
  cl_unsubmitted magenta
  dirty yellow
  clean green
  unresolved red
  lgtm green
  mailed blue
  pending yellow
  deleted 8
  submitted magenta
  not_uploaded white
  lgtm_reviewers green
  pending_reviewers white
  actionable_analyses red
  running_analyses yellow
  complete_analyses 8
)

# Prompt messages
typeset -Ag message=(
  home '🏠'
  merge_warn '❗%K{196}%BDo not amend! (Merge)%b%k'
  p4head '⚓️'
  tip '➳'
  patched '℞'
  rollback '⟳'
  stale '🕑$VCS_STATUS[stale]h'
  author '🙋$(create_link $AUTHOR http://who/$AUTHOR)'
  shortest_node '🔰$SHORTEST_NODE'
  cl_updated '✅$(create_link $CHANGELIST http://$CHANGELIST)'
  cl_willupdate '☑️ $(create_link $CHANGELIST http://$CHANGELIST)'
  cl_unsubmitted '☑️ $(create_link $CHANGELIST http://$CHANGELIST)'
  desc '✏️️ $COMMIT_MESSAGE'
  dirty '🧹'
  clean '''
  unresolved '$(create_link UNRESOLVED ''${ALICES[lgtm_reviewers]:+\(''${ALICES[lgtm_reviewers]}\) }''${ALICES[pending_reviewers]})'
  lgtm '$(create_link LGTM ''${ALICES[lgtm_reviewers]:+\(''${ALICES[lgtm_reviewers]}\) }\ ''${ALICES[pending_reviewers]})'
  mailed '$(create_link MAILED ''${ALICES[lgtm_reviewers]:+\(''${ALICES[lgtm_reviewers]}\) }''${ALICES[pending_reviewers]})'
  pending '$(create_link PENDING ''${ALICES[lgtm_reviewers]:+\(''${ALICES[lgtm_reviewers]}\) }''${ALICES[pending_reviewers]})'
  deleted '$(create_link DELETED ''${ALICES[lgtm_reviewers]:+\(''${ALICES[lgtm_reviewers]}\) }''${ALICES[pending_reviewers]})'
  submitted '$(create_link SUBMITTED ''${ALICES[lgtm_reviewers]:+\(''${ALICES[lgtm_reviewers]}\) }''${ALICES[pending_reviewers]})'
  lgtm_reviewers '''
  pending_reviewers '''
  actionable_analyses '$(create_link ● $ALICES[actionable_analyses])'
  running_analyses '$(create_link ● $ALICES[running_analyses])'
  complete_analyses '''
)

export cloudHome="/google/src/cloud/$USER"

##### END ENV settings #####

##### BEGIN Workspace identification #####

# Workspace name
function workspace() {
  # Use :A parameter expansion to resolve symlinks to /google/src
  # http://zsh.sourceforge.net/Doc/Release/Expansion.html#index-parameter-expansion-flags
  if [[ $PWD:A =~ "$cloudHome/([^/]+)" ]]; then
    echo ''${match[1]}
  fi
}

# Absolute directory of our workspace
function workspace_dir() {
  if [[ $WORKSPACE != "" ]]; then
    echo "$cloudHome/$WORKSPACE/google3"
  fi
}

# Relative path after google3/
function source_pwd() {
  local wkspace_dir=$(workspace_dir)
  if [[ -n "$wkspace_dir" ]]; then
    echo "$PWD[''${#wkspace_dir}+2,''${#PWD}]"
  fi
}

##### END Workspace identification #####

##### BEGIN VCS analysis #####

# Creates a clickable link in the terminal
function create_link() {
  echo "\e]8;;$2\a$1\e]8;;\a"
}

# Clears out our exported vars
function unset_vcs_info() {
  RPROMPT=""
  unset AUTHOR SHORTEST_NODE CHANGELIST COMMIT_MESSAGE
  typeset -Ag VCS_STATUS=()
}

# Kicks off async request for vcs info
function fetch_vcs_info() {
  unset_vcs_info
  if [[ -z $WORKSPACE || ! -d $cloudHome/$WORKSPACE/.hg ]]; then return; fi

  local worker_cmds=(
    'chg log --rev p4base -T ":{date}\\n";'
    'chg log --follow -l 1 -T "'
      ':{emailuser(author)}\\n'
      ':{parents}\\n'
      ':{node|shortest}\\n'
      ':{clpreferredname}\\n'
      ':{clnumber}\\n'
      ':{p4head}\\n'
      ':{patchedcl}\\n'
      ':{rollback_cl}\\n'
      ':{tags}\\n'
      ':{willupdatecl}\\n'
      ':{GOOG_trim_desc(desc)}\\n'
      ':{if(alices, alices.status)}\\n'
      ':{if(alices, alices.lgtms)}\\n'
      ':{if(alices, alices.pendings)}\\n'
      ':{if(alices, alices.actionable)}\\n'
      ':{if(alices, alices.running)}\\n'
      ':{if(alices, alices.complete)}\\n";'
    'chg status -mard -T ":{status}"'
  )

  async_worker_eval vcs_worker cd $PWD
  async_job vcs_worker eval ''${(j::)worker_cmds}
}

# exports $AUTHOR $SHORTEST_NODE $CHANGELIST $COMMIT_MESSAGE $ALICES $HG_STATUS
#         $VCS_STATUS
function update_vcs_info() {
  unset_vcs_info

  # If we got an error, we need to kick off the service again
  if [[ $2 -ne 0 ]]; then
    async_stop_worker vcs_worker
    async_unregister_callback vcs_worker
    async_flush_jobs vcs_worker
    async_start_worker vcs_worker
    async_register_callback vcs_worker update_vcs_info
    fetch_vcs_info
    return
  fi

  if [[ $1 != "eval" || -z $WORKSPACE ]]; then return; fi

  # If there's already another queued, we throw this one away
  if [[ $6 -eq 1 ]]; then return; fi

  # Extract values from reply
  local -a values=("''${(f)3}")
  local -i p4date="''${values[1]:1}"
  export AUTHOR="''${values[2]:1}"
  local -a parents=($''${=values[3]:1})
  export SHORTEST_NODE="''${values[4]:1}"
  export CHANGELIST="''${values[5]:1}"
  local clnumber="''${values[6]:1}"
  local p4head="''${values[7]:1}"
  local patchedcl="''${values[8]:1}"
  local rollbackcl="''${values[9]:1}"
  local tags="''${values[10]:1}"
  local willupdatecl="''${values[11]:1}"
  local commit_message="''${values[12]:1}"
  # Shorten commit message to 67 chars at max (number determined from `man hg`)
  # Escape percent signs in the commit message
  if [[ $#commit_message -gt 67 ]]; then
    export COMMIT_MESSAGE="''${commit_message[1,64]:gs/%/%%}..."
  else
    export COMMIT_MESSAGE=''${commit_message[1,64]:gs/%/%%}
  fi
  typeset -Ag ALICES=()
  export ALICES[cl_status]="''${values[13]:1}"
  export ALICES[lgtm_reviewers]="''${values[14]:1}"
  export ALICES[pending_reviewers]="''${values[15]:1}"
  export ALICES[actionable_analyses]="''${values[16]:1}"
  export ALICES[running_analyses]="''${values[17]:1}"
  export ALICES[complete_analyses]="''${values[18]:1}"
  export HG_STATUS=''${''${"''${values[19]:1}":+DIRTY}:-CLEAN}

  # Set various VCS_STATUS
  local -i now=$(date +"%s")
  local -i diff; ((diff = ($now - $p4date) / 3600))
  if [[ $diff -ge $STALENESS_THRESHOLD ]]; then
    VCS_STATUS[stale]=$diff
  fi
  if [[ $#parents -ge 2 ]]; then
    VCS_STATUS[merge]=$parents
  fi
  if [[ $clnumber =~ "\b([0-9]+)\b" ]]; then
    VCS_STATUS[clnumber]=''${match[1]}
  fi
  if [[ $p4head == "p4head" ]]; then
    VCS_STATUS[p4head]=1
  fi
  if [[ $patchedcl =~ "\b([0-9]+)\b" ]]; then
    VCS_STATUS[patched_cl]=''${match[1]}
  fi
  if [[ $rollbackcl =~ "\b([0-9]+)\b" ]]; then
    VCS_STATUS[rollback_cl]=''${match[1]}
  fi
  if [[ $tags =~ "\btip\b" ]]; then
    VCS_STATUS[tip]=1
  fi
  if [[ $willupdatecl =~ "\b([0-9]+)\b" ]]; then
    VCS_STATUS[willupdate_cl]=''${match[1]}
  fi

  # Update the prompt then tell ZSH to redraw it
  update_rprompt
  zle && zle reset-prompt
}

# Updated in precmd, used to track fig changes
local vcs_mtime=""
function get_vcs_mtime() {
  case `uname` in
    Darwin)
      local statArgs="-f%c"
    ;;
    Linux)
      local statArgs="-c %Z"
    ;;
  esac
  local mtime=""
  if [[ -f $cloudHome/$WORKSPACE/.hg/dirstate ]]; then
    mtime+="$(/usr/bin/stat $statArgs $cloudHome/$WORKSPACE/.hg/dirstate)"
  fi
  if [[ -f $cloudHome/$WORKSPACE/.hg/store/review__units ]]; then
    mtime+="-$(/usr/bin/stat $statArgs $cloudHome/$WORKSPACE/.hg/store/review__units)"
  fi
  echo $mtime
}

# Setup async worker for getting VCS info
async_start_worker vcs_worker
async_register_callback vcs_worker update_vcs_info

# Kicks off async request for alices
function fetch_alices() {
  if [[ -z $WORKSPACE || ! -d $cloudHome/$WORKSPACE/.hg ]]; then return; fi

  local worker_cmds=(
    'chg log --follow -l 1 -T "'
      ':{if(alices, alices.status)}\\n'
      ':{if(alices, alices.lgtms)}\\n'
      ':{if(alices, alices.pendings)}\\n'
      ':{if(alices, alices.actionable)}\\n'
      ':{if(alices, alices.running)}\\n'
      ':{if(alices, alices.complete)}"'
  )

  async_worker_eval alices_worker cd $PWD
  async_job alices_worker eval ''${(j::)worker_cmds}
}

# exports $ALICES
function update_alices() {
  # If we got an error, we need to kick off the service again
  if [[ $2 -ne 0 ]]; then
    async_stop_worker alices_worker
    async_unregister_callback alices_worker
    async_flush_jobs alices_worker
    async_start_worker alices_worker
    async_register_callback alices_worker update_alices
    fetch_alices
    return
  fi

  if [[ $1 != "eval" || -z $WORKSPACE ]]; then return; fi

  # If there's already another queued, we throw this one away
  if [[ $6 -eq 1 ]]; then return; fi

  # Extract values from reply
  local -a values=("''${(f)3}")
  typeset -Ag ALICES=()
  export ALICES[cl_status]="''${values[1]:1}"
  export ALICES[lgtm_reviewers]="''${values[2]:1}"
  export ALICES[pending_reviewers]="''${values[3]:1}"
  export ALICES[actionable_analyses]="''${values[4]:1}"
  export ALICES[running_analyses]="''${values[5]:1}"
  export ALICES[complete_analyses]="''${values[6]:1}"

  # Update the prompt then tell ZSH to redraw it
  update_rprompt
  zle && zle reset-prompt
}

# Setup async worker for getting VCS info
async_start_worker alices_worker
async_register_callback alices_worker update_alices

##### END VCS analysis #####

##### BEGIN Prompt management #####

# expand vars in message array and escape link chars
function render_message() {
  local msg=$(eval echo \"$1\")
  # surround non-printable chars with %{...%}
  msg=''${(S)msg//$'\e'/$'%{\e'}
  msg=''${(S)msg//$'\a'/$'\a%}'}

  echo $msg
}

# strip away any non-printable formatting chars
function stripped() {
  # Strip %S, %s, %B, %b, %U, %u, %f, and %k
  local stripped=''${(S)1//\%[SsBbUufk]/}
  # Strip out %F{...} and %K{...}
  stripped=''${(S)stripped//\%[FK]{*}/}
  # Strip out %{...%}
  stripped=''${(S)stripped//\%{*\%}/}

  echo $stripped
}

# get the length of a string after stripping non-printable chars
function get_length() {
  local stripped=$(stripped $1)
  echo $#stripped
}

# get the color for CL indicators
function get_cl_color() {
  if [[ -n $VCS_STATUS[willupdate_cl] ]]; then
    echo $clr[cl_willupdate]
  elif [[ -n $VCS_STATUS[clnumber] ]]; then
    echo $clr[cl_updated]
  elif [[ -n $CHANGELIST ]]; then
    echo $clr[cl_unsubmitted]
  else
    return 1
  fi
}

# get the number for CL
function get_cl_number() {
  if [[ -n $VCS_STATUS[willupdate_cl] ]]; then
    echo $(render_message $message[cl_willupdate])
  elif [[ -n $VCS_STATUS[clnumber] ]]; then
    echo $(render_message $message[cl_updated])
  elif [[ -n $CHANGELIST ]]; then
    echo $(render_message $message[cl_unsubmitted])
  else
    return 1
  fi
}

# Updated by update_prompt
local -i PROMPT_SIZE=0

# Fetches new RPROMPT string
function get_rprompt() {
  if [[ -z $WORKSPACE || -z $vcs_mtime ]]; then
    echo "" && return
  fi

  # Build an array of RPROMPT elements to join at the end
  local rprompt=()

  # Calculate total columns available for rprompt
  local -i avail_columns
  ((avail_columns = $COLUMNS - $PROMPT_SIZE - $PROMPT_SPACE))

  # Indicate whether our workspace is dirty or clean
  local dirty=$(render_message $message[dirty])
  local clean=$(render_message $message[clean])
  if [[ -n $dirty && $HG_STATUS = DIRTY ]]; then
    rprompt+=("%F{$clr[dirty]}$dirty%f")
    ((avail_columns = $avail_columns - $(get_length $dirty) - 1))
  elif [[ -n $clean && $HG_STATUS = CLEAN ]]; then
    rprompt+=("%F{$clr[clean]}$clean%f")
    ((avail_columns = $avail_columns - $(get_length $clean) - 1))
  fi

  # If we're stale, display the stale symbol
  local stale=$(render_message $message[stale])
  if [[ -n $stale && -n $VCS_STATUS[stale] ]]; then
    rprompt+=("%F{$clr[stale]}$stale%f")
    ((avail_columns = $avail_columns - $(get_length $stale) - 1))
  fi

  # If we're at tip, display the tip symbol
  local tip=$(render_message $message[tip])
  if [[ -n $tip && $VCS_STATUS[tip] -eq 1 ]]; then
    rprompt+=("%F{$clr[tip]}$tip%f")
    ((avail_columns = $avail_columns - $(get_length $tip) - 1))
  fi

  # If we're at p4head, display the p4head symbol
  local p4head=$(render_message $message[p4head])
  if [[ -n $p4head && $VCS_STATUS[p4head] -eq 1 ]]; then
    rprompt+=("%F{$clr[p4head]}$p4head%f")
    ((avail_columns = $avail_columns - $(get_length $p4head) - 1))
  fi

  # If we're a patch, display the patch symbol
  local patched=$(render_message $message[patched])
  if [[ -n $patched && -n $VCS_STATUS[patched_cl] ]]; then
    rprompt+=("%F{$clr[patched]}$patched%f")
    ((avail_columns = $avail_columns - $(get_length $patched) - 1))
  fi

  # If we're a rollback, display the rollback symbol
  local rollback=$(render_message $message[rollback])
  if [[ -n $rollback && -n $VCS_STATUS[rollback_cl] ]]; then
    rprompt+=("%F{$clr[rollback]}$rollback%f")
    ((avail_columns = $avail_columns - $(get_length $rollback) - 1))
  fi

  # We show evil merge warning no matter what, then end it
  local merge_warn=$(render_message $message[merge_warn])
  if [[ -n $merge_warn && -n $VCS_STATUS[merge] ]]; then
    rprompt+=("%F{$clr[merge_warn]}$merge_warn%f")
    echo ''${(j: :)rprompt} && return
  fi

  # Display author if it's not us and we're not p4head
  local author=$(render_message $message[author])
  local author_length=$(get_length $author)
  local username=$(render_message '$AUTHOR')
  if [[ -n $author && -n $AUTHOR && ! $(stripped $username) = $USER &&
        ! $VCS_STATUS[p4head] -eq 1 &&
        $avail_columns -ge $author_length ]]; then
    rprompt+=("%F{$clr[author]}$author%f")
    ((avail_columns = $avail_columns - $author_length - 1))
  fi

  # Adding any changelist info
  if [[ -n $CHANGELIST ]]; then
    # Display shortest node
    local shortest_node=$(render_message $message[shortest_node])
    local shortest_node_length=$(get_length $shortest_node)
    if [[ -n $shortest_node && -n $SHORTEST_NODE &&
          $avail_columns -ge $shortest_node_length ]]; then
      if [[ -n $clr[shortest_node] ]]; then
        rprompt+=("%F{$clr[shortest_node]}$shortest_node%f")
      else
        rprompt+=("%F{$(get_cl_color)}$shortest_node%f")
      fi
      ((avail_columns = $avail_columns - $shortest_node_length - 1))
    fi

    # Display the CL number if we have enough room
    local cl_number=$(get_cl_number)
    local cl_number_length=$(get_length $cl_number)
    if [[ -n $cl_number && $avail_columns -ge $cl_number_length ]]; then
      rprompt+=("%F{$(get_cl_color)}$cl_number%f")
      ((avail_columns = $avail_columns - $cl_number_length - 1))
    fi

    # Display the CL status if we have enough room
    local cl_status=$(render_message $message[$ALICES[cl_status]:l])
    local cl_status_length=$(get_length $cl_status)
    if [[ -n $cl_status && -n $ALICES[cl_status] &&
          $avail_columns -ge $cl_status_length ]]; then
      rprompt+=("%F{$clr[$ALICES[cl_status]:l]}$cl_status%f")
      ((avail_columns = $avail_columns - $cl_status_length - 1))
    fi

    # Display the lgtm reviewers if we have enough room
    local lgtm_reviewers=$(render_message $message[lgtm_reviewers])
    local lgtm_reviewers_length=$(get_length $lgtm_reviewers)
    if [[ -n $lgtm_reviewers && -n $ALICES[lgtm_reviewers] &&
          $avail_columns -ge $lgtm_reviewers_length ]]; then
      rprompt+=("%F{$clr[lgtm_reviewers]}$lgtm_reviewers%f")
      ((avail_columns = $avail_columns - $lgtm_reviewers_length - 1))
    fi

    # Display the pending reviewers if we have enough room
    local pending_reviewers=$(render_message $message[pending_reviewers])
    local pending_reviewers_length=$(get_length $pending_reviewers)
    if [[ -n $pending_reviewers && -n $ALICES[pending_reviewers] &&
          $avail_columns -ge $pending_reviewers_length ]]; then
      rprompt+=("%F{$clr[pending_reviewers]}$pending_reviewers%f")
      ((avail_columns = $avail_columns - $pending_reviewers_length - 1))
    fi

    # Display the actionable analyses if we have enough room
    local actionable_analyses=$(render_message $message[actionable_analyses])
    local actionable_analyses_length=$(get_length $actionable_analyses)
    if [[ -n $actionable_analyses && -n $ALICES[actionable_analyses] &&
          $avail_columns -ge $actionable_analyses_length ]]; then
      rprompt+=("%F{$clr[actionable_analyses]}$actionable_analyses%f")
      ((avail_columns = $avail_columns - $actionable_analyses_length - 1))
    fi

    # Display the running analyses if we have enough room
    local running_analyses=$(render_message $message[running_analyses])
    local running_analyses_length=$(get_length $message[running_analyses])
    if [[ -n $running_analyses && -n $ALICES[running_analyses] &&
          $avail_columns -ge $running_analyses_length ]]; then
      rprompt+=("%F{$clr[running_analyses]}$running_analyses%f")
      ((avail_columns = $avail_columns - $running_analyses_length - 1))
    fi

    # Display the complete analyses if we have enough room
    local complete_analyses=$(render_message $message[complete_analyses])
    local complete_analyses_length=$(get_length $message[complete_analyses])
    if [[ -n $complete_analyses && -n $ALICES[complete_analyses] &&
          $avail_columns -ge $complete_analyses_length ]]; then
      rprompt+=("%F{$clr[complete_analyses]}$complete_analyses%f")
      ((avail_columns = $avail_columns - $complete_analyses_length - 1))
    fi
  fi

  # Display commit message if exists, we're not p4head, and we have room
  local desc=$(render_message $message[desc])
  if [[ -n $desc && -n $COMMIT_MESSAGE && ! $VCS_STATUS[p4head] -eq 1 &&
        $avail_columns -ge 5 ]]; then
    # Shorten commit message if neccessary
    if [[ $avail_columns -le $(get_length $desc) ]]; then
      # Get printable chars from desc
      # ex: $desc=%{some formatting%}commit message!%{more formatting%}
      # ex: $stripped_desc=commit message!
      local stripped_desc=$(stripped $desc)

      # Find what needs to be cut
      # ex: $desc_suffix_to_cut=essage!
      local desc_suffix_to_cut=$stripped_desc[(($avail_columns - 3)),-1]

      # Substitue "..." for the portion that needs to be cut (matching from end)
      # ex: $desc=%{some formatting%}commit m...%{more formatting%}
      desc=''${(S)desc/%$desc_suffix_to_cut/"..."}
    fi

    # If $clr[desc] is set, use that.
    # Otherwise if there is a $ALICES[cl_status] color, use that.
    # Else, use $clr[not_uploaded].
    rprompt+=(
      "%F{''${''${clr[desc]:-$clr[$ALICES[cl_status]:l]}:-$clr[not_uploaded]}}$desc%f"
    )
  fi

  echo ''${(j: :)rprompt:#}
}

# Make our RPROMPT work regardless of whether `prompt_subst` is set
function update_rprompt() {
  if [[ -o prompt_subst ]]; then
    RPROMPT='$(get_rprompt)'
  else
    RPROMPT=$(get_rprompt)
  fi
}

# Update prompt
function update_prompt() {
  if [[ -n $GP_IGNORE_LEFT_PROMPT ]]; then return; fi

  if [[ -n $INDICATOR_FUNCTION ]]; then
    local indicator=$($INDICATOR_FUNCTION)
  else
    local indicator="%F{green}⇪"
  fi
  PROMPT="$indicator%F{$clr[prefix]}$PROMPT_PREFIX%F{$clr[div]}:%f"

  # 1 for ":"
  ((PROMPT_SIZE = $(get_length $indicator) + $(get_length $PROMPT_PREFIX) + 1))

  local home_length=$(get_length $message[home])
  if [[ $PWD == $HOME ]]; then # If we're in $HOME, just show $message[home]
    PROMPT+="$message[home]"
    ((PROMPT_SIZE = PROMPT_SIZE + $home_length))
  elif [[ $PWD == $HOME* ]]; then # Or relative path to HOME
    local rel_home="''${PWD##$HOME/}"
    PROMPT+="$message[home]%F{$clr[home]}$rel_home%f"
    ((PROMPT_SIZE = PROMPT_SIZE + $#rel_home + $home_length))
  elif [[ $PWD == $(workspace_dir) ]]; then # Or just $WORKSPACE
    PROMPT+="%F{$clr[wkspace]}%B$WORKSPACE%b%f"
    ((PROMPT_SIZE = PROMPT_SIZE + $#WORKSPACE))
  else
    ((PROMPT_SIZE = PROMPT_SIZE + $#WORKSPACE))
    local src_pwd=$(source_pwd)
    if [[ -n $src_pwd ]]; then # Show relative path to workspace
      # Shorten relative path if necessary
      local -i avail_columns
      ((avail_columns = $MAX_PROMPT_LENGTH - $PROMPT_SIZE))
      if [[ $avail_columns -lt $#src_pwd ]]; then
        src_pwd=$src_pwd[(($#src_pwd - $avail_columns)),-1]
        src_pwd[1,3]='...'
      fi
      PROMPT+="%F{$clr[wkspace]}%B$WORKSPACE%b%F{$clr[div]}/%F{$clr[src]}$src_pwd%f"
      ((PROMPT_SIZE = PROMPT_SIZE + $#src_pwd + 1)) # 1 for "/"
    else
      # Not in $WORKSPACE or $HOME, show absolute path up to max length.
      PROMPT+="%F{$clr[path]}%$MAX_PROMPT_LENGTH<..<%~%f"
      if [[ $#PWD -gt $MAX_PROMPT_LENGTH ]]; then
        ((PROMPT_SIZE = PROMPT_SIZE + $MAX_PROMPT_LENGTH))
      else
        ((PROMPT_SIZE = PROMPT_SIZE + $#PWD))
      fi
    fi
  fi

  ((PROMPT_SIZE = PROMPT_SIZE + $(get_length $PROMPT_SUFFIX)))
  PROMPT+="%F{$clr[div]}$PROMPT_SUFFIX%f"
}

# add-zsh-hook to hook into chpwd and precmd
autoload -Uz add-zsh-hook

# Track when PWD/WORKSPACE has changed to update prompt
function pwd_changed() {
  # Mark if workspace has changed
  unset WORKSPACE_CHANGED
  local new_workspace=$(workspace)
  if [[ $new_workspace != $WORKSPACE ]]; then
    export WORKSPACE=$new_workspace
    export WORKSPACE_CHANGED=1
  fi

  # Mark that PWD changed
  export PWD_CHANGED=1

  # Update prompt, unless it always happens inside prompt_precmd()
  if [[ -z $INDICATOR_FUNCTION ]]; then update_prompt; fi
}
add-zsh-hook chpwd pwd_changed

# Run before every command, to determine whether rprompt needs updating
function prompt_precmd() {
  export LAST_EXIT=$? # For access by INDICATOR_FUNCTION

  # Initial prompt needs to be set up
  if [[ $PROMPT_SIZE -eq 0 ]]; then
    pwd_changed
  fi

  # Always update left prompt because of INDICATOR_FUNCTION
  if [[ -n $INDICATOR_FUNCTION ]]; then
    update_prompt
  fi

  # Update if our WORKSPACE changed
  if [[ -n $WORKSPACE_CHANGED ]]; then
    if [[ -n $WORKSPACE ]]; then
      vcs_mtime=$(get_vcs_mtime)
      fetch_vcs_info
    else
      vcs_mtime=""
      unset_vcs_info
    fi
  elif [[ -n $WORKSPACE ]]; then
    # Update if .hg has been changed
    local new_mtime=$(get_vcs_mtime)
    if [[ $new_mtime != $vcs_mtime ]]; then
      vcs_mtime=$new_mtime
      fetch_vcs_info
    elif [[ -n $ALWAYS_UPDATE_ALICES ]]; then fetch_alices;
    elif [[ -n $PWD_CHANGED ]]; then update_rprompt; fi
  elif [[ -n $PWD_CHANGED ]]; then update_rprompt; fi

  # Unset this for tracking next cycle
  unset PWD_CHANGED WORKSPACE_CHANGED
}
add-zsh-hook precmd prompt_precmd

# If the terminal resizes, we need to rerun update_rprompt
function window_changed() {
  update_rprompt
  zle && zle reset-prompt
}
trap window_changed WINCH

##### END Prompt management #####
  '';
in
{
  home.file."goog_prompt.zsh".text = googPromptContent;
}
