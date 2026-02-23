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

      # --- 2. The Sandboxes ---
      makeJailedCrush = {extraPkgs ? []}:
        jail "crush" pkgs.crush (with jail.combinators; (
          commonJailOptions
          ++ [
            # Give it a safe spot for its own config and cache.
            # This also lets it remember things between sessions.
            (try-readwrite (noescape "~/.local/share/crush"))
            (try-readwrite (noescape "~/.config/crush"))

            (add-pkg-deps commonPkgs)
            (add-pkg-deps extraPkgs)
          ]
        ));

      makeJailedOpencode = {extraPkgs ? []}:
        jail "opencode" pkgs-unstable.opencode (with jail.combinators; (
          commonJailOptions
          ++ [
            # Give it a safe spot for its own config and cache.
            # This also lets it remember things between sessions.
            (try-readwrite (noescape "~/.config/opencode"))
            (try-readwrite (noescape "~/.local/share/opencode"))
            (try-readwrite (noescape "~/.local/state/opencode"))

            (add-pkg-deps commonPkgs)
            (add-pkg-deps extraPkgs)
          ]
        ));

      makeJailedLetta = {extraPkgs ? []}:
        jail "letta" llm-agents.packages.${system}.letta-code (with jail.combinators; (
          commonJailOptions
          ++ [
            # Give it a safe spot for its own config and cache.
            # This also lets it remember things between sessions.
            gui # for opening ade browser
            (try-readwrite (noescape "~/.letta"))
            (add-pkg-deps commonPkgs)
            (add-pkg-deps extraPkgs)
          ]
        ));

      makeJailedForge = {extraPkgs ? []}:
        jail "forge" llm-agents.packages.${system}.forge (with jail.combinators; (
          commonJailOptions
          ++ [
            # Give it a safe spot for its own config and cache.
            # This also lets it remember things between sessions.
            gui # for opening ade browser
            (try-readwrite (noescape "~/.forge"))
            (add-pkg-deps commonPkgs)
            (add-pkg-deps extraPkgs)
          ]
        ));
    in {
      lib = {
        inherit makeJailedCrush;
        inherit makeJailedOpencode;
      };

      devShells.default = pkgs.mkShell {
        name = "jailed agents";

        packages = [
          pkgs.zsh
          (makeJailedCrush {})
          (makeJailedOpencode {})
          (makeJailedLetta {})
          (makeJailedForge {})
        ];

        shellHook = ''
          echo welcome to jailed agents
        '';
      };
    });
}
