import re

with open("default.nix", "r") as f:
    content = f.read()

content = re.sub(
    r'  monitorEnvVars = {.*?PATH =',
    '  monitorEnvVars = {\n    # systemd user services and launchd agents both start with a minimal PATH.\n    # agent-tracker intentionally invokes `tmux` and `sleep` by name from\n    # Python, so provide an explicit cross-platform tool PATH instead of\n    # relying on the interactive shell environment.\n    PATH =',
    content,
    flags=re.DOTALL
)

content = re.sub(
    r'  } // lib.optionalAttrs \(cfg.registries != \[\]\) \{\n    AGENT_REGISTRIES_JSON = builtins.toJSON cfg.registries;\n  \};',
    '  };',
    content
)

with open("default.nix", "w") as f:
    f.write(content)
