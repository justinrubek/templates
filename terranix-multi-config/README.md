# terranix configuration

This contains multiple terraform configurations and a small shell script which is used to run terraform commands against them.

- each configuration is placed in `./terraform/configurations/${configurationName}`
    - currently the configuration name must be added to `./flake-parts/default.nix` in `terraformConfigurationNames`
    - a configuration should contain a `terraform.nix` file, which will be included as a [terranix](https://terranix.org/) module
    - the configuration's JSON is exposed via a package e.g. `nix build .#terraformConfigurations_core`
- the nix devShell exposes a command, `tnix`
    - this builds the terranix configuration as JSON and symlinks it inside the configuration directory before running the requested terraform command
    - the first argument is used to determine which directory to use
        - e.g. `tnix core init`, `tnix core plan`, `tnix ${configurationName} ${terraformArgs}`
    - all other arguments are opaquely passed to terraform
