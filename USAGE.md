# Usage Guide

## Table of Contents

- [Tmux](#tmux)
  - [Core Concepts](#core-concepts)
  - [Sessions](#sessions)
  - [Windows](#windows)
  - [Panes](#panes)
  - [Copy Mode](#copy-mode)
  - [Custom Bindings](#custom-bindings)
  - [Best Practices](#best-practices)
- [Neovim](#neovim)
  - [Navigation](#navigation)
  - [Buffers](#buffers)
  - [Tasks](#tasks)
  - [Notes (zk)](#notes-zk)
  - [AI Review Comments](#ai-review-comments)
  - [Spreadsheets (sc-im)](#spreadsheets-sc-im)
  - [Agent Observer](#agent-observer)
- [Shell (Zsh)](#shell-zsh)

---

## Tmux

**Prefix key: `Ctrl+B`**  
All tmux bindings below are pressed _after_ the prefix unless marked with `-n` (no prefix).

### Core Concepts

| Concept | What it is | Analogy |
|---------|-----------|---------|
| **Session** | A named workspace that persists even when detached | A project or context |
| **Window** | A full-screen tab inside a session | A browser tab |
| **Pane** | A split view inside a window | A terminal split |

The hierarchy is: **Session → Windows → Panes**

### Sessions

| Key / Command | Action |
|---------------|--------|
| `tmux new -s <name>` | Create a named session |
| `tmux attach -t <name>` | Attach to an existing session |
| `tmux ls` | List all sessions |
| `Prefix + d` | Detach from current session (session keeps running) |
| `Prefix + $` | Rename current session |
| `Prefix + s` | Show session list (interactive) |
| `Prefix + (` / `)` | Switch to previous / next session |
| `Prefix + Ctrl+T` | Open sessionizer (fuzzy session switcher) |
| Right-click status bar | Session context menu (new, kill, rename, switch) |

### Windows

| Key | Action |
|-----|--------|
| `Prefix + c` | Create new window |
| `Prefix + ,` | Rename current window |
| `Prefix + &` | Kill current window |
| `Prefix + n` / `p` | Next / previous window |
| `Prefix + <number>` | Jump to window by number (1-indexed) |
| `Prefix + l` | Last (previously active) window |
| `Prefix + w` | Interactive window list |

### Panes

| Key | Action |
|-----|--------|
| `Prefix + %` | Split pane vertically (left/right) |
| `Prefix + "` | Split pane horizontally (top/bottom) |
| `Prefix + x` | Kill current pane |
| `Prefix + z` | Toggle pane zoom (fullscreen) |
| `Prefix + {` / `}` | Swap pane with previous / next |
| `Prefix + q` | Show pane numbers |
| `Prefix + Space` | Cycle through pane layouts |

**Seamless vim-tmux navigation (no prefix needed):**

| Key | Action |
|-----|--------|
| `Ctrl+H` | Move to pane on the left |
| `Ctrl+J` | Move to pane below |
| `Ctrl+K` | Move to pane above |
| `Ctrl+L` | Move to pane on the right |

These work from both tmux panes and neovim splits — no context switching needed.

### Copy Mode

Copy mode uses vi bindings (`keyMode = "vi"`).

| Key | Action |
|-----|--------|
| `Prefix + [` | Enter copy mode |
| `q` | Exit copy mode |
| `v` | Begin selection |
| `y` | Yank (copy) selection |
| `/` | Search forward |
| `?` | Search backward |
| `n` / `N` | Next / previous search match |
| `g` / `G` | Jump to top / bottom |
| `WheelUp` / `WheelDown` | Scroll (works in TUI apps too) |

### Custom Bindings

| Key | Action |
|-----|--------|
| `Prefix + r` | Reload tmux config |
| `Prefix + Ctrl+T` | Open sessionizer |
| `Prefix + Ctrl+P` | Open command palette |
| `Prefix + N` | Focus next agent (agent-tracker) |
| `Prefix + P` | Focus previous agent (agent-tracker) |
| `Prefix + Ctrl+C` | Create note popup |
| `Prefix + T` | Create task popup |
| `Prefix + t` | List tasks for current workspace |
| `Prefix + Ctrl+N` | List all tasks popup |

### Best Practices

**Sessions — one per project/context**  
Create a session per project (`tmux new -s myapp`) and leave it running. Detach with `Prefix + d` and reattach later. Never close terminal tabs just to "end" a session — detach instead so state is preserved.

**Windows — one per concern within a project**  
Inside a session, use windows for logical roles: `editor`, `server`, `logs`, `git`. Name them with `Prefix + ,` so the status bar is readable at a glance.

**Panes — for things you need to see at the same time**  
Split panes only when you need simultaneous visibility (e.g., editor + running tests). Zoom a pane (`Prefix + z`) when you need to focus, then unzoom to restore the split.

**Sessionizer over manual switching**  
Use `Prefix + Ctrl+T` to fuzzy-find and jump between sessions rather than cycling with `(` `)`.

**Keep windows flat**  
Avoid deeply nested pane layouts. If you need more than 3 panes, consider a new window instead.

---

## Neovim

**Leader key: `<Space>`** (AstroNvim default)

### Navigation

| Key | Action |
|-----|--------|
| `Ctrl+H` | Move to left split / tmux pane |
| `Ctrl+J` | Move to split below / tmux pane |
| `Ctrl+K` | Move to split above / tmux pane |
| `Ctrl+L` | Move to right split / tmux pane |
| `Ctrl+\` | Move to previous split / tmux pane |

### Buffers

| Key | Action |
|-----|--------|
| `]b` | Next buffer |
| `[b` | Previous buffer |
| `<Leader>bd` | Close buffer from tabline |

### Visual Mode

| Key | Action |
|-----|--------|
| `p` | Paste without overwriting clipboard register |
| `ic` | Select inside markdown code block |
| `ac` | Select around markdown code block (includes backticks) |

### Misc

| Key | Action |
|-----|--------|
| `<Leader>tf` | Toggle transparency / focus mode |

### Tasks

| Key | Action |
|-----|--------|
| `<Leader>tt` | View tasks |
| `<Leader>tA` | View all tasks |
| `<Leader>tw` | View tasks tagged `@work` |
| `<Leader>tu` | View tasks tagged `#urgent` |
| `<Leader>td` | View daily tasks |
| `<Leader>ta` | Add task |
| `<Leader>tx` | Toggle task done |

### Notes (zk)

| Key | Action |
|-----|--------|
| `<Leader>zn` | New note |
| `<Leader>zo` | Open notes |
| `<Leader>zwo` | Open workspace notes |
| `<Leader>zt` | Browse tags |
| `<Leader>zf` | Search notes |
| `<Leader>zb` | Backlinks for current note |
| `<Leader>zl` | Links in current note |
| `<Leader>zf` (visual) | Search notes matching selection |
| `gd` | Go to linked note (definition) |

### AI Review Comments

| Key | Action |
|-----|--------|
| `<Leader>ra` | Add review comment (normal & visual) |
| `<Leader>rd` | Delete review comment |
| `<Leader>re` | Edit review comment |
| `<Leader>rv` | View review comment |
| `<Leader>rr` | Go to review comments list |
| `<Leader>rg` | Go to review comment |
| `<Leader>rG` | Go to comment in file |
| `<Leader>rt` | Go to comment by type |
| `<Leader>rR` | Resolve comment |
| `<Leader>rA` | Resolve all comments |
| `<Leader>rE` | Export review |
| `<Leader>rX` | Export and clear |
| `<Leader>rf` | Export review to file |
| `<Leader>rc` | Clear all comments |
| `]r` | Next review comment |
| `[r` | Previous review comment |

### Spreadsheets (sc-im)

| Key | Action |
|-----|--------|
| `<Leader>sc` | Open table under cursor in sc-im |
| `<Leader>sl` | Open table (linked) in sc-im |
| `<Leader>sp` | Open plain table in sc-im |
| `<Leader>st` | Toggle sc-im link format |
| `<Leader>sr` | Rename linked sc-im file |
| `<Leader>su` | Recalculate markdown table |
| `<Leader>sU` | Update sc file and markdown table |

### Agent Observer

| Key | Action |
|-----|--------|
| `<Leader>ao` | Toggle agent observer panel |

---

## Agent Communicator

Prompt templates live in `~/.config/agent-communicator/prompts/<prompt-name>.md`.

| Key | Action |
|-----|--------|
| `P` | Open prompt selector, edit selected prompt in Neovim/temp file, send only if saved |
| `Ctrl+N` / `Ctrl+P` | Select next/previous agent |
| `Enter` | Send composer text |

---

## Shell (Zsh)

### Keybindings

| Key | Action |
|-----|--------|
| `Ctrl+E` | Accept autosuggestion |
| `Ctrl+P` | Previous command in history |
| `Ctrl+N` | Next command in history |

### Aliases

| Alias | Action |
|-------|--------|
| `wn` | Notes workflow |
| `nf` | Create new file |
| `nd` | Create new directory |
| `nn` | Create new note |
| `nmn` | Note manager |
