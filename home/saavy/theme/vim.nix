{ lib, theme, ... }:
let
  inherit (theme) color;
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

    hi Normal guifg=${color.text.base} guibg=${color.surface.base} gui=NONE ctermfg=7 ctermbg=0 cterm=NONE
    hi NormalNC guifg=${color.text.soft} guibg=${color.surface.base} gui=NONE ctermfg=15 ctermbg=0 cterm=NONE
    hi EndOfBuffer guifg=${color.surface.base} guibg=${color.surface.base} gui=NONE ctermfg=0 ctermbg=0 cterm=NONE
    hi NonText guifg=${color.text.faint} guibg=NONE gui=NONE ctermfg=8 ctermbg=NONE cterm=NONE
    hi SpecialKey guifg=${color.text.faint} guibg=NONE gui=NONE ctermfg=8 ctermbg=NONE cterm=NONE
    hi Whitespace guifg=${color.text.faint} guibg=NONE gui=NONE ctermfg=8 ctermbg=NONE cterm=NONE

    hi Cursor guifg=${color.surface.base} guibg=${color.accent} gui=NONE ctermfg=0 ctermbg=12 cterm=NONE
    hi CursorIM guifg=${color.surface.base} guibg=${color.accent} gui=NONE ctermfg=0 ctermbg=15 cterm=NONE
    hi CursorLine guifg=NONE guibg=${color.surface.sunk} gui=NONE ctermfg=NONE ctermbg=0 cterm=NONE
    hi CursorColumn guifg=NONE guibg=${color.surface.sunk} gui=NONE ctermfg=NONE ctermbg=0 cterm=NONE
    hi CursorLineNr guifg=${color.text.base} guibg=${color.surface.sunk} gui=bold ctermfg=7 ctermbg=0 cterm=bold
    hi LineNr guifg=${color.text.faint} guibg=${color.surface.base} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE
    hi LineNrAbove guifg=${color.text.faint} guibg=${color.surface.base} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE
    hi LineNrBelow guifg=${color.text.faint} guibg=${color.surface.base} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE
    hi SignColumn guifg=${color.text.soft} guibg=${color.surface.base} gui=NONE ctermfg=15 ctermbg=0 cterm=NONE
    hi FoldColumn guifg=${color.text.faint} guibg=${color.surface.sunk} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE
    hi Folded guifg=${color.text.soft} guibg=${color.surface.sunk} gui=italic ctermfg=15 ctermbg=0 cterm=NONE
    hi ColorColumn guifg=NONE guibg=${color.surface.sunk} gui=NONE ctermfg=NONE ctermbg=8 cterm=NONE

    hi Visual guifg=${color.text.base} guibg=${color.surface.hover} gui=NONE ctermfg=7 ctermbg=8 cterm=NONE
    hi VisualNOS guifg=${color.text.base} guibg=${color.surface.hover} gui=underline ctermfg=7 ctermbg=8 cterm=underline
    hi Search guifg=${color.surface.base} guibg=${color.warning} gui=bold ctermfg=0 ctermbg=11 cterm=bold
    hi IncSearch guifg=${color.surface.base} guibg=${color.accent} gui=bold ctermfg=0 ctermbg=12 cterm=bold
    hi CurSearch guifg=${color.surface.base} guibg=${color.accent} gui=bold ctermfg=0 ctermbg=15 cterm=bold
    hi Substitute guifg=${color.surface.base} guibg=${color.danger} gui=bold ctermfg=0 ctermbg=9 cterm=bold
    hi MatchParen guifg=${color.text.base} guibg=${color.surface.hover} gui=bold ctermfg=7 ctermbg=8 cterm=bold

    hi StatusLine guifg=${color.surface.base} guibg=${color.accent} gui=bold ctermfg=0 ctermbg=12 cterm=bold
    hi StatusLineNC guifg=${color.text.soft} guibg=${color.surface.deep} gui=NONE ctermfg=15 ctermbg=0 cterm=NONE
    hi TabLine guifg=${color.text.soft} guibg=${color.surface.sunk} gui=NONE ctermfg=15 ctermbg=0 cterm=NONE
    hi TabLineFill guifg=${color.lineSolid} guibg=${color.surface.deep} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE
    hi TabLineSel guifg=${color.text.base} guibg=${color.surface.hover} gui=bold ctermfg=7 ctermbg=8 cterm=bold
    hi WinBar guifg=${color.text.base} guibg=${color.surface.sunk} gui=bold ctermfg=7 ctermbg=0 cterm=bold
    hi WinBarNC guifg=${color.text.faint} guibg=${color.surface.sunk} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE
    hi VertSplit guifg=${color.lineSolid} guibg=${color.surface.base} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE
    hi WinSeparator guifg=${color.lineSolid} guibg=${color.surface.base} gui=NONE ctermfg=8 ctermbg=0 cterm=NONE

    hi Pmenu guifg=${color.text.base} guibg=${color.surface.sunk} gui=NONE ctermfg=7 ctermbg=0 cterm=NONE
    hi PmenuSel guifg=${color.text.base} guibg=${color.surface.hover} gui=bold ctermfg=7 ctermbg=8 cterm=bold
    hi PmenuSbar guifg=NONE guibg=${color.surface.deep} gui=NONE ctermfg=NONE ctermbg=0 cterm=NONE
    hi PmenuThumb guifg=NONE guibg=${color.lineSolid} gui=NONE ctermfg=NONE ctermbg=8 cterm=NONE
    hi PmenuMatch guifg=${color.accent} guibg=${color.surface.sunk} gui=bold ctermfg=12 ctermbg=0 cterm=bold
    hi PmenuMatchSel guifg=${color.accent} guibg=${color.surface.hover} gui=bold ctermfg=15 ctermbg=8 cterm=bold
    hi WildMenu guifg=${color.surface.base} guibg=${color.accent} gui=bold ctermfg=0 ctermbg=12 cterm=bold

    hi Directory guifg=${color.accent} guibg=NONE gui=bold ctermfg=12 ctermbg=NONE cterm=bold
    hi Title guifg=${color.accent} guibg=NONE gui=bold ctermfg=15 ctermbg=NONE cterm=bold
    hi Question guifg=${color.success} guibg=NONE gui=bold ctermfg=10 ctermbg=NONE cterm=bold
    hi MoreMsg guifg=${color.success} guibg=NONE gui=NONE ctermfg=10 ctermbg=NONE cterm=NONE
    hi ModeMsg guifg=${color.text.base} guibg=NONE gui=bold ctermfg=7 ctermbg=NONE cterm=bold
    hi WarningMsg guifg=${color.warning} guibg=NONE gui=bold ctermfg=11 ctermbg=NONE cterm=bold
    hi ErrorMsg guifg=${color.danger} guibg=NONE gui=bold ctermfg=9 ctermbg=NONE cterm=bold

    hi Comment guifg=${color.text.faint} guibg=NONE gui=italic ctermfg=8 ctermbg=NONE cterm=italic
    hi Constant guifg=${color.warning} guibg=NONE gui=NONE ctermfg=11 ctermbg=NONE cterm=NONE
    hi String guifg=${color.success} guibg=NONE gui=NONE ctermfg=10 ctermbg=NONE cterm=NONE
    hi Character guifg=${color.success} guibg=NONE gui=NONE ctermfg=10 ctermbg=NONE cterm=NONE
    hi Number guifg=${color.warning} guibg=NONE gui=NONE ctermfg=11 ctermbg=NONE cterm=NONE
    hi Boolean guifg=${color.warning} guibg=NONE gui=bold ctermfg=11 ctermbg=NONE cterm=bold
    hi Float guifg=${color.warning} guibg=NONE gui=NONE ctermfg=11 ctermbg=NONE cterm=NONE
    hi Identifier guifg=${color.text.base} guibg=NONE gui=NONE ctermfg=7 ctermbg=NONE cterm=NONE
    hi Function guifg=${color.accent} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi Statement guifg=${color.accent} guibg=NONE gui=bold ctermfg=12 ctermbg=NONE cterm=bold
    hi Conditional guifg=${color.accent} guibg=NONE gui=bold ctermfg=12 ctermbg=NONE cterm=bold
    hi Repeat guifg=${color.accent} guibg=NONE gui=bold ctermfg=12 ctermbg=NONE cterm=bold
    hi Label guifg=${color.accent} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi Operator guifg=${color.text.soft} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi Keyword guifg=${color.accent} guibg=NONE gui=bold ctermfg=12 ctermbg=NONE cterm=bold
    hi Exception guifg=${color.danger} guibg=NONE gui=bold ctermfg=9 ctermbg=NONE cterm=bold
    hi PreProc guifg=${color.accent} guibg=NONE gui=NONE ctermfg=12 ctermbg=NONE cterm=NONE
    hi Include guifg=${color.accent} guibg=NONE gui=NONE ctermfg=12 ctermbg=NONE cterm=NONE
    hi Define guifg=${color.accent} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi Macro guifg=${color.accent} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi PreCondit guifg=${color.warning} guibg=NONE gui=NONE ctermfg=11 ctermbg=NONE cterm=NONE
    hi Type guifg=${color.accent} guibg=NONE gui=NONE ctermfg=12 ctermbg=NONE cterm=NONE
    hi StorageClass guifg=${color.accent} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi Structure guifg=${color.accent} guibg=NONE gui=NONE ctermfg=12 ctermbg=NONE cterm=NONE
    hi Typedef guifg=${color.accent} guibg=NONE gui=NONE ctermfg=12 ctermbg=NONE cterm=NONE
    hi Special guifg=${color.accent} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi SpecialChar guifg=${color.warning} guibg=NONE gui=NONE ctermfg=11 ctermbg=NONE cterm=NONE
    hi Tag guifg=${color.accent} guibg=NONE gui=NONE ctermfg=12 ctermbg=NONE cterm=NONE
    hi Delimiter guifg=${color.text.soft} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi SpecialComment guifg=${color.text.soft} guibg=NONE gui=italic ctermfg=15 ctermbg=NONE cterm=italic
    hi Debug guifg=${color.danger} guibg=NONE gui=NONE ctermfg=9 ctermbg=NONE cterm=NONE
    hi Underlined guifg=${color.accent} guibg=NONE gui=underline ctermfg=12 ctermbg=NONE cterm=underline
    hi Ignore guifg=${color.text.faint} guibg=NONE gui=NONE ctermfg=8 ctermbg=NONE cterm=NONE
    hi Error guifg=${color.danger} guibg=${color.surface.sunk} gui=bold ctermfg=9 ctermbg=0 cterm=bold
    hi Todo guifg=${color.surface.base} guibg=${color.warning} gui=bold ctermfg=0 ctermbg=11 cterm=bold

    hi DiffAdd guifg=${color.success} guibg=${color.surface.sunk} gui=NONE ctermfg=10 ctermbg=0 cterm=NONE
    hi DiffChange guifg=${color.warning} guibg=${color.surface.sunk} gui=NONE ctermfg=11 ctermbg=0 cterm=NONE
    hi DiffDelete guifg=${color.danger} guibg=${color.surface.sunk} gui=NONE ctermfg=9 ctermbg=0 cterm=NONE
    hi DiffText guifg=${color.surface.base} guibg=${color.warning} gui=bold ctermfg=0 ctermbg=11 cterm=bold
    hi Added guifg=${color.success} guibg=NONE gui=NONE ctermfg=10 ctermbg=NONE cterm=NONE
    hi Changed guifg=${color.warning} guibg=NONE gui=NONE ctermfg=11 ctermbg=NONE cterm=NONE
    hi Removed guifg=${color.danger} guibg=NONE gui=NONE ctermfg=9 ctermbg=NONE cterm=NONE

    hi SpellBad guifg=${color.danger} guibg=NONE gui=undercurl guisp=${color.danger} ctermfg=9 ctermbg=NONE cterm=underline
    hi SpellCap guifg=${color.warning} guibg=NONE gui=undercurl guisp=${color.warning} ctermfg=11 ctermbg=NONE cterm=underline
    hi SpellLocal guifg=${color.accent} guibg=NONE gui=undercurl guisp=${color.accent} ctermfg=12 ctermbg=NONE cterm=underline
    hi SpellRare guifg=${color.accent} guibg=NONE gui=undercurl guisp=${color.accent} ctermfg=15 ctermbg=NONE cterm=underline

    hi DiagnosticError guifg=${color.danger} guibg=NONE gui=NONE ctermfg=9 ctermbg=NONE cterm=NONE
    hi DiagnosticWarn guifg=${color.warning} guibg=NONE gui=NONE ctermfg=11 ctermbg=NONE cterm=NONE
    hi DiagnosticInfo guifg=${color.accent} guibg=NONE gui=NONE ctermfg=12 ctermbg=NONE cterm=NONE
    hi DiagnosticHint guifg=${color.text.soft} guibg=NONE gui=NONE ctermfg=15 ctermbg=NONE cterm=NONE
    hi DiagnosticOk guifg=${color.success} guibg=NONE gui=NONE ctermfg=10 ctermbg=NONE cterm=NONE
    hi DiagnosticUnderlineError guifg=NONE guibg=NONE gui=undercurl guisp=${color.danger} ctermfg=NONE ctermbg=NONE cterm=underline
    hi DiagnosticUnderlineWarn guifg=NONE guibg=NONE gui=undercurl guisp=${color.warning} ctermfg=NONE ctermbg=NONE cterm=underline
    hi DiagnosticUnderlineInfo guifg=NONE guibg=NONE gui=undercurl guisp=${color.accent} ctermfg=NONE ctermbg=NONE cterm=underline
    hi DiagnosticUnderlineHint guifg=NONE guibg=NONE gui=undercurl guisp=${color.text.soft} ctermfg=NONE ctermbg=NONE cterm=underline
  '';
in
{
  home.file.".vim/colors/${theme.name}.vim".text = colorscheme;

  programs.vim.extraConfig = lib.mkAfter ''
    colorscheme ${theme.name}
  '';
}
