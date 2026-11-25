{
  description = "hcx: resumable omp agents in herdr-core (hc), mirrored into Rex, on several Macs";

  # No inputs on purpose: the module builds with the consuming system's nixpkgs.
  outputs = { self }: {
    darwinModules.default = import ./nix/module.nix;
  };
}
