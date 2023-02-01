{
  inputs,
  self,
  ...
} @ part-inputs: {
  imports = [];

  perSystem = {
    pkgs,
    lib,
    system,
    inputs',
    ...
  }: let
    devTools = [
      # rust tooling
      fenix-toolchain
      pkgs.bacon
      # version control
      pkgs.cocogitto
      inputs'.bomper.packages.cli
      # misc
    ];

    extraBuildInputs = [
      pkgs.pkg-config
    ];
    extraNativeBuildInputs = [
    ];

    allBuildInputs = base: base ++ extraBuildInputs;
    allNativeBuildInputs = base: base ++ extraNativeBuildInputs;

    fenix-channel = inputs'.fenix.packages.latest;
    fenix-toolchain = fenix-channel.withComponents [
      "rustc"
      "cargo"
      "clippy"
      "rust-analysis"
      "rust-src"
      "rustfmt"
      "llvm-tools-preview"
    ];

    craneLib = inputs.crane.lib.${system}.overrideToolchain fenix-toolchain;

    common-build-args = rec {
      src = inputs.nix-filter.lib {
        root = ../.;
        include = [
          "crates"
          "Cargo.toml"
          "Cargo.lock"
        ];
      };

      # TODO: change the name to reflect the project
      pname = "rust-crane";

      buildInputs = allBuildInputs [];
      nativeBuildInputs = allNativeBuildInputs [];
      LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath buildInputs;
    };
    deps-only = craneLib.buildDepsOnly ({} // common-build-args);

    checks = {
      clippy = craneLib.cargoClippy ({
          cargoArtifacts = deps-only;
          cargoClippyExtraArgs = "--all-features -- --deny warnings";
        }
        // common-build-args);

      rust-fmt = craneLib.cargoFmt ({
          inherit (common-build-args) src;
        }
        // common-build-args);

      rust-tests = craneLib.cargoNextest ({
          cargoArtifacts = deps-only;
          partitions = 1;
          partitionType = "count";
        }
        // common-build-args);

      pre-commit-hooks = inputs.pre-commit-hooks.lib.${system}.run {
        inherit (common-build-args) src;
        hooks = {
          alejandra.enable = true;
          rustfmt.enable = true;
        };
      };
    };

    cli-package = craneLib.buildPackage ({
        pname = "cli";
        cargoArtifacts = deps-only;
        cargoExtraArgs = "--bin cli";
      }
      // common-build-args);
  in rec {
    devShells.default = pkgs.mkShell rec {
      packages = allBuildInputs (allNativeBuildInputs devTools);
      LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath packages;
      inherit (self.checks.${system}.pre-commit-hooks) shellHook;
    };

    packages = {
      default = packages.cli;
      cli = cli-package;
      rust-toolchain = fenix-toolchain;
    };

    apps = {
      cli = {
        type = "app";
        program = "${self.packages.${system}.cli}/bin/cli";
      };
      default = apps.cli;
    };

    inherit checks;
  };
}
