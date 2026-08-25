{
  programs.vim = {
    enable = true;
    defaultEditor = true;
    settings = {
      background = "dark";
      copyindent = true;
      expandtab = true;
      hidden = true;
      history = 1000;
      ignorecase = true;
      mouse = "a";
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      smartcase = true;
      tabstop = 2;
    };
    extraConfig = ''
      filetype plugin indent on
      syntax enable
      set incsearch
      set splitbelow
      set splitright
      set wildmenu
    '';
  };
}
