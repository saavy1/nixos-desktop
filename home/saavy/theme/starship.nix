{ theme, ... }:
let
  inherit (theme) color;
in
{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = true;
      command_timeout = 1000;
      palette = theme.name;
      format = "$directory$git_branch$git_status$nix_shell$cmd_duration$status$line_break$character";
      right_format = "$time";

      palettes.${theme.name} = {
        background = color.surface.base;
        selection = color.surface.hover;
        border = color.lineSolid;
        muted = color.text.faint;
        accent = color.accent;
        foreground = color.text.base;
        soft = color.text.soft;
        warm = color.accent;
        error = color.danger;
        warning = color.warning;
        success = color.success;
      };

      character = {
        success_symbol = "[❯](bold success)";
        error_symbol = "[❯](bold error)";
      };
      cmd_duration = {
        min_time = 2000;
        format = " [took $duration](muted)";
      };
      directory = {
        format = "[$path](bold foreground) ";
        read_only = " 󰌾";
        read_only_style = "warning";
        truncation_length = 4;
        truncate_to_repo = true;
      };
      git_branch = {
        symbol = " ";
        format = "[$symbol$branch](accent)";
      };
      git_status = {
        format = "([$all_status$ahead_behind](warning)) ";
        conflicted = "~";
        ahead = "⇡$count";
        behind = "⇣$count";
        diverged = "⇕⇡$ahead_count⇣$behind_count";
        untracked = "?$count";
        stashed = "*$count";
        modified = "!$count";
        staged = "+$count";
        renamed = "»$count";
        deleted = "✘$count";
      };
      nix_shell = {
        symbol = " ";
        format = "[$symbol$state( ($name))](soft) ";
      };
      status = {
        disabled = false;
        format = "[$status](error) ";
      };
      time = {
        disabled = false;
        format = "[$time](muted)";
        time_format = "%H:%M";
      };
    };
  };
}