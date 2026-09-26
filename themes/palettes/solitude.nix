# Ink & Paper: sampled from the Solitude screenprints. Teal-black ink, cream
# paper, lichen in between, rust as the only hot color.
let
  ink0 = "#0d1213";
  ink1 = "#131a1c";
  ink2 = "#1a2224";
  ink3 = "#263031";
  ink4 = "#2e3a3b";
  slate = "#3a4443";
  moss = "#58615b";
  stone = "#7e867b";
  lichen = "#a1a495";
  paper = "#d0c4a8";
  rust = "#d9623f";
  ochre = "#d0b98a";
  sage = "#9aa58c";
  # Text tones: stone/lichen/moss lifted to stay readable (>= 4.5:1 for
  # faint) even when a panel sits over a white window.
  mist = "#b3b6aa";
  pebble = "#90978d";
  ash = "#6c7770";
in
{
  name = "solitude";
  polarity = "dark";

  color = {
    surface = {
      deep = ink0;
      sunk = ink1;
      base = ink2;
      raised = ink3;
      hover = ink4;
    };
    text = {
      base = paper;
      soft = mist;
      faint = pebble;
      disabled = ash;
    };
    # `line` is tinted with alpha.line / alpha.lineStrong for hairlines;
    # `lineSolid` is for places that cannot do alpha.
    line = paper;
    lineSolid = slate;
    accent = paper;
    accentText = ink2;
    secondary = lichen;
    danger = rust;
    warning = ochre;
    success = sage;
  };

  terminal = [
    ink2
    "#c8674f"
    sage
    ochre
    "#7f98a0"
    "#a78d95"
    "#8fa9a3"
    paper
    moss
    rust
    "#b3bd9f"
    "#e3cf9f"
    "#9ab3ba"
    "#c0a5ad"
    "#a9c2bb"
    "#e6dcc4"
  ];

  icons.name = "Yaru-sage-dark";

  wallpaper = {
    path = ../assets/solitude/1-on-pole.jpg;
    paths = [
      ../assets/solitude/1-on-pole.jpg
      ../assets/solitude/2-wreckage.jpg
      ../assets/solitude/3-climb.jpg
      ../assets/solitude/4-ether.jpg
      ../assets/solitude/5-eyed.jpg
    ];
  };
}
