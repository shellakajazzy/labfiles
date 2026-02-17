# ~/~ begin <<README.md#flake.nix>>[init]
{
  description = "Flake containing the configuration for Jason G's homelab network and server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # ~/~ begin <<README.md#flake-inputs>>[init]
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ~/~ end
  };

  outputs = { self, nixpkgs, ... } @ inputs: let
    # ~/~ begin <<README.md#flake-declarations>>[init]
    nixpkgSetup = {
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      nix.settings.trusted-users = [ "@wheel" "root" ];
      nixpkgs.config.allowUnfree = true;
      system.stateVersion = "25.11";
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[1]
    localizationSetup = {
      time.timeZone = "America/Los_Angeles";
      i18n = {
        defaultLocale = "en_US.UTF-8";
        extraLocaleSettings = {
          LC_ADDRESS = "en_US.UTF-8";
          LC_IDENTIFICATION = "en_US.UTF-8";
          LC_MEASUREMENT = "en_US.UTF-8";
          LC_MONETARY = "en_US.UTF-8";
          LC_NAME = "en_US.UTF-8";
          LC_NUMERIC = "en_US.UTF-8";
          LC_PAPER = "en_US.UTF-8";
          LC_TELEPHONE = "en_US.UTF-8";
          LC_TIME = "en_US.UTF-8";
        };
      };
      services.xserver.xkb = {
        layout = "us";
        variant = "";
      };
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[2]
    bootloaderSetup = {
      boot.loader.grub.enable = true;
      boot.loader.grub.devices = [ "nodev" ];
      boot.growPartition = true;
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[3]
    userSetup = hostname: {
      users.mutableUsers = false;
      users.users = {
        root = {
          hashedPassword = "!";
        };
    
        "${hostname}" = {
          isNormalUser = true;
          home = "/home/${hostname}";
          description = "${hostname}";
          group = "users";
          extraGroups = [ "wheel" ];
          password = "password123";
        };
      };
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[4]
    networkingSetup = hostname: {
      networking.networkmanager.enable = true;
      networking.hostName = "${hostname}";
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[5]
    raidDiskSetup = deviceName: {
      device = "${deviceName}";
      type = "disk";
      content = {
        type = "gpt";
        partitions.mdadm = {
          size = "100%";
          content = {
            type = "mdraid";
            name = "raid5";
          };
        };
      };
    };
    # ~/~ end
  in {
    # ~/~ begin <<README.md#nixos-host-declaration>>[init]
    nixosConfigurations.nixoshost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";  
      modules = [
        # ~/~ begin <<README.md#nixos-host-modules>>[init]
        inputs.disko.nixosModules.disko
        # ~/~ end
    
        nixpkgSetup
        localizationSetup
        (userSetup "nixoshost")
        (networkingSetup "nixoshost")
    
        ./hardware-configuration.nix
        {
          # ~/~ begin <<README.md#nixos-host-config>>[init]
          disko.devices = {
            disk = {
              main = {
                device = "/dev/sda";
                type = "disk";
                content = {
                  type = "gpt";
                  partitions = {
                    ESP = {
                      type = "EF00";
                      size = "500M";
                      content = {
                        type = "filesystem";
                        format = "vfat";
                        mountpoint = "/boot";
                        mountOptions = [ "umask=0077" ];
                      };
                    };
                    root = {
                      size = "100%";
                      content = {
                        type = "filesystem";
                        format = "ext4";
                        mountpoint = "/";
                      };
                    };
                  };
                };
              };
          
              one = raidDiskSetup "/dev/sdc";
              two = raidDiskSetup "/dev/sdd";
              three = raidDiskSetup "/dev/sde";
              four = raidDiskSetup "/dev/sdf";
              five = raidDiskSetup "/dev/sdg";
              six = raidDiskSetup "/dev/sdh";
              seven = raidDiskSetup "/dev/sdi";
              eight = raidDiskSetup "/dev/sdj";
            };
            mdadm = {
              raid5 = {
                type = "mdadm";
                level = 5;
                content = {
                  type = "gpt";
                  partitions = {
                    primary = {
                      size = "100%";
                      content = {
                        type = "filesystem";
                        format = "ext4";
                        mountpoint = "/mnt/raid";
                      };
                    };
                  };
                };
                extraArgs = [ "--assume-clean" ];
              };
            };
          };
          # ~/~ end
          # ~/~ begin <<README.md#nixos-host-config>>[1]
          boot.loader.grub = {
            device = "nodev";
            efiSupport = true;
            efiInstallAsRemovable = true;
          };
          # ~/~ end
        }
      ];
    };
    # ~/~ end
  };
}
# ~/~ end
