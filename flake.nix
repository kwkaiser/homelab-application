{
  description = "homelab-application dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # certbot-dns-cloudflare is marked broken as of nixos-unstable/25.05
    # (see certbot/certbot#10182) but still builds fine on 24.11 - pin just
    # that package to the last known-good revision instead of pinning the
    # whole devshell to it.
    nixpkgs-certbot.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-certbot,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      pkgs-certbot = import nixpkgs-certbot {inherit system;};
      certbot-cloudflare = pkgs-certbot.certbot.withPlugins (cps: [cps.certbot-dns-cloudflare]);
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          go-task
          secretspec
          certbot-cloudflare
          yq-go
        ];
      };
    });
}
