{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    jail-nix.url = "sourcehut:~alexdavid/jail.nix";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    jail-nix,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      jail = jail-nix.lib.init pkgs;

      # I'm using crush and opencode, but you could swap in others.
      crush-pkg = pkgs.${system}.crush;
      opencode-pkg = pkgs.${system}.opencode;

      # Common packages available to both agents
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
        jail "jailed-crush" crush-pkg (with jail.combinators; (
          commonJailOptions
          ++ [
            # Give it a safe spot for its own config and cache.
            # This also lets it remember things between sessions.
            (readwrite (noescape "~/.config/crush"))
            (readwrite (noescape "~/.local/share/crush"))

            (add-pkg-deps commonPkgs)
            (add-pkg-deps extraPkgs)
          ]
        ));

      makeJailedOpencode = {extraPkgs ? []}:
        jail "jailed-opencode" opencode-pkg (with jail.combinators; (
          commonJailOptions
          ++ [
            # Give it a safe spot for its own config and cache.
            # This also lets it remember things between sessions.
            (readwrite (noescape "~/.config/opencode"))
            (readwrite (noescape "~/.local/share/opencode"))
            (readwrite (noescape "~/.local/state/opencode"))

            (add-pkg-deps commonPkgs)
            (add-pkg-deps extraPkgs)
          ]
        ));
    in {
      lib = {
        inherit makeJailedCrush;
        inherit makeJailedOpencode;
      };

      # --- 3. Putting It All Together in the Dev Shell ---
      devShells.default = pkgs.mkShell {
        packages = [
          (makeJailedCrush {})
          (makeJailedOpencode {})
        ];
      };
    });
}
