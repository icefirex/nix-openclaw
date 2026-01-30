{
  description = "OpenClaw - AI assistant gateway for messaging platforms";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators }:
  let
    supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # Base VM modules (openclaw module + vm config)
    vmModules = [
      self.nixosModules.openclaw
      ./vm-config.nix
    ];
  in {
    # NixOS module - import this in your configuration
    nixosModules = {
      default = self.nixosModules.openclaw;
      openclaw = import ./module.nix;
    };

    # Standalone package
    packages = forAllSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = self.packages.${system}.openclaw;
        openclaw = pkgs.callPackage ./package.nix { };

        # VM Images via nixos-generators
        # Build with: nix build .#qcow (or iso, vmware, proxmox, virtualbox)

        # QCOW2 - For QEMU/KVM/Proxmox
        qcow = nixos-generators.nixosGenerate {
          inherit system;
          modules = vmModules;
          format = "qcow";
        };

        # ISO - Bootable installer
        iso = nixos-generators.nixosGenerate {
          inherit system;
          modules = vmModules;
          format = "iso";
        };

        # VMware
        vmware = nixos-generators.nixosGenerate {
          inherit system;
          modules = vmModules;
          format = "vmware";
        };

        # Proxmox VE (LXC container)
        proxmox-lxc = nixos-generators.nixosGenerate {
          inherit system;
          modules = vmModules;
          format = "proxmox-lxc";
        };

        # VirtualBox
        virtualbox = nixos-generators.nixosGenerate {
          inherit system;
          modules = vmModules;
          format = "virtualbox";
        };
      }
    );

    # Overlay for adding openclaw to pkgs
    overlays.default = final: prev: {
      openclaw = self.packages.${prev.system}.openclaw;
    };
  };
}
