# helium-nix

Nix package và modules để tích hợp **Helium Browser** vào NixOS/Home Manager, được duy trì **chủ yếu cho cấu hình NixOS cá nhân của tôi**.

Repository này public để version control, backup và thuận tiện sử dụng giữa các máy tôi trực tiếp quản lý. Nó không phải package Helium tổng quát, không phải distribution và không có compatibility/support contract cho hệ thống khác.

## Mục đích

`helium-nix` tách binary packaging của Helium khỏi system configuration trong `nixos-portable`.

Nó chịu trách nhiệm:

- đóng gói official Helium Linux AMD64 release thành Nix package;
- cung cấp NixOS module;
- cung cấp Home Manager module;
- cung cấp overlay;
- kiểm tra package và module bằng Nix flake checks;
- tự động theo dõi upstream release.

Ranh giới thiết kế:

```text
upstream Helium Linux
        │
        │ official AMD64 .deb
        ▼
   helium-nix
        │
        ├── package
        ├── NixOS module
        ├── Home Manager module
        └── overlay
        │
        ▼
   nixos-portable
```

`helium-nix` **không chứa source code của Helium**. Package lấy artifact `.deb` từ release chính thức của `imputnet/helium-linux` và đóng gói lại cho môi trường Nix.

## Architecture policy

Repository **chỉ hỗ trợ `x86_64-linux`**.

```text
Supported:
  x86_64-linux

Out of scope:
  i686 / 32-bit
  aarch64 / ARM
  mọi architecture khác
```

Đây là policy có chủ đích. Package không giả lập support cho architecture mà upstream không cung cấp artifact tương ứng.

## Package

Package mặc định được expose bởi flake:

```bash
nix build .#helium
```

Hoặc dùng package trong một NixOS configuration:

```nix
environment.systemPackages = [
  inputs.helium.packages.${pkgs.system}.helium
];
```

Package hiện thực hiện các bước chính:

1. tải fixed-output AMD64 `.deb` từ release upstream;
2. kiểm tra hash của artifact;
3. giải nén Debian archive;
4. cài Helium vào `/opt/helium`;
5. patch interpreter và RPATH bằng `patchelf`;
6. tạo launcher `$out/bin/helium`;
7. điều chỉnh desktop entry và icon;
8. cung cấp runtime library paths, ALSA plugin path, fontconfig và flags cần thiết.

Packaging tập trung vào việc tạo một runtime closure Nix ổn định cho binary upstream, thay vì biên dịch lại source Helium.

## NixOS module

Module cung cấp interface:

```nix
programs.helium.enable = true;
programs.helium.package = ...;
programs.helium.flags = [ ... ];
programs.helium.policies = { ... };
```

Import module:

```nix
imports = [ inputs.helium.nixosModules.default ];

programs.helium.enable = true;
```

NixOS module cài package, tạo launcher với flags và ghi system-level managed policies khi được cấu hình.

Managed policy trên NixOS được ghi vào các đường dẫn Chromium/Helium Linux tương ứng. Đây là system-level configuration và khác với user-level policy của Home Manager.

## Home Manager module

```nix
imports = [ inputs.helium.homeModules.default ];

programs.helium.enable = true;
```

Home Manager cài package vào user environment và hỗ trợ flags/policies ở user scope.

User-level policy **không được coi là equivalent với system managed policy** cho các policy cần enforcement ở cấp hệ thống.

## Overlay

Flake cũng expose overlay để sử dụng package theo cơ chế overlay của Nix:

```nix
overlays.default
```

Overlay chỉ là convenience layer; NixOS/Home Manager modules không yêu cầu overlay để hoạt động.

## Flake architecture

```text
flake.nix
│
├── nixpkgs
├── home-manager
│
├── packages.x86_64-linux
│    └── helium
│
├── overlays.default
│
├── nixosModules.default
│
├── homeModules.default
│
├── checks.x86_64-linux
│    ├── package
│    ├── runtime smoke
│    ├── NixOS module
│    ├── Home Manager module
│    └── custom-package variants
│
└── formatter.x86_64-linux
```

`home-manager` được cấu hình để follow cùng `nixpkgs` trong flake. Khi `helium-nix` được dùng từ `nixos-portable`, input `nixpkgs` của nó cũng follow parent `nixpkgs`.

## Automatic upstream tracking

