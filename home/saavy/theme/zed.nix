{ theme, ... }:
let
  inherit (theme) colors typography;
  ansi = builtins.elemAt theme.terminal;
  withAlpha = color: alpha: "${color}${alpha}";
  transparent = withAlpha colors.background "00";
  subtleSelection = withAlpha colors.selection "80";
  themeDocument = {
    name = theme.name;
    author = "Solitude NixOS";
    themes = [
      {
        name = theme.name;
        appearance = theme.polarity;
        style = {
          accents = [
            colors.accent
            colors.success
            colors.warning
            colors.foregroundWarm
            colors.foregroundSoft
          ];

          background = colors.background;
          "background.appearance" = "opaque";
          border = colors.border;
          "border.disabled" = colors.muted;
          "border.focused" = colors.accent;
          "border.selected" = colors.foregroundSoft;
          "border.transparent" = transparent;
          "border.variant" = colors.selection;

          conflict = colors.warning;
          "conflict.background" = withAlpha colors.warning "20";
          "conflict.border" = withAlpha colors.warning "80";
          created = colors.success;
          "created.background" = withAlpha colors.success "20";
          "created.border" = withAlpha colors.success "80";
          deleted = colors.error;
          "deleted.background" = withAlpha colors.error "20";
          "deleted.border" = withAlpha colors.error "80";
          modified = colors.warning;
          "modified.background" = withAlpha colors.warning "20";
          "modified.border" = withAlpha colors.warning "80";
          renamed = colors.accent;
          "renamed.background" = withAlpha colors.accent "20";
          "renamed.border" = withAlpha colors.accent "80";
          ignored = colors.muted;
          "ignored.background" = withAlpha colors.muted "20";
          "ignored.border" = withAlpha colors.muted "80";
          hidden = colors.muted;
          "hidden.background" = withAlpha colors.muted "20";
          "hidden.border" = withAlpha colors.muted "80";
          unreachable = colors.muted;
          "unreachable.background" = withAlpha colors.muted "20";
          "unreachable.border" = withAlpha colors.muted "80";

          error = colors.error;
          "error.background" = withAlpha colors.error "20";
          "error.border" = withAlpha colors.error "80";
          warning = colors.warning;
          "warning.background" = withAlpha colors.warning "20";
          "warning.border" = withAlpha colors.warning "80";
          success = colors.success;
          "success.background" = withAlpha colors.success "20";
          "success.border" = withAlpha colors.success "80";
          info = colors.accent;
          "info.background" = withAlpha colors.accent "20";
          "info.border" = withAlpha colors.accent "80";
          hint = colors.foregroundSoft;
          "hint.background" = withAlpha colors.foregroundSoft "18";
          "hint.border" = withAlpha colors.foregroundSoft "70";
          predictive = colors.muted;
          "predictive.background" = withAlpha colors.muted "18";
          "predictive.border" = withAlpha colors.muted "70";

          "surface.background" = colors.backgroundDark;
          "elevated_surface.background" = colors.backgroundDarker;
          "drop_target.background" = withAlpha colors.accent "30";
          "panel.background" = colors.backgroundDark;
          "panel.focused_border" = colors.accent;
          "panel.indent_guide" = colors.selection;
          "panel.indent_guide_active" = colors.border;
          "panel.indent_guide_hover" = colors.foregroundSoft;
          "pane.focused_border" = colors.accent;
          "pane_group.border" = colors.border;
          "status_bar.background" = colors.backgroundDarker;
          "title_bar.background" = colors.backgroundDark;
          "title_bar.inactive_background" = colors.backgroundDarker;
          "toolbar.background" = colors.backgroundDark;
          "tab_bar.background" = colors.backgroundDarker;
          "tab.active_background" = colors.background;
          "tab.inactive_background" = colors.backgroundDark;

          "element.background" = transparent;
          "element.hover" = withAlpha colors.selection "70";
          "element.active" = colors.selection;
          "element.selected" = subtleSelection;
          "element.disabled" = withAlpha colors.muted "18";
          "ghost_element.background" = transparent;
          "ghost_element.hover" = withAlpha colors.selection "70";
          "ghost_element.active" = colors.selection;
          "ghost_element.selected" = subtleSelection;
          "ghost_element.disabled" = withAlpha colors.muted "18";

          text = colors.foreground;
          "text.muted" = colors.foregroundSoft;
          "text.placeholder" = colors.muted;
          "text.disabled" = colors.muted;
          "text.accent" = colors.accent;
          icon = colors.foreground;
          "icon.muted" = colors.foregroundSoft;
          "icon.placeholder" = colors.muted;
          "icon.disabled" = colors.muted;
          "icon.accent" = colors.accent;
          "link_text.hover" = colors.foregroundWarm;

          "scrollbar.track.background" = transparent;
          "scrollbar.track.border" = transparent;
          "scrollbar.thumb.background" = withAlpha colors.border "80";
          "scrollbar.thumb.hover_background" = colors.border;
          "scrollbar.thumb.border" = transparent;
          "search.match_background" = withAlpha colors.warning "35";

          "editor.background" = colors.background;
          "editor.foreground" = colors.foreground;
          "editor.gutter.background" = colors.background;
          "editor.subheader.background" = colors.backgroundDark;
          "editor.active_line.background" = withAlpha colors.selection "45";
          "editor.highlighted_line.background" = withAlpha colors.selection "70";
          "editor.line_number" = colors.muted;
          "editor.active_line_number" = colors.foregroundSoft;
          "editor.invisible" = colors.muted;
          "editor.indent_guide" = colors.selection;
          "editor.indent_guide_active" = colors.border;
          "editor.wrap_guide" = colors.selection;
          "editor.active_wrap_guide" = colors.border;
          "editor.document_highlight.bracket_background" = withAlpha colors.accent "35";
          "editor.document_highlight.read_background" = withAlpha colors.selection "70";
          "editor.document_highlight.write_background" = withAlpha colors.accent "30";

          players = [
            {
              cursor = colors.accent;
              background = withAlpha colors.accent "20";
              selection = withAlpha colors.accent "50";
            }
            {
              cursor = colors.success;
              background = withAlpha colors.success "20";
              selection = withAlpha colors.success "50";
            }
            {
              cursor = colors.warning;
              background = withAlpha colors.warning "20";
              selection = withAlpha colors.warning "50";
            }
            {
              cursor = colors.foregroundWarm;
              background = withAlpha colors.foregroundWarm "20";
              selection = withAlpha colors.foregroundWarm "50";
            }
          ];

          "terminal.background" = colors.background;
          "terminal.foreground" = colors.foreground;
          "terminal.bright_foreground" = colors.foregroundWarm;
          "terminal.dim_foreground" = colors.foregroundSoft;
          "terminal.ansi.background" = colors.background;
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
              color = colors.accent;
            };
            boolean = {
              color = colors.warning;
            };
            comment = {
              color = colors.muted;
              font_style = "italic";
            };
            "comment.doc" = {
              color = colors.foregroundSoft;
              font_style = "italic";
            };
            constant = {
              color = colors.warning;
            };
            constructor = {
              color = colors.foregroundWarm;
            };
            embedded = {
              color = colors.foreground;
            };
            emphasis = {
              color = colors.foregroundWarm;
              font_style = "italic";
            };
            "emphasis.strong" = {
              color = colors.foregroundWarm;
              font_weight = 700;
            };
            enum = {
              color = colors.accent;
            };
            function = {
              color = colors.foregroundWarm;
            };
            hint = {
              color = colors.muted;
            };
            keyword = {
              color = colors.accent;
              font_weight = 600;
            };
            label = {
              color = colors.foregroundWarm;
            };
            link_text = {
              color = colors.accent;
            };
            link_uri = {
              color = colors.foregroundSoft;
              font_style = "italic";
            };
            number = {
              color = colors.warning;
            };
            operator = {
              color = colors.foregroundSoft;
            };
            predictive = {
              color = colors.muted;
              font_style = "italic";
            };
            preproc = {
              color = colors.accent;
            };
            primary = {
              color = colors.foreground;
            };
            property = {
              color = colors.foregroundWarm;
            };
            punctuation = {
              color = colors.foregroundSoft;
            };
            "punctuation.bracket" = {
              color = colors.foreground;
            };
            "punctuation.delimiter" = {
              color = colors.muted;
            };
            string = {
              color = colors.success;
            };
            "string.escape" = {
              color = colors.warning;
            };
            "string.regex" = {
              color = colors.success;
            };
            "string.special" = {
              color = colors.foregroundWarm;
            };
            "string.special.symbol" = {
              color = colors.accent;
            };
            tag = {
              color = colors.accent;
            };
            "text.literal" = {
              color = colors.foregroundSoft;
            };
            title = {
              color = colors.foreground;
              font_weight = 700;
            };
            type = {
              color = colors.accent;
            };
            variable = {
              color = colors.foreground;
            };
            "variable.special" = {
              color = colors.warning;
            };
            variant = {
              color = colors.foregroundWarm;
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
      buffer_font_family = typography.mono;
      buffer_font_size = typography.size.body;
      load_direnv = "direct";
      terminal.font_family = typography.mono;
    };
    themes.${theme.name} = themeDocument;
  };
}
