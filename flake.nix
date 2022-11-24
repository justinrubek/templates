{
  description = "nix project templates";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-parts,
    pre-commit-hooks,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit self;} {
      systems = ["x86_64-linux" "aarch64-linux"];
      imports = [];

      flake.templates = {
        rust-crane = {
          path = ./rust-crane;
          description = "rust using crane and fenix for building";
        };
        terranix-multi-config = {
          path = ./terranix-multi-config;
          description = "hybrid terranix/terraform. multiple distinct terraform configurations";
        };
      };

      perSystem = {
        pkgs,
        lib,
        system,
        inputs',
        ...
      }: {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.alejandra
          ];
          inherit (self.checks.${system}.pre-commit-hooks) shellHook;
        };

        checks.pre-commit-hooks = inputs.pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            alejandra.enable = true;
          };
        };
      };
    };
}
