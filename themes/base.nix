# Palette-independent design tokens shared by every theme. A palette in
# ./palettes can override any of these; see ./mk-theme.nix for how they merge.
{
  polarity = "dark";

  typography = {
    # UI faces for the shell and GTK. `code` is the terminal/editor face and
    # needs Nerd Font glyphs for starship, yazi and friends.
    sans = "IBM Plex Sans";
    display = "Fraunces";
    mono = "IBM Plex Mono";
    code = "JetBrainsMono Nerd Font";
    icons = "lucide";
    # Attribute paths under pkgs, installed system-wide via fonts.packages.
    packages = [
      "ibm-plex"
      "fraunces"
      "nerd-fonts.jetbrains-mono"
      "lucide"
    ];

    # Pixel sizes for the shell, except `gtk` (points) and `code` (terminal pt).
    size = {
      label = 10;
      caption = 11;
      small = 12;
      body = 14;
      bar = 13;
      heading = 16;
      title = 22;
      display = 28;
      gtk = 11;
      code = 14;
    };
  };

  geometry = {
    borderWidth = 1;
    radius = {
      small = 5;
      medium = 8;
      large = 11;
      pill = 999;
    };
    shellGap = 10;
    outerMargin = 10;
  };

  spacing = {
    xs = 4;
    sm = 8;
    md = 12;
    lg = 16;
    xl = 22;
    xxl = 32;
  };

  # Durations in ms.
  motion = {
    fast = 120;
    base = 180;
    slow = 260;
  };

  # Opacities applied to the palette's `line`, text and status colors to build
  # hairlines, hover washes and tints without extra palette entries.
  alpha = {
    line = 0.14;
    lineStrong = 0.22;
    hover = 0.08;
    selected = 0.1;
    tint = 0.14;
    scrim = 0.45;
    # Whole-control opacity when disabled.
    disabled = 0.55;
  };

  effects = {
    barOpacity = 0.88;
    panelOpacity = 0.96;
    blur = true;
    blurSize = 8;
    blurPasses = 2;
    # "soft" (blurred drop shadow), "offset" (hard print-style shadow) or "none".
    shadow = "soft";
    grain = true;
    grainOpacity = 0.07;
  };

  shell = {
    bar.height = 44;
    launcher = {
      width = 960;
      height = 680;
      maxResults = 9;
    };
    keybinds = {
      width = 1480;
      height = 900;
    };
  };

  icons.name = "Yaru-sage-dark";

  # Package attribute paths under pkgs, like typography.packages.
  cursor = {
    name = "Bibata-Modern-Classic";
    package = "bibata-cursors";
    size = 24;
  };

  gtk = {
    name = "adw-gtk3-dark";
    package = "adw-gtk3";
  };

  wallpaper = {
    path = null;
    paths = [ ];
    fillMode = "cover";
  };
}
