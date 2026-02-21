# Jailed Agents Repository

This repository contains the source code for the Jailed Agents project. It includes Nix Flake configurations and other scripts.

## Overview

- **flake.nix**: Nix flake definition.
- **flake.lock**: Lock file for reproducible builds.

## Agents

- opencode: launches the OpenCode agent inside a jailed sandbox with shared tooling, caching directories, and any `extraPkgs` you provide.
- crush: launches the Crush agent with the same sandbox defaults and optional `extraPkgs` support.

Both helpers extend the jail with a common toolkit (`bashInteractive`, `git`, `ripgrep`, etc.), mount the working directory, enable outbound networking, and pre-create writeable state in `~/.config`, `~/.local/share`, and (for OpenCode) `~/.local/state`.

## Using in NixOS systemPackages

Add the jailed agent wrapper returned by `jailed-agents.lib.${system}.*` to your flake's `environment.systemPackages`. You can pass more packages to the agent by setting `extraPkgs`:

```nix
environment.systemPackages = with pkgs; [
  udiskie
  brave
  (
    jailed-agents.lib.${system}.makeJailedOpencode {
      extraPkgs = with pkgs; [nilfs-utils];
    }
  )
];
```

Replace `nilfs-utils` with any additional dependencies your agent session needs. Use `makeJailedCrush { extraPkgs = [...] ; }` similarly if you prefer the Crush agent.

## Usage

To run a dev shell:

```bash
nix develop -c $SHELL
```
