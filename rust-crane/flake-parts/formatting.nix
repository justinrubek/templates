{
  inputs,
  self,
  ...
}: {
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    formatters = [
      pkgs.alejandra
      pkgs.rustfmt
    ];

    # wrap treefmt to provide the correct PATH with all formatters
    treefmt = pkgs.stdenv.mkDerivation {
      name = "treefmt";
      buildInputs = [pkgs.makeWrapper];
      buildCommand = ''
        makeWrapper \
          ${pkgs.treefmt}/bin/treefmt \
          $out/bin/treefmt \
          --prefix PATH : ${lib.makeBinPath formatters}
      '';
    };
  in {
    packages = {
      inherit treefmt;
    };

    legacyPackages = {
      inherit formatters;
    };
  };
}
