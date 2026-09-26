{ theme, ... }:
let
  inherit (theme) color;
in
{
  programs.yazi.theme = {
    app.overall.bg = color.surface.base;
    mgr = {
      cwd = { fg = color.accent; bold = true; };
      find_keyword = { fg = color.warning; bold = true; };
      find_position = { fg = color.text.soft; };
      symlink_target = { fg = color.accent; italic = true; };
      marker_copied = { fg = color.success; bg = color.success; };
      marker_cut = { fg = color.danger; bg = color.danger; };
      marker_marked = { fg = color.warning; bg = color.warning; };
      marker_selected = { fg = color.accent; bg = color.accent; };
      border_symbol = "│";
      border_style = { fg = color.lineSolid; };
    };
    indicator = {
      parent = { fg = color.text.faint; bg = color.text.faint; };
      current = { fg = color.accent; bg = color.accent; };
      preview = { fg = color.lineSolid; bg = color.lineSolid; };
    };
    tabs = {
      active = { fg = color.surface.base; bg = color.accent; bold = true; };
      inactive = { fg = color.text.soft; bg = color.surface.sunk; };
    };
    mode = {
      normal_main = { fg = color.surface.base; bg = color.accent; bold = true; };
      normal_alt = { fg = color.accent; bg = color.surface.hover; };
      select_main = { fg = color.surface.base; bg = color.warning; bold = true; };
      select_alt = { fg = color.warning; bg = color.surface.hover; };
      unset_main = { fg = color.surface.base; bg = color.danger; bold = true; };
      unset_alt = { fg = color.danger; bg = color.surface.hover; };
    };
  };
}
