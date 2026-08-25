{
  name = "base-dark";
  polarity = "dark";

  colors = {
    background = "#111315";
    backgroundDark = "#0d0f11";
    backgroundDarker = "#090a0c";
    selection = "#303438";
    border = "#4f5559";
    muted = "#555b60";
    accent = "#7b848a";
    foreground = "#d0d2d3";
    foregroundSoft = "#a9afb3";
    foregroundWarm = "#d1c8c3";
    error = "#dc6048";
    warning = "#c8c0ac";
    success = "#9fa8a4";
  };

  typography = {
    sans = "Inter";
    mono = "JetBrains Mono";
    size = {
      caption = 11;
      body = 14;
      bar = 14;
      title = 22;
    };
  };

  geometry = {
    borderWidth = 1;
    radiusSmall = 6;
    radiusMedium = 10;
    radiusLarge = 14;
    shellGap = 10;
    outerMargin = 10;
  };

  effects = {
    panelOpacity = 0.94;
    blur = true;
    blurSize = 8;
    blurPasses = 2;
    shadow = true;
  };

  shell = {
    bar = {
      height = 46;
      titleWidth = 320;
    };
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

  wallpaper = {
    path = null;
    paths = [ ];
    fillMode = "cover";
  };

  terminal = [
    "#111315"
    "#555b60"
    "#9fa8a4"
    "#d0d2d3"
    "#7b848a"
    "#aeaeae"
    "#707070"
    "#d0d2d3"
    "#555b60"
    "#dc6048"
    "#303438"
    "#c8c0ac"
    "#62686c"
    "#9a9a9a"
    "#808080"
    "#d1c8c3"
  ];
}
