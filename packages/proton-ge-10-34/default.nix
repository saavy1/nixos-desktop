{
  fetchzip,
  proton-ge-bin,
}:

proton-ge-bin.overrideAttrs
  (_: {
    steamDisplayName = "GE-Proton10-34";
    version = "GE-Proton10-34";
    # This release's internal tool name carries no -x86_64 suffix; without
    # this, preFixup's --replace-fail finds no match and the build fails.
    toolName = "GE-Proton10-34";
    src = fetchzip {
      url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-34/GE-Proton10-34.tar.gz";
      hash = "sha256-lzPsYYcrp5NoT3B0WFj3o10Z7tXx7xva1wEP3edeuqM=";
    };
  })
