{ inputs, lib, ... }:
let
  theme = import ../../themes { inherit lib; };
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
