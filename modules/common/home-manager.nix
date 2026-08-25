{ inputs, ... }:
let
  theme = import ../../themes/solitude.nix;
in
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs theme; };
    users.saavy = import ../../home/saavy;
  };
}
