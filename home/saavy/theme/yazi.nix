{ theme, ... }:
let
  inherit (theme) colors;
in
{
  programs.yazi.theme = {
    app.overall.bg = colors.background;
    mgr = {
      cwd = { fg = colors.accent; bold = true; };
      find_keyword = { fg = colors.warning; bold = true; };
      find_position = { fg = colors.foregroundSoft; };
      symlink_target = { fg = colors.accent; italic = true; };
      marker_copied = { fg = colors.success; bg = colors.success; };
      marker_cut = { fg = colors.error; bg = colors.error; };
      marker_marked = { fg = colors.warning; bg = colors.warning; };
      marker_selected = { fg = colors.accent; bg = colors.accent; };
      border_symbol = "│";
      border_style = { fg = colors.border; };
    };
    indicator = {
      parent = { fg = colors.muted; bg = colors.muted; };
      current = { fg = colors.accent; bg = colors.accent; };
      preview = { fg = colors.border; bg = colors.border; };
    };
    tabs = {
      active = { fg = colors.background; bg = colors.accent; bold = true; };
      inactive = { fg = colors.foregroundSoft; bg = colors.backgroundDark; };
    };
    mode = {
      normal_main = { fg = colors.background; bg = colors.accent; bold = true; };
      normal_alt = { fg = colors.accent; bg = colors.selection; };
      select_main = { fg = colors.background; bg = colors.warning; bold = true; };
      select_alt = { fg = colors.warning; bg = colors.selection; };
      unset_main = { fg = colors.background; bg = colors.error; bold = true; };
      unset_alt = { fg = colors.error; bg = colors.selection; };
    };
  };
}
