{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Jayson Saavedra";
        email = "31431014+saavy1@users.noreply.github.com";
      };
      init.defaultBranch = "main";
      push = {
        autoSetupRemote = true;
        default = "current";
      };
    };
  };

  programs.gh = {
    enable = true;
    settings.git_protocol = "https";
  };
}
