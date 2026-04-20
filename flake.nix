{
  description = "flake for jailed agents";

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    jail-nix.url = "sourcehut:~alexdavid/jail.nix";
    flake-utils.url = "github:numtide/flake-utils";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs = {
    nixpkgs-unstable,
    nixpkgs,
    jail-nix,
    flake-utils,
    llm-agents,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
      };

      jail = jail-nix.lib.init pkgs;

      # Common packages available to agents
      commonPkgs = with pkgs; [
        bashInteractive
        curl
        wget
        jq
        git
        which
        ripgrep
        gnugrep
        gawkInteractive
        ps
        findutils
        gzip
        unzip
        gnutar
        diffutils
      ];

      # Common sandbox options shared by both agents
      commonJailOptions = with jail.combinators; [
        network
        time-zone
        no-new-session
        mount-cwd
      ];

      makeJailedOpencode = {extraPkgs ? []}:
        jail "opencode" pkgs-unstable.opencode (with jail.combinators; (
          commonJailOptions
          ++ [
            (try-readwrite (noescape "~/.config/opencode"))
            (try-readwrite (noescape "~/.local/share/opencode"))
            (try-readwrite (noescape "~/.local/state/opencode"))

            (add-pkg-deps commonPkgs)
            (add-pkg-deps extraPkgs)
          ]
        ));

      PI = llm-agents.packages.${system}.pi;

      makeJailedPI = {extraPkgs ? []}:
        jail "pi" PI (with jail.combinators; (
          commonJailOptions
          ++ [
            (try-readwrite (noescape "~/.pi"))
            (try-readonly (noescape "~/lisp-pi"))
            (add-pkg-deps commonPkgs)
            (add-pkg-deps [pkgs.sbcl])
            (add-pkg-deps extraPkgs)
          ]
        ));
    in {
      lib = {
        inherit makeJailedOpencode;
        inherit makeJailedPI;
      };

      devShells.default = pkgs.mkShell {
        name = "jailed agents";

        packages = [
          pkgs.zsh
          (makeJailedOpencode {})
          (makeJailedPI {})
        ];

        shellHook = ''
          echo welcome to jailed agents
        '';
      };
    });
}
