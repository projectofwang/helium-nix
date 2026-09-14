# Helium Nix Hardening Roadmap

This repository is part of the shared `nixos-portable` hardening plan tracked in `projectofwang/nixos-portable#3`.

## Workstreams

- **Packaging:** fixed-source binary provenance, architecture support, ELF/runtime dependencies.
- **Module API:** NixOS/Home Manager package, flags, and policy semantics.
- **QA:** package/module evaluation and runtime smoke tests.
- **Integration:** compatibility with the parent `nixos-portable` flake.
- **Documentation:** keep behavior and operational constraints explicit.

## Current target

- x86_64-linux and aarch64-linux are first-class supported systems.
- `programs.helium.package` accepts arbitrary package values without requiring a package-specific `flags` override.
- `programs.helium.flags` is applied by a lightweight wrapper.
- Policy values are restricted to JSON-compatible Nix values.
- NixOS and Home Manager modules are evaluated in CI.
- `helium --version` is exercised as a runtime smoke test.
- Fixed upstream release hashes remain mandatory.

## Deferred until evidence exists

Runtime dependency reduction is intentionally conservative. Libraries are not removed merely because they look redundant; changes require ELF/runtime evidence and a passing smoke test.
