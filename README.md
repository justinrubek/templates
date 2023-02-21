# nix flake templates

Templates for quickly starting a new project

Initialize in the current directory:
```
nix flake init --template github:justinrubek/templates#rust-crane
```

Or, create a new one
```
nix flake new --template github:justinrubek/templates#rust-crane ./rust-project
```
## rust

The `rust-crane` template is intended to initialize a new workspace.
It includes basic things needed to manage the new codebase: 
a simple rust application and a nix flake that supplies the development environment and builds the package.

The `rust-lib-crate` template is intended to be used in combination with `rust-crane`.
The workspace reads all crates from `./crates`, so if you initialize it in that directory it will be included:
`nix flake new --template justinrubek/templates#rust-lib-crate ./crates/your-lib`.
