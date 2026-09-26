{ theme, ... }:
let
  inherit (theme) color typography;
  ansi = builtins.elemAt theme.terminal;
  withAlpha = color: alpha: "${color}${alpha}";
  transparent = withAlpha color.surface.base "00";
  subtleSelection = withAlpha color.surface.hover "80";
  themeDocument = {
    name = theme.name;
    author = "Solitude NixOS";
    themes = [
      {
        name = theme.name;
        appearance = theme.polarity;
        style = {
          accents = [
            color.accent
            color.success
            color.warning
            color.accent
            color.text.soft
          ];

          background = color.surface.base;
          "background.appearance" = "opaque";
          border = color.lineSolid;
          "border.disabled" = color.text.faint;
          "border.focused" = color.accent;
          "border.selected" = color.text.soft;
          "border.transparent" = transparent;
          "border.variant" = color.surface.hover;

          conflict = color.warning;
          "conflict.background" = withAlpha color.warning "20";
          "conflict.border" = withAlpha color.warning "80";
          created = color.success;
          "created.background" = withAlpha color.success "20";
          "created.border" = withAlpha color.success "80";
          deleted = color.danger;
          "deleted.background" = withAlpha color.danger "20";
          "deleted.border" = withAlpha color.danger "80";
          modified = color.warning;
          "modified.background" = withAlpha color.warning "20";
          "modified.border" = withAlpha color.warning "80";
          renamed = color.accent;
          "renamed.background" = withAlpha color.accent "20";
          "renamed.border" = withAlpha color.accent "80";
          ignored = color.text.faint;
          "ignored.background" = withAlpha color.text.faint "20";
          "ignored.border" = withAlpha color.text.faint "80";
          hidden = color.text.faint;
          "hidden.background" = withAlpha color.text.faint "20";
          "hidden.border" = withAlpha color.text.faint "80";
          unreachable = color.text.faint;
          "unreachable.background" = withAlpha color.text.faint "20";
          "unreachable.border" = withAlpha color.text.faint "80";

          error = color.danger;
          "error.background" = withAlpha color.danger "20";
          "error.border" = withAlpha color.danger "80";
          warning = color.warning;
          "warning.background" = withAlpha color.warning "20";
          "warning.border" = withAlpha color.warning "80";
          success = color.success;
          "success.background" = withAlpha color.success "20";
          "success.border" = withAlpha color.success "80";
          info = color.accent;
          "info.background" = withAlpha color.accent "20";
          "info.border" = withAlpha color.accent "80";
          hint = color.text.soft;
          "hint.background" = withAlpha color.text.soft "18";
          "hint.border" = withAlpha color.text.soft "70";
          predictive = color.text.faint;
          "predictive.background" = withAlpha color.text.faint "18";
          "predictive.border" = withAlpha color.text.faint "70";

          "surface.background" = color.surface.sunk;
          "elevated_surface.background" = color.surface.deep;
          "drop_target.background" = withAlpha color.accent "30";
          "panel.background" = color.surface.sunk;
          "panel.focused_border" = color.accent;
          "panel.indent_guide" = color.surface.hover;
          "panel.indent_guide_active" = color.lineSolid;
          "panel.indent_guide_hover" = color.text.soft;
          "pane.focused_border" = color.accent;
          "pane_group.border" = color.lineSolid;
          "status_bar.background" = color.surface.deep;
          "title_bar.background" = color.surface.sunk;
          "title_bar.inactive_background" = color.surface.deep;
          "toolbar.background" = color.surface.sunk;
          "tab_bar.background" = color.surface.deep;
          "tab.active_background" = color.surface.base;
          "tab.inactive_background" = color.surface.sunk;

          "element.background" = transparent;
          "element.hover" = withAlpha color.surface.hover "70";
          "element.active" = color.surface.hover;
          "element.selected" = subtleSelection;
          "element.disabled" = withAlpha color.text.faint "18";
          "ghost_element.background" = transparent;
          "ghost_element.hover" = withAlpha color.surface.hover "70";
          "ghost_element.active" = color.surface.hover;
          "ghost_element.selected" = subtleSelection;
          "ghost_element.disabled" = withAlpha color.text.faint "18";

          text = color.text.base;
          "text.muted" = color.text.soft;
          "text.placeholder" = color.text.faint;
          "text.disabled" = color.text.faint;
          "text.accent" = color.accent;
          icon = color.text.base;
          "icon.muted" = color.text.soft;
          "icon.placeholder" = color.text.faint;
          "icon.disabled" = color.text.faint;
          "icon.accent" = color.accent;
          "link_text.hover" = color.accent;

          "scrollbar.track.background" = transparent;
          "scrollbar.track.border" = transparent;
          "scrollbar.thumb.background" = withAlpha color.lineSolid "80";
          "scrollbar.thumb.hover_background" = color.lineSolid;
          "scrollbar.thumb.border" = transparent;
          "search.match_background" = withAlpha color.warning "35";

          "editor.background" = color.surface.base;
          "editor.foreground" = color.text.base;
          "editor.gutter.background" = color.surface.base;
          "editor.subheader.background" = color.surface.sunk;
          "editor.active_line.background" = withAlpha color.surface.hover "45";
          "editor.highlighted_line.background" = withAlpha color.surface.hover "70";
          "editor.line_number" = color.text.faint;
          "editor.active_line_number" = color.text.soft;
          "editor.invisible" = color.text.faint;
          "editor.indent_guide" = color.surface.hover;
          "editor.indent_guide_active" = color.lineSolid;
          "editor.wrap_guide" = color.surface.hover;
          "editor.active_wrap_guide" = color.lineSolid;
          "editor.document_highlight.bracket_background" = withAlpha color.accent "35";
          "editor.document_highlight.read_background" = withAlpha color.surface.hover "70";
          "editor.document_highlight.write_background" = withAlpha color.accent "30";

          players = [
            {
              cursor = color.accent;
              background = withAlpha color.accent "20";
              selection = withAlpha color.accent "50";
            }
            {
              cursor = color.success;
              background = withAlpha color.success "20";
              selection = withAlpha color.success "50";
            }
            {
              cursor = color.warning;
              background = withAlpha color.warning "20";
              selection = withAlpha color.warning "50";
            }
            {
              cursor = color.accent;
              background = withAlpha color.accent "20";
              selection = withAlpha color.accent "50";
            }
          ];

          "terminal.background" = color.surface.base;
          "terminal.foreground" = color.text.base;
          "terminal.bright_foreground" = color.accent;
          "terminal.dim_foreground" = color.text.soft;
          "terminal.ansi.background" = color.surface.base;
          "terminal.ansi.black" = ansi 0;
          "terminal.ansi.red" = ansi 1;
          "terminal.ansi.green" = ansi 2;
          "terminal.ansi.yellow" = ansi 3;
          "terminal.ansi.blue" = ansi 4;
          "terminal.ansi.magenta" = ansi 5;
          "terminal.ansi.cyan" = ansi 6;
          "terminal.ansi.white" = ansi 7;
          "terminal.ansi.bright_black" = ansi 8;
          "terminal.ansi.bright_red" = ansi 9;
          "terminal.ansi.bright_green" = ansi 10;
          "terminal.ansi.bright_yellow" = ansi 11;
          "terminal.ansi.bright_blue" = ansi 12;
          "terminal.ansi.bright_magenta" = ansi 13;
          "terminal.ansi.bright_cyan" = ansi 14;
          "terminal.ansi.bright_white" = ansi 15;
          "terminal.ansi.dim_black" = ansi 0;
          "terminal.ansi.dim_red" = ansi 1;
          "terminal.ansi.dim_green" = ansi 2;
          "terminal.ansi.dim_yellow" = ansi 3;
          "terminal.ansi.dim_blue" = ansi 4;
          "terminal.ansi.dim_magenta" = ansi 5;
          "terminal.ansi.dim_cyan" = ansi 6;
          "terminal.ansi.dim_white" = ansi 7;

          syntax = {
            attribute = {
              color = color.accent;
            };
            boolean = {
              color = color.warning;
            };
            comment = {
              color = color.text.faint;
              font_style = "italic";
            };
            "comment.doc" = {
              color = color.text.soft;
              font_style = "italic";
            };
            constant = {
              color = color.warning;
            };
            constructor = {
              color = color.accent;
            };
            embedded = {
              color = color.text.base;
            };
            emphasis = {
              color = color.accent;
              font_style = "italic";
            };
            "emphasis.strong" = {
              color = color.accent;
              font_weight = 700;
            };
            enum = {
              color = color.accent;
            };
            function = {
              color = color.accent;
            };
            hint = {
              color = color.text.faint;
            };
            keyword = {
              color = color.accent;
              font_weight = 600;
            };
            label = {
              color = color.accent;
            };
            link_text = {
              color = color.accent;
            };
            link_uri = {
              color = color.text.soft;
              font_style = "italic";
            };
            number = {
              color = color.warning;
            };
            operator = {
              color = color.text.soft;
            };
            predictive = {
              color = color.text.faint;
              font_style = "italic";
            };
            preproc = {
              color = color.accent;
            };
            primary = {
              color = color.text.base;
            };
            property = {
              color = color.accent;
            };
            punctuation = {
              color = color.text.soft;
            };
            "punctuation.bracket" = {
              color = color.text.base;
            };
            "punctuation.delimiter" = {
              color = color.text.faint;
            };
            string = {
              color = color.success;
            };
            "string.escape" = {
              color = color.warning;
            };
            "string.regex" = {
              color = color.success;
            };
            "string.special" = {
              color = color.accent;
            };
            "string.special.symbol" = {
              color = color.accent;
            };
            tag = {
              color = color.accent;
            };
            "text.literal" = {
              color = color.text.soft;
            };
            title = {
              color = color.text.base;
              font_weight = 700;
            };
            type = {
              color = color.accent;
            };
            variable = {
              color = color.text.base;
            };
            "variable.special" = {
              color = color.warning;
            };
            variant = {
              color = color.accent;
            };
          };
        };
      }
    ];
  };
in
{
  programs.zed-editor = {
    enable = true;
    package = null;
    mutableUserSettings = true;
    userSettings = {
      theme = theme.name;
      ui_font_family = typography.sans;
      ui_font_size = typography.size.body;
      buffer_font_family = typography.code;
      buffer_font_size = typography.size.code;
      load_direnv = "direct";
      terminal.font_family = typography.code;
    };
    themes.${theme.name} = themeDocument;
  };
}
