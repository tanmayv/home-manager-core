# Minimal Cloudtop: 20% Project Ideation & Design

## 1. Project Overview

**Project Name:** Minimal Cloudtop
**Goal:** Develop and refine a modern, AI-focused Home Manager configuration that optimizes the terminal experience for Googlers using Cloudtop, specifically tailoring it for CitC workflows, Tmux status bar metadata (like hg/cl info), and robust inter-agent communication.
**Technology Stack:** Nix, Home Manager, Zsh, Tmux, Git, Mercurial (hg), Python, Bash.
**Team:** [Your Name / Team]

## 2. Goals and Exit Criteria

### Immediate Milestones (Roofshots)
*   [x] Establish a modular Nix-based configuration structure.
*   [x] Implement seamless integration between Zsh, Zoxide, and CitC workspace boundaries (`hgd` and `cd` wrappers).
*   [x] Build a dynamic, multi-line Tmux status bar with mouse-clickable regions for session and agent management.
*   [x] Create reliable, lock-protected inter-agent communication scripts (`send-message-to-agent`, `waiting`, `iamdone`).
*   [x] Implement an automatic daily update checker for the `stable` release branch that gracefully handles rebasing user customizations.

### Long-Term Vision (Moonshots)
*   Become a recommended, standardized terminal setup for AI researchers and engineers across Google who prefer a fast, minimal, and keyboard-centric (yet mouse-friendly) environment.
*   Seamlessly integrate internal tools (Buganizer, Critique, F1, Monarch) directly into the terminal UI or command palette.

## 3. Review Questions & Assessment

*   **Is it unique?** While other dotfile managers exist, this project specifically bridges the gap between pure Nix/Home Manager paradigms and Google's internal infrastructure (CitC, hg wrappers), while treating AI CLI agents as first-class citizens (UI metadata and IPC).
*   **Would it be useful?** Yes, it drastically reduces onboarding time for new Cloudtop users who want a modern terminal (Atuin, Zoxide, Fzf) pre-configured with Google-specific workflows and a Tokyo Night aesthetic.
*   **How does it fit into Google's goals?** It enhances developer velocity and satisfaction by providing a high-performance, distraction-free environment tailored for AI integration.
*   **Are there related projects at Google?** There are various internal dotfile sharing communities. This project should aim to be modular enough to share components with them.
*   **What does this project need to advance?**
    *   Broader dogfooding among engineers outside the immediate team.
    *   Integration with internal metrics to track stability and usage (if applicable).
    *   Formal review from security/privacy regarding the update mechanism and shell wrappers.

## 4. Next Steps

1.  Share this design document with `20percent-feedback@google.com` for early review.
2.  Continue dogfooding the `stable` branch release mechanism.
3.  Gather feedback on the command palette discoverability.
