{
  fetchzip,
  proton-ge-bin,
}:

(proton-ge-bin.override {
  steamDisplayName = "GE-Proton10-34";
}).overrideAttrs
  (_: {
    version = "GE-Proton10-34";

    src = fetchzip {
      url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-34/GE-Proton10-34.tar.gz";
      hash = "sha256-lzPsYYcrp5NoT3B0WFj3o10Z7tXx7xva1wEP3edeuqM=";
    };
  })
