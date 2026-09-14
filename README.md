# helium-nix

Đóng gói Helium Browser bằng Nix cho mục đích **sử dụng cá nhân**, được dùng cùng cấu hình `nixos-portable` của tôi.

Repository này được duy trì dành riêng cho **personal use**. Đây không phải package Helium tổng quát, kho phân phối, hay dự án có cam kết hỗ trợ cho các hệ thống khác.

## Mục đích

`helium-nix` tách phần đóng gói Helium khỏi `nixos-portable`, đồng thời cung cấp giao diện Nix nhỏ gọn cho các máy của tôi:

- `x86_64-linux`
- `aarch64-linux`
- NixOS module
- Home Manager module
- overlay tùy chọn
- artifact upstream được cố định bằng version và hash riêng cho từng kiến trúc

Repository này đóng gói binary Helium từ upstream; không chứa source code của Helium Browser.

## Sử dụng với nixos-portable

`nixos-portable` sử dụng repository này làm flake input:

```nix
helium = {
  url = "github:projectofwang/helium-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Profile Helium import NixOS module trực tiếp:

```nix
imports = [ inputs.helium.nixosModules.default ];

programs.helium.enable = true;
```

Cấu hình `nixos-portable` thông thường không cần overlay.

## Chỉ sử dụng package

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

## Phân tách cấu hình cá nhân

Các lựa chọn phụ thuộc vào từng máy thuộc về `nixos-portable`, không thuộc repository này. Ví dụ, Wayland flags và browser policies được cấu hình trong profile `helium` của `nixos-portable`.

Repository này nên giữ phạm vi tập trung vào:

- đóng gói Helium;
- NixOS module;
- Home Manager module;
- giao diện package/overlay cần thiết cho cấu hình cá nhân.

## Cập nhật Helium

Việc cập nhật được thực hiện thận trọng vì đây là binary package phục vụ cấu hình cá nhân.

1. Kiểm tra release Helium upstream.
2. Xác nhận release và tên artifact.
3. Xác nhận artifact AMD64 và ARM64 riêng biệt.
4. Cập nhật `version` và hash tương ứng trong `package.nix`.
5. Chạy `nix flake check`.
6. Build kiến trúc đang sử dụng trước khi cập nhật lockfile của `nixos-portable`.

Không sử dụng release URL trôi nổi hoặc `lib.fakeHash`.

## Bảo mật và mô hình tin cậy

Package sử dụng fixed-output hash của Nix để đảm bảo tính toàn vẹn và khả năng tái lập của artifact. Điều này **không chứng minh** binary Helium upstream không chứa malware hoặc hành vi không mong muốn.

Điểm tin cậy nằm ở release Helium upstream. Trước khi thay đổi version hoặc hash, cần xem xét release upstream tương ứng.

## Phạm vi

Repository này nhỏ và mang tính cá nhân, được thiết kế theo nhu cầu của cấu hình NixOS của tôi. Compatibility, API, module options và chu kỳ cập nhật có thể thay đổi bất cứ lúc nào để phục vụ `nixos-portable`.

Nếu sử dụng repository này ngoài cấu hình đó, hãy xem nó như một ví dụ hoặc package cá nhân, không phải nguồn package được hỗ trợ chính thức.
