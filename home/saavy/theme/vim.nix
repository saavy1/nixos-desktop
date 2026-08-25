{ lib, theme, ... }:
let
  inherit (theme) colors;
  terminalColors = builtins.concatStringsSep ", " (map (color: "'${color}'") theme.terminal);
  colorscheme = ''
    hi clear
    if exists('syntax_on')
      syntax reset
    endif
    let g:colors_name = '${theme.name}'
    set background=${theme.polarity}
    if has('termguicolors')
      set termguicolors
    endif

    let g:terminal_ansi_colors = [${terminalColors}]

    hi Normal guifg=${colors.foreground} guibg=${colors.background} gui=NONE ctermfg=7 ctermbg=0 cterm=NONE
    hi NormalNC guifg=${colors.foregroundSoft} guibg=${colors.background} gui=NONE ctermfg=15 ctermbg=0 cterm=NONE
    hi EndOfBuffer guifg=${colors.background} guibg=${colors.background} gui=NONE ctermfg=0 ctermbg=0 cterm=NONE
    hi NonText guifg=${colors.muted} guibg=NONE gui=NONE ctermfg=8 ctermbg=NONE cterm=NONE
    hi SpecialKey guifg=${colors.muted} guibg=NONE gui=NONE ctermfg=8 ctermbg=NONE cterm=NONE
    hi Whitespace guifg=${colors.muted} guibg=NONE gui=NONE ctermfg=8 ctermbg=NONE cterm=NONE

    hi Cursor guifg=${colors.background} guibg=${colors.accent} gui=NONE ctermfg=0 ctermbg=12 cterm=NONE
    hi CursorIM guifg=${colors.background} guibg=${colors.foregroundWarm} gui=NONE ctermfg=0 ctermbg=15 cterm=NONE
    hi CursorLine guifg=NONE guibg=${colors.backgroundDark} gui=NONE ctermfg=NONE ctermbg=0 cterm=NONE
    hi CursorColumn guifg=NONE guibg=${colors.backgroundDark} gui=NONE ctermfg=NONE ctermbg=0 cterm=NONE
    hi CursorLineNr guifg=${colors.foreground} guibg=${colors.backgroundDark} gui=bold ctermfg=7 ctermbg=0 cterm=bold
    hi LineNr guifg=${colors.muted} guibg=${colors.background} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE
    hi LineNrAbove guifg=${colors.muted} guibg=${colors.background} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE
    hi LineNrBelow guifg=${colors.muted} guibg=${colors.background} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE
    hi SignColumn guifg=${colors.foregroundSoft} guibg=${colors.background} gui=NONE ctermfg=15 ctermbg=0 cterm=NONE
    hi FoldColumn guifg=${colors.muted} guibg=${colors.backgroundDark} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE
    hi Folded guifg=${colors.foregroundSoft} guibg=${colors.backgroundDark} gui=italic ctermfg=15 ctermbg=0 cterm=NONE
    hi ColorColumn guifg=NONE guibg=${colors.backgroundDark} gui=NONE ctermfg=NONE ctermbg=8 cterm=NONE

    hi Visual guifg=${colors.foreground} guibg=${colors.selection} gui=NONE ctermfg=7 ctermbg=8 cterm=NONE
    hi VisualNOS guifg=${colors.foreground} guibg=${colors.selection} gui=underline ctermfg=7 ctermbg=8 cterm=underline
    hi Search guifg=${colors.background} guibg=${colors.warning} gui=bold ctermfg=0 ctermbg=11 cterm=bold
    hi IncSearch guifg=${colors.background} guibg=${colors.accent} gui=bold ctermfg=0 ctermbg=12 cterm=bold
    hi CurSearch guifg=${colors.background} guibg=${colors.foregroundWarm} gui=bold ctermfg=0 ctermbg=15 cterm=bold
    hi Substitute guifg=${colors.background} guibg=${colors.error} gui=bold ctermfg=0 ctermbg=9 cterm=bold
    hi MatchParen guifg=${colors.foreground} guibg=${colors.selection} gui=bold ctermfg=7 ctermbg=8 cterm=bold

    hi StatusLine guifg=${colors.background} guibg=${colors.accent} gui=bold ctermfg=0 ctermbg=12 cterm=bold
    hi StatusLineNC guifg=${colors.foregroundSoft} guibg=${colors.backgroundDarker} gui=NONE ctermfg=15 ctermbg=0 cterm=NONE
    hi TabLine guifg=${colors.foregroundSoft} guibg=${colors.backgroundDark} gui=NONE ctermfg=15 ctermbg=0 cterm=NONE
    hi TabLineFill guifg=${colors.border} guibg=${colors.backgroundDarker} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE
    hi TabLineSel guifg=${colors.foreground} guibg=${colors.selection} gui=bold ctermfg=7 ctermbg=8 cterm=bold
    hi WinBar guifg=${colors.foreground} guibg=${colors.backgroundDark} gui=bold ctermfg=7 ctermbg=0 cterm=bold
    hi WinBarNC guifg=${colors.muted} guibg=${colors.backgroundDark} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE
    hi VertSplit guifg=${colors.border} guibg=${colors.background} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE
    hi WinSeparator guifg=${colors.border} guibg=${colors.background} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE

    hi Pmenu guifg=${colors.foreground} guibg=${colors.backgroundDark} gui=NONE ctermfg=7 ctermbg=0 cterm=NONE
    hi PmenuSel guifg=${colors.foreground} guibg=${colors.selection} gui=bold ctermfg=7 ctermbg=8 cterm=bold
    hi PmenuSbar guifg=NONE guibg=${colors.backgroundDarker} gui=NONE ctermfg=NONE ctermbg=0 cterm=NONE
    hi PmenuThumb guifg=NONE guibg=${colors.border} gui=NONE ctermfg=NONE ctermbg=8 cterm=NONE
    hi PmenuMatch guifg=${colors.accent} guibg=${colors.backgroundDark} gui=bold ctermfg=12 ctermbg=0 cterm=bold
    hi PmenuMatchSel guifg=${colors.foregroundWarm} guibg=${colors.selection} gui=bold ctermfg=15 ctermbg=8 cterm=bold
    hi WildMenu guifg=${colors.background} guibg=${colors.accent} gui=bold ctermfg=0 ctermbg=12 cterm=bold

    hi Directory guifg=${colors.accent} guibg=NONE gui=bold ctermfg=12 ctermbg=NONE cterm=bold
    hi Title guifg=${colors.foregroundWarm} guibg=NONE gui=bold ctermfg=15 ctermbg=NONE cterm=bold
    hi Question guifg=${colors.success} guibg=NONE gui=bold ctermfg=10 ctermbg=NONE cterm=bold
    hi MoreMsg guifg=${colors.success} guibg=NONE gui=NONE ctermfg=10 ctermbg=NONE cterm=NONE
    hi ModeMsg guifg=${colors.foreground} guibg=NONE gui=bold ctermfg=7 ctermbg=NONE cterm=bold
    hi WarningMsg guifg=${colors.warning} guibg=NONE gui=bold ctermfg=11 ctermbg=NONE cterm=bold
    hi ErrorMsg guifg=${colors.error} guibg=NONE gui=bold ctermfg=9 ctermbg=NONE cterm=bold

    hi Comment guifg=${colors.muted} guibg=NONE gui=italic ctermfg=8 ctermbg=NONE cterm=italic
    hi Constant guifg=${colors.warning} guibg=NONE gui=NONE ctermfg=11 ctermbg=NONE cterm=NONE
    hi String guifg=${colors.success} guibg=NONE gui=NONE ctermfg=10 ctermbg=NONE cterm=NONE
    hi Character guifg=${colors.success} guibg=NONE gui=NONE ctermfg=10 ctermbg=NONE cterm=NONE
    hi Number guifg=${colors.warning} guibg=NONE gui=NONE ctermfg=11 ctermbg=NONE cterm=NONE
    hi Boolean guifg=${colors.warning} guibg=NONE gui=bold ctermfg=11 ctermbg=NONE cterm=bold
    hi Float guifg=${colors.warning} guibg=NONE gui=NONE ctermfg=11 ctermbg=NONE cterm=NONE
    hi Identifier guifg=${colors.foreground} guibg=NONE gui=NONE ctermfg=7 ctermbg=NONE cterm=NONE
    hi Function guifg=${colors.foregroundWarm} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi Statement guifg=${colors.accent} guibg=NONE gui=bold ctermfg=12 ctermbg=NONE cterm=bold
    hi Conditional guifg=${colors.accent} guibg=NONE gui=bold ctermfg=12 ctermbg=NONE cterm=bold
    hi Repeat guifg=${colors.accent} guibg=NONE gui=bold ctermfg=12 ctermbg=NONE cterm=bold
    hi Label guifg=${colors.foregroundWarm} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi Operator guifg=${colors.foregroundSoft} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi Keyword guifg=${colors.accent} guibg=NONE gui=bold ctermfg=12 ctermbg=NONE cterm=bold
    hi Exception guifg=${colors.error} guibg=NONE gui=bold ctermfg=9 ctermbg=NONE cterm=bold
    hi PreProc guifg=${colors.accent} guibg=NONE gui=NONE ctermfg=12 ctermbg=NONE cterm=NONE
    hi Include guifg=${colors.accent} guibg=NONE gui=NONE ctermfg=12 ctermbg=NONE cterm=NONE
    hi Define guifg=${colors.foregroundWarm} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi Macro guifg=${colors.foregroundWarm} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi PreCondit guifg=${colors.warning} guibg=NONE gui=NONE ctermfg=11 ctermbg=NONE cterm=NONE
    hi Type guifg=${colors.accent} guibg=NONE gui=NONE ctermfg=12 ctermbg=NONE cterm=NONE
    hi StorageClass guifg=${colors.foregroundWarm} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi Structure guifg=${colors.accent} guibg=NONE gui=NONE ctermfg=12 ctermbg=NONE cterm=NONE
    hi Typedef guifg=${colors.accent} guibg=NONE gui=NONE ctermfg=12 ctermbg=NONE cterm=NONE
    hi Special guifg=${colors.foregroundWarm} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi SpecialChar guifg=${colors.warning} guibg=NONE gui=NONE ctermfg=11 ctermbg=NONE cterm=NONE
    hi Tag guifg=${colors.accent} guibg=NONE gui=NONE ctermfg=12 ctermbg=NONE cterm=NONE
    hi Delimiter guifg=${colors.foregroundSoft} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi SpecialComment guifg=${colors.foregroundSoft} guibg=NONE gui=italic ctermfg=15 ctermbg=NONE cterm=italic
    hi Debug guifg=${colors.error} guibg=NONE gui=NONE ctermfg=9 ctermbg=NONE cterm=NONE
    hi Underlined guifg=${colors.accent} guibg=NONE gui=underline ctermfg=12 ctermbg=NONE cterm=underline
    hi Ignore guifg=${colors.muted} guibg=NONE gui=NONE ctermfg=8 ctermbg=NONE cterm=NONE
    hi Error guifg=${colors.error} guibg=${colors.backgroundDark} gui=bold ctermfg=9 ctermbg=0 cterm=bold
    hi Todo guifg=${colors.background} guibg=${colors.warning} gui=bold ctermfg=0 ctermbg=11 cterm=bold

    hi DiffAdd guifg=${colors.success} guibg=${colors.backgroundDark} gui=NONE ctermfg=10 ctermbg=0 cterm=NONE
    hi DiffChange guifg=${colors.warning} guibg=${colors.backgroundDark} gui=NONE ctermfg=11 ctermbg=0 cterm=NONE
    hi DiffDelete guifg=${colors.error} guibg=${colors.backgroundDark} gui=NONE ctermfg=9 ctermbg=0 cterm=NONE
    hi DiffText guifg=${colors.background} guibg=${colors.warning} gui=bold ctermfg=0 ctermbg=11 cterm=bold
    hi Added guifg=${colors.success} guibg=NONE gui=NONE ctermfg=10 ctermbg=NONE cterm=NONE
    hi Changed guifg=${colors.warning} guibg=NONE gui=NONE ctermfg=11 ctermbg=NONE cterm=NONE
    hi Removed guifg=${colors.error} guibg=NONE gui=NONE ctermfg=9 ctermbg=NONE cterm=NONE

    hi SpellBad guifg=${colors.error} guibg=NONE gui=undercurl guisp=${colors.error} ctermfg=9 ctermbg=NONE cterm=underline
    hi SpellCap guifg=${colors.warning} guibg=NONE gui=undercurl guisp=${colors.warning} ctermfg=11 ctermbg=NONE cterm=underline
    hi SpellLocal guifg=${colors.accent} guibg=NONE gui=undercurl guisp=${colors.accent} ctermfg=12 ctermbg=NONE cterm=underline
    hi SpellRare guifg=${colors.foregroundWarm} guibg=NONE gui=undercurl guisp=${colors.foregroundWarm} ctermfg=15 ctermbg=NONE cterm=underline

    hi DiagnosticError guifg=${colors.error} guibg=NONE gui=NONE ctermfg=9 ctermbg=NONE cterm=NONE
    hi DiagnosticWarn guifg=${colors.warning} guibg=NONE gui=NONE ctermfg=11 ctermbg=NONE cterm=NONE
    hi DiagnosticInfo guifg=${colors.accent} guibg=NONE gui=NONE ctermfg=12 ctermbg=NONE cterm=NONE
    hi DiagnosticHint guifg=${colors.foregroundSoft} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi DiagnosticOk guifg=${colors.success} guibg=NONE gui=NONE ctermfg=10 ctermbg=NONE cterm=NONE
    hi DiagnosticUnderlineError guifg=NONE guibg=NONE gui=undercurl guisp=${colors.error} ctermfg=NONE ctermbg=NONE cterm=underline
    hi DiagnosticUnderlineWarn guifg=NONE guibg=NONE gui=undercurl guisp=${colors.warning} ctermfg=NONE ctermbg=NONE cterm=underline
    hi DiagnosticUnderlineInfo guifg=NONE guibg=NONE gui=undercurl guisp=${colors.accent} ctermfg=NONE ctermbg=NONE cterm=underline
    hi DiagnosticUnderlineHint guifg=NONE guibg=NONE gui=undercurl guisp=${colors.foregroundSoft} ctermfg=NONE ctermbg=NONE cterm=underline
  '';
in
{
  home.file.".vim/colors/${theme.name}.vim".text = colorscheme;

  programs.vim.extraConfig = lib.mkAfter ''
    colorscheme ${theme.name}
  '';
}
