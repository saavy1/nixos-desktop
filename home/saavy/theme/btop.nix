{ theme, ... }:
let
  inherit (theme) colors;
  customTheme = ''
    theme[main_bg]="${colors.background}"
    theme[main_fg]="${colors.foreground}"
    theme[title]="${colors.foregroundWarm}"
    theme[hi_fg]="${colors.accent}"
    theme[selected_bg]="${colors.selection}"
    theme[selected_fg]="${colors.foreground}"
    theme[inactive_fg]="${colors.muted}"
    theme[graph_text]="${colors.foregroundSoft}"
    theme[meter_bg]="${colors.selection}"
    theme[proc_misc]="${colors.foregroundSoft}"
    theme[cpu_box]="${colors.accent}"
    theme[mem_box]="${colors.success}"
    theme[net_box]="${colors.warning}"
    theme[proc_box]="${colors.foregroundWarm}"
    theme[div_line]="${colors.border}"
    theme[temp_start]="${colors.success}"
    theme[temp_mid]="${colors.warning}"
    theme[temp_end]="${colors.error}"
    theme[cpu_start]="${colors.muted}"
    theme[cpu_mid]="${colors.accent}"
    theme[cpu_end]="${colors.foreground}"
    theme[free_start]="${colors.muted}"
    theme[free_mid]="${colors.foregroundSoft}"
    theme[free_end]="${colors.foreground}"
    theme[cached_start]="${colors.muted}"
    theme[cached_mid]="${colors.accent}"
    theme[cached_end]="${colors.foregroundSoft}"
    theme[available_start]="${colors.muted}"
    theme[available_mid]="${colors.success}"
    theme[available_end]="${colors.foreground}"
    theme[used_start]="${colors.accent}"
    theme[used_mid]="${colors.warning}"
    theme[used_end]="${colors.error}"
    theme[download_start]="${colors.muted}"
    theme[download_mid]="${colors.accent}"
    theme[download_end]="${colors.success}"
    theme[upload_start]="${colors.muted}"
    theme[upload_mid]="${colors.foregroundWarm}"
    theme[upload_end]="${colors.warning}"
    theme[process_start]="${colors.success}"
    theme[process_mid]="${colors.foregroundSoft}"
    theme[process_end]="${colors.accent}"
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
