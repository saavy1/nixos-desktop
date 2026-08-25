{ pkgs, ... }:
let
  brightnessStep = pkgs.writeShellApplication {
    name = "brightness-step";
    runtimeInputs = [
      pkgs.brightnessctl
      pkgs.gawk
      pkgs.quickshell
    ];
    text = ''
      output="$(brightnessctl -m set "$1")"
      if [[ "$output" =~ ,([0-9]+)% ]]; then
        level="$(awk -v percent="''${BASH_REMATCH[1]}" 'BEGIN { print percent / 100 }')"
        qs -c desktop ipc call osd brightness "$level" >/dev/null 2>&1 || true
      fi
    '';
  };
in
{
  home.packages = [
    brightnessStep
    pkgs.brightnessctl
    pkgs.ddcutil
  ];

  services.hyprsunset.enable = true;
}
