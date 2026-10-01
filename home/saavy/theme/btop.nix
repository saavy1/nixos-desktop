{ theme, ... }:
let
  inherit (theme) color;
  customTheme = ''
    theme[main_bg]="${color.surface.base}"
    theme[main_fg]="${color.text.base}"
    theme[title]="${color.accent}"
    theme[hi_fg]="${color.accent}"
    theme[selected_bg]="${color.surface.hover}"
    theme[selected_fg]="${color.text.base}"
    theme[inactive_fg]="${color.text.faint}"
    theme[graph_text]="${color.text.soft}"
    theme[meter_bg]="${color.surface.hover}"
    theme[proc_misc]="${color.text.soft}"
    theme[cpu_box]="${color.accent}"
    theme[mem_box]="${color.success}"
    theme[net_box]="${color.warning}"
    theme[proc_box]="${color.accent}"
    theme[div_line]="${color.lineSolid}"
    theme[temp_start]="${color.success}"
    theme[temp_mid]="${color.warning}"
    theme[temp_end]="${color.danger}"
    theme[cpu_start]="${color.text.faint}"
    theme[cpu_mid]="${color.accent}"
    theme[cpu_end]="${color.text.base}"
    theme[free_start]="${color.text.faint}"
    theme[free_mid]="${color.text.soft}"
    theme[free_end]="${color.text.base}"
    theme[cached_start]="${color.text.faint}"
    theme[cached_mid]="${color.accent}"
    theme[cached_end]="${color.text.soft}"
    theme[available_start]="${color.text.faint}"
    theme[available_mid]="${color.success}"
    theme[available_end]="${color.text.base}"
    theme[used_start]="${color.accent}"
    theme[used_mid]="${color.warning}"
    theme[used_end]="${color.danger}"
    theme[download_start]="${color.text.faint}"
    theme[download_mid]="${color.accent}"
    theme[download_end]="${color.success}"
    theme[upload_start]="${color.text.faint}"
    theme[upload_mid]="${color.accent}"
    theme[upload_end]="${color.warning}"
    theme[process_start]="${color.success}"
    theme[process_mid]="${color.text.soft}"
    theme[process_end]="${color.accent}"
  '';
in
{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = theme.name;
      theme_background = true;
      truecolor = true;
      rounded_corners = true;
      graph_symbol = "braille";
      shown_boxes = "cpu mem net proc";
      update_ms = 1000;
    };
    themes.${theme.name} = customTheme;
  };
}
