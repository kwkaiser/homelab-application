{
  description = "homelab-application dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      certbot-cloudflare = pkgs.certbot.withPlugins (cps: [cps.certbot-dns-cloudflare]);
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          go-task
          secretspec
          certbot-cloudflare
        ];
      };
    });
}
