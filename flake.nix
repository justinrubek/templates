{
  description = "nix project templates";

  inputs = {};

  outputs = {
    self
  }: {
    templates = {
      rust-crane = {
        path = ./rust-crane;
        description = "rust using crane and fenix for building";
      };
    };
  };
}
