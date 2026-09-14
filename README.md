# helium-nix

Đóng gói **Helium Browser** bằng Nix, dành riêng cho cấu hình NixOS cá nhân của tôi.

Repository này không phải package Helium tổng quát hay dự án có compatibility/support contract. Nó tồn tại chủ yếu để tách binary packaging của Helium khỏi `nixos-portable`.

## Phạm vi

Repository cung cấp:

- package `helium` cho `x86_64-linux` và `aarch64-linux`;
- NixOS module;
- Home Manager module;
- overlay tùy chọn;
- fixed-output hash riêng cho từng artifact upstream.

Repository **không chứa source code Helium**. Package lấy binary `.deb` từ release upstream và đóng gói lại cho môi trường Nix.

## Dùng với nixos-portable

`nixos-portable` dùng repository này làm flake input:

```nix
helium = {
  url = "github:projectofwang/helium-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Profile Helium dùng NixOS module trực tiếp:

```nix
imports = [ inputs.helium.nixosModules.default ];

programs.helium.enable = true;
```

Cấu hình machine-specific như Wayland flags và browser policies nằm ở `nixos-portable`, không nằm trong package repository này.

## Chỉ dùng package

```nix
environment.systemPackages = [
  inputs.helium.packages.${pkgs.system}.helium
];
```

Hoặc dùng package mặc định của flake:

```bash
nix build .#helium
```

## Home Manager

```nix
imports = [ inputs.helium.homeModules.default ];
programs.helium.enable = true;
```

## Package layout

`package.nix` hiện:

1. tải artifact `.deb` theo architecture;
2. kiểm tra fixed-output hash của artifact;
3. giải nén bằng `ar`/`tar`;
4. đưa Helium vào `/opt/helium`;
5. patch interpreter và RPATH bằng `patchelf`;
6. tạo launcher tại `$out/bin/helium`;
7. sửa desktop entry và icon;
8. thêm runtime library path, ALSA plugin path, fontconfig và các flags được cấu hình.

Package hiện dùng version `0.17.0.1`, với hash độc lập cho AMD64 và ARM64. fileciteturn95file0L2-L2

## Module

NixOS module cung cấp:

```nix
programs.helium.enable = true;
programs.helium.package = ...;
programs.helium.flags = [ ... ];
programs.helium.policies = { ... };
```

Module không yêu cầu overlay để hoạt động; package được tạo trực tiếp từ `package.nix`. fileciteturn96file0L2-L2

Home Manager cung cấp cùng interface cơ bản và cài package vào `home.packages`. fileciteturn97file0L2-L2

## Cập nhật Helium

Đây là binary package cá nhân nên update phải có kiểm soát:

1. kiểm tra release upstream;
2. xác nhận version và tên artifact;
3. xác nhận artifact AMD64 và ARM64 riêng biệt;
4. cập nhật version + hash tương ứng trong `package.nix`;
5. chạy `nix flake check`;
6. build architecture đang sử dụng;
7. sau đó mới cập nhật lockfile của `nixos-portable`.

Không dùng release URL trôi nổi và không dùng `lib.fakeHash` trong commit cuối.



## Flake

Flake chỉ dùng `nixpkgs` làm input và expose package, overlay, NixOS module, Home Manager module, checks và formatter cho hai architecture. fileciteturn94file0L2-L2

`flake.lock` của repository này pin `nixpkgs` độc lập với lockfile của `nixos-portable`, nhưng hai repository hiện được cấu hình để follow cùng `nixpkgs` revision khi được dùng làm input. fileciteturn116file0L2-L2

## Phạm vi sử dụng

Repository này public để version control và truy cập thuận tiện, nhưng mục tiêu thiết kế là **chỉ phục vụ `nixos-portable` và các máy cá nhân của tôi**.

Không có cam kết về API ổn định, compatibility với hệ thống khác, backward compatibility hoặc release cadence. Module options và packaging implementation có thể thay đổi nếu cấu hình cá nhân cần thay đổi.
