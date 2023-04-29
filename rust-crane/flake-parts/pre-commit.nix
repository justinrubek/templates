{
  inputs,
  self,
  ...
}: {
  perSystem = {self', ...}: let
  in {
    pre-commit = {
      check.enable = true;

      settings = {
        src = ../.;
        hooks = {
          treefmt = {
            enable = true;
            name = "treefmt";
            description = "format the code";
            types = ["file"];
            pass_filenames = true;
            entry = "${self'.packages.treefmt}/bin/treefmt";
          };
        };
      };
    };
  };
}
