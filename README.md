# helium-nix

Personal Nix packaging for Helium Browser, used with my `nixos-portable` configuration.

This repository is intentionally maintained for **personal use**. It is not intended to be a general-purpose Helium package, a distribution repository, or a promise of support for other systems.

## Purpose

`helium-nix` keeps the Helium binary packaging separate from `nixos-portable` while providing a small Nix interface for my machines:

- `x86_64-linux`
- `aarch64-linux`
- NixOS module
- Home Manager module
- optional overlay
- fixed upstream release artifacts and per-architecture hashes

The repository packages the upstream Helium binary; it does not contain the Helium browser source code.

## Usage with nixos-portable

`nixos-portable` consumes this repository as a flake input:

```nix
helium = {
  url = "github:projectofwang/helium-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

The Helium profile imports the NixOS module directly:

```nix
imports = [ inputs.helium.nixosModules.default ];

programs.helium.enable = true;
```

No overlay is required for the normal `nixos-portable` setup.

## Package-only usage

```nix
environment.systemPackages = [
  inputs.helium.packages.${pkgs.system}.helium
];
```

## Home Manager

```nix
imports = [ inputs.helium.homeModules.default ];
programs.helium.enable = true;
```

## Personal configuration

The actual machine-specific choices belong in `nixos-portable`, not here. For example, Wayland flags and browser policies are configured by the `helium` profile there.

This repository should remain focused on packaging and the reusable module interface.

## Updating Helium

Updates are intentionally conservative because this is a personal binary package.

1. Check the upstream Helium release.
2. Confirm the release and artifact names.
3. Confirm separate AMD64 and ARM64 artifacts.
4. Update `version` and the corresponding hashes in `package.nix`.
5. Run `nix flake check`.
6. Build the architecture being used before updating `nixos-portable`'s lockfile.

Do not use floating release URLs or `lib.fakeHash`.

## Security / trust model

The package uses Nix fixed-output hashes for artifact integrity and reproducibility. This does **not** prove that the upstream Helium binary is free of malware or other unwanted behavior.

The trust boundary is the upstream Helium release. Review upstream releases before changing the pinned version or hashes.

## Scope

This repository is intentionally small and opinionated for my own NixOS setup. Compatibility, APIs, module options, and update cadence may change when needed for `nixos-portable`.

If you use this repository outside that configuration, treat it as an example rather than a supported package source.