Mục tiêu của repository là **Helium package luôn bám theo release Linux mới nhất của upstream** mà không cần sửa version/hash thủ công.

Workflow `.github/workflows/update-helium.yml` chạy định kỳ và cũng hỗ trợ manual dispatch.

Khi upstream phát hành version mới, workflow:

1. đọc release mới nhất của `imputnet/helium-linux` qua GitHub API;
2. xác nhận version theo format release hợp lệ;
3. tải đúng artifact chính thức `helium-bin_<version>-1_amd64.deb`;
4. tính SHA-256 SRI hash bằng Nix;
5. cập nhật `version` và `hash` trong `package.nix`;
6. tạo branch update;
7. mở pull request;
8. để CI kiểm tra package, runtime smoke test và modules trước khi merge.

Flow:

```text
upstream release
      │
      ▼
 daily/manual updater
      │
      ▼
 official AMD64 artifact
      │
      ▼
 Nix SHA-256 SRI hash
      │
      ▼
 package.nix update
      │
      ▼
 pull request
      │
      ▼
 CI validation
      │
      ▼
 merge
```

Workflow **không tự động merge release vào `main`**. Đây là intentional safety gate: upstream release mới phải vượt qua CI trước khi trở thành revision chính thức của repository.

Không dùng floating release URL và không dùng `lib.fakeHash` trong package cuối cùng.

## Version policy

Version trong `package.nix` phải tương ứng với release mới nhất mà updater đã chọn từ upstream và artifact AMD64 tương ứng.

Nếu cần cập nhật thủ công, nguyên tắc vẫn là tải artifact chính thức, tính hash bằng Nix và commit version/hash thực tế; không đoán hash.

## Dùng với nixos-portable

`nixos-portable` dùng repository này làm flake input:

```nix
helium = {
  url = "github:projectofwang/helium-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Profile `helium` trong parent repository import module trực tiếp. Các cấu hình machine-specific như Wayland flags và browser policy nằm ở `nixos-portable`; package repository giữ phần packaging/module generic nhất có thể.

Sau khi `helium-nix` có revision mới, parent repository phải refresh lockfile để consume revision đó:

```bash
nix flake lock --update-input helium
nix flake check
```

## CI và validation

GitHub Actions chạy:

```bash
nix flake check --system x86_64-linux --no-write-lock-file
```

Các checks bao gồm package evaluation/build, runtime smoke test và các NixOS/Home Manager module variants.

Workflow sử dụng permissions giới hạn, checkout không giữ credentials và các third-party Actions quan trọng được pin bằng commit SHA.

## Development

Kiểm tra repository local:

```bash
nix flake check --system x86_64-linux --no-write-lock-file
nix build .#helium
```

Khi thay đổi package hoặc module, nên kiểm tra cả runtime smoke test và module checks trước khi merge.

## Personal-use scope

Đây là **project cá nhân**. Mục tiêu thực tế là phục vụ `nixos-portable` và các máy tôi trực tiếp quản lý.

Không có cam kết về:

- compatibility với architecture/platform khác;
- backward compatibility của module options;
- API stability;
- release cadence độc lập;
- SLA hoặc support;
- khả năng dùng nguyên trạng bởi người khác.

Implementation có thể thay đổi bất cứ lúc nào nếu cần để phục vụ cấu hình cá nhân tốt hơn.

## License và upstream software

`helium-nix` là lớp packaging/integration cho phần mềm upstream. Helium và các thành phần bên thứ ba vẫn chịu license riêng của chúng. Repository này không tuyên bố sở hữu source code hoặc license của phần mềm upstream chỉ vì nó được đóng gói làm Nix dependency.

Việc sử dụng repository cho mục đích cá nhân không thay đổi license của phần mềm upstream; các nghĩa vụ phân phối, nếu có, được xác định bởi license tương ứng khi phần mềm được redistributе.

## Design principles

- **Personal first** — tối ưu cho nhu cầu thực tế của chủ repository.
- **Upstream aligned** — version phải bám release Linux chính thức.
- **Reproducible** — artifact có fixed hash.
- **No fake hash** — không commit `fakeHash`.
- **No floating binaries** — không tải release bằng URL không cố định.
- **CI before merge** — release update phải qua validation.
- **x86_64 only** — không giả lập support cho platform ngoài phạm vi.
- **Clear boundary** — package repository xử lý packaging; machine-specific policy nằm ở `nixos-portable`.
