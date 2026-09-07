{ pkgs, ... }:
{
  home.packages = [
    pkgs.git-open
    pkgs.kubectl
  ];

  programs.fish = {
    enable = true;
    preferAbbrs = true;

    plugins = [
      {
        name = "bass";
        src = pkgs.fishPlugins.bass.src;
      }
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
    ];

    shellAbbrs = {
      # Git: keep the vocabulary small enough to learn rather than importing
      # a plugin's entire alias catalog.
      g = "git";
      ga = "git add";
      gaa = "git add --all";
      gc = "git commit";
      gd = "git diff";
      gl = "git pull";
      glo = "git log --oneline --decorate --graph";
      gp = "git push";
      gst = "git status --short --branch";
      gsw = "git switch";
      gswc = "git switch --create";
      gwt = "git worktree";

      # Kubernetes.
      k = "kubectl";
      ka = "kubectl apply -f";
      kd = "kubectl describe";
      kdel = "kubectl delete";
      kg = "kubectl get";
      kl = "kubectl logs";

      # NixOS and flakes.
      nb = "nix build";
      nfc = "nix flake check";
      nfu = "nix flake update";
      ns = "nix shell";
      nrs = "sudo nixos-rebuild switch --flake ~/nixos-desktop#desktop";
    };

    interactiveShellInit = ''
      set --global fish_greeting

      # Fish already implements history substring search; bind it explicitly
      # rather than carrying a redundant third-party plugin.
      bind up up-or-search
      bind down down-or-search
    '';
  };

  # fzf-fish owns Fish's key bindings; this module supplies the executable.
  programs.fzf = {
    enable = true;
    enableFishIntegration = false;
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  # Home Manager owns the generated file even on the first switch, replacing
  # Fish's stock unmanaged stub if it is still present.
  xdg.configFile."fish/config.fish".force = true;
}