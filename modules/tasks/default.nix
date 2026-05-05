{ config, pkgs, inputs, ... }:

{
  home.packages = [
    inputs.tasks-nvim.packages.${pkgs.system}.default
  ];

  xdg.configFile."task-manager-tui/config.json".text = ''
    {
      "db_path": "~/.local/share/nvim/task_manager.db",
      "inbox_file": "~/pkm/tasks.md",
      "directories": ["~/pkm"],
      "auto_tags": {
        "/daily/": ["daily"]
      }
    }
  '';
}
