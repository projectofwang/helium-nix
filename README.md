# helium-nix

Nix packaging for [Helium Browser](https://github.com/imputnet/helium-linux), with NixOS and Home Manager modules.

## Design

- Downloads only versioned upstream release artifacts from `imputnet/helium-linux`.
- Uses separate immutable SHA-256 hashes for `x86_64-linux` and `aarch64-linux`.
- Does not execute arbitrary network scripts during the build.
- Keeps the package as a binary-native-code derivation; this repository does not claim to audit the Helium binary itself for malware.

The upstream project publishes release artifacts and states that its AppImage, binary tarballs, and Debian repository are signed with its published PGP key. Release `0.17.0.1` is immutable and provides distinct AMD64 and ARM64 Debian artifacts.

## Flake outputs

- `packages.<system>.helium`
- `overlays.default`
- `nixosModules.default`
- `homeModules.default`

Supported systems:

- `x86_64-linux`
- `aarch64-linux`

## NixOS

```nix
inputs.helium.url = "github:projectofwang/helium-nix";

# In your system module:
imports = [ inputs.helium.nixosModules.default ];

programs.helium.enable = true;
```

Optional policies:

```nix
programs.helium.policies = {
  BrowserSignin = 0;
};
```

## Home Manager

```nix
imports = [ inputs.helium.homeModules.default ];
programs.helium.enable = true;
```

## Package only

```nix
environment.systemPackages = [
  inputs.helium.packages.${pkgs.system}.helium
];
```

## Security model

The important trust boundary is the upstream Helium binary. Nix fixed-output hashes provide artifact integrity/reproducibility after a hash has been reviewed; they do not prove that the upstream binary is benign.

For updates, review the upstream release, asset name, architecture, digest, and source changes before changing `package.nix`. Do not replace the fixed hashes with `lib.fakeHash` or floating URLs.

## Version updates

When updating Helium:

1. Confirm the upstream release tag.
2. Confirm the release is immutable.
3. Confirm both Debian assets exist.
4. Record the AMD64 and ARM64 SHA-256 digests independently.
5. Update `version` and both hashes in `package.nix`.
6. Run `nix flake check` and build the package on the target architecture(s).

## Relation to nixos-portable

Use this repository as a dedicated flake input in `nixos-portable`, instead of embedding the Helium package implementation there. This keeps the browser packaging lifecycle independent from the OS framework.
