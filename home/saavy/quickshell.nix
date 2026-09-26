{ config, lib, pkgs, ... }:
let
  clipboardSelect = pkgs.writeShellApplication {
    name = "clipboard-select";
    runtimeInputs = [
      pkgs.cliphist
      pkgs.wl-clipboard
    ];
    text = ''
      printf '%s' "$1" | cliphist decode | wl-copy
    '';
  };
  clipboardDelete = pkgs.writeShellApplication {
    name = "clipboard-delete";
    runtimeInputs = [ pkgs.cliphist ];
    text = ''
      printf '%s' "$1" | cliphist delete
    '';
  };

  clipboardPreview = pkgs.writeShellApplication {
    name = "clipboard-preview";
    runtimeInputs = [
      pkgs.cliphist
      pkgs.coreutils
    ];
    text = ''
      printf '%s' "$1" | cliphist decode > "$2"
    '';
  };

  # Today's token totals from local agent session logs (Claude Code, omp, Codex).
  agentUsageToday = pkgs.writers.writePython3Bin "agent-usage-today" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./scripts/agent-usage-today.py);

  # Launcher categories, in display order. The model picks one per app from
  # the descriptions; the icons are Lucide names.
  appCategories = [
    {
      name = "Development";
      icon = "code";
      description = "code editors, IDEs, terminals, git clients and developer tools";
    }
    {
      name = "AI & agents";
      icon = "bot";
      description = "AI assistants, chatbots, coding agents and agent orchestration tools";
    }
    {
      name = "Internet & chat";
      icon = "globe";
      description = "web browsers, email, messaging, chat, voice and video calls";
    }
    {
      name = "Media";
      icon = "music";
      description = "music and video players, streaming, podcasts, photo viewers";
    }
    {
      name = "Creative";
      icon = "palette";
      description = "drawing, image editing, 3D modelling, audio production, video editing";
    }
    {
      name = "Hardware";
      icon = "cpu";
      description = "electronics, PCB and schematic design, CAD, microcontrollers, 3D printing";
    }
    {
      name = "Games";
      icon = "gamepad-2";
      description = "games, game launchers and stores, emulators";
    }
    {
      name = "Office";
      icon = "file-text";
      description = "documents, notes, spreadsheets, PDFs, calendars";
    }
    {
      name = "System";
      icon = "settings";
      description = "settings, file managers, system monitors, utilities and drivers";
    }
  ];

  # Sorts installed apps into appCategories with the model on the Spark and
  # writes $XDG_STATE_HOME/app-categories.json, which the launcher reads.
  # Only new or changed apps are asked, so reruns are cheap.
  appCategorize = pkgs.writers.writePython3Bin "app-categorize" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./scripts/app-categorize.py);
  # Flags clipboard entries that look like secrets (Laya on the Spark) so the
  # clipboard panel masks them. Once the flagged set looks right, set
  # autoExpire to delete them from history after expireAfter seconds.
  clipGuardSettings = {
    threshold = 0.9;
    autoExpire = true;
    expireAfter = 3600;
  };
  clipGuard = pkgs.writers.writePython3Bin "clip-guard" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./scripts/clip-guard.py);

  # Names each Hyprland workspace after what's on it (Qwen on the Spark),
  # reacting to window events; the bar reads $XDG_STATE_HOME/workspace-names.json.
  workspaceNamer = pkgs.writers.writePython3Bin "workspace-namer" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./scripts/workspace-namer.py);

  appCategoriesJson = pkgs.writeText "app-categories.json" (
    builtins.toJSON { categories = appCategories; }
  );
in
{
  home.packages = [
    agentUsageToday
    appCategorize
    clipGuard
    workspaceNamer
    clipboardSelect
    clipboardDelete
    clipboardPreview
  ];

  programs.quickshell = {
    enable = true;
    activeConfig = "desktop";
    systemd.enable = true;
  };

  services.cliphist = {
    enable = true;
    systemdTargets = [ "graphical-session.target" ];
  };

  # Every QML file in ./quickshell (including ui/) is linked individually so
  # the generated Theme.qml and Icons.qml can sit alongside them.
  xdg.configFile."quickshell/desktop" = {
    source = ./quickshell;
    recursive = true;
  };

  xdg.configFile."quickshell/desktop/AppCategories.qml".text = ''
    pragma Singleton

    import QtQuick

    // Generated from appCategories in home/saavy/quickshell.nix.
    QtObject {
      readonly property var list: ${builtins.toJSON appCategories}
    }
  '';

  systemd.user.services.app-categorize = {
    Unit.Description = "Sort launcher apps into categories";
    Service = {
      Type = "oneshot";
      ExecStart = "${appCategorize}/bin/app-categorize ${appCategoriesJson}";
    };
  };

  systemd.user.timers.app-categorize = {
    Unit.Description = "Sort launcher apps into categories";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "6h";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.clip-guard = {
    Unit.Description = "Mask secrets in clipboard history";
    Service = {
      Type = "oneshot";
      Environment = "PATH=${lib.makeBinPath [ pkgs.cliphist ]}";
      ExecStart = lib.escapeShellArgs [
        "${clipGuard}/bin/clip-guard"
        "sweep"
        "--threshold"
        (toString clipGuardSettings.threshold)
        "--expire-after"
        (toString (if clipGuardSettings.autoExpire then clipGuardSettings.expireAfter else 0))
      ];
    };
  };

  systemd.user.timers.clip-guard = {
    Unit.Description = "Mask secrets in clipboard history";
    Timer = {
      OnStartupSec = "1min";
      OnUnitActiveSec = "1min";
      AccuracySec = "10s";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.workspace-namer = {
    Unit = {
      Description = "Name Hyprland workspaces after their windows";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${workspaceNamer}/bin/workspace-namer";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.quickshell = {
    Unit = {
      X-Restart-Triggers = [
        "${./quickshell}"
        "${config.xdg.configFile."quickshell/desktop/Theme.qml".source}"
        "${config.xdg.configFile."quickshell/desktop/Icons.qml".source}"
        "${config.xdg.configFile."quickshell/desktop/AppCategories.qml".source}"
      ];
      # At login the service can start before the session has imported
      # WAYLAND_DISPLAY; Qt then falls back to xcb and exits. Retry slowly
      # enough that the session catches up instead of tripping the limit.
      StartLimitIntervalSec = 60;
      StartLimitBurst = 10;
    };
    Service.RestartSec = 2;
  };
}
