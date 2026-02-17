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
    # ~/~ begin <<README.md#flake-inputs>>[1]
    sops-nix.url = "github:Mic92/sops-nix";
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
    sshSetup = {
      services.openssh = {
        enable = true;
        ports = [ 22 ];
        settings = {
          PermitRootLogin = "no";
          PubkeyAuthentication = true;
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[4]
    userSetup = hostname: {
      users.mutableUsers = true;
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
          initialPassword = "5Mez8Gia";
          openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKEmnK6phRQrpbHncPDo83riVYs8b6GzpdF3c6znIb0t homelab" ];
        };
      };
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[5]
    tailscaleSetup = authKeyPath: let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in {
      environment.systemPackages = [ pkgs.tailscale pkgs.jq ];
    
      services.tailscale.enable = true;
      systemd.services.tailscaleAutoconnect = {
        description = "Autoconnect to tailscale";
        after = [ "network-pre.target" "tailscale.service" ];
        wants = [ "network-pre.target" "tailscale.service" ];
        wantedBy = [ "multi-user.target" ];
    
        script = ''
          sleep 2
    
          status="$(${pkgs.tailscale}/bin/tailscale status -json | ${pkgs.jq}/bin/jq -r .BackendState)"
          if [ $status = "Running" ]; then exit 0; fi
          ${pkgs.tailscale}/bin/tailscale up -authkey $(cat ${authKeyPath})
        '';
      };
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[6]
    networkingSetup = hostname: {
      networking.networkmanager.enable = true;
      networking.hostName = "${hostname}";
    };
    # ~/~ end
    # ~/~ begin <<README.md#flake-declarations>>[7]
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
        # ~/~ begin <<README.md#nixos-host-modules>>[1]
        inputs.sops-nix.nixosModules.sops
        # ~/~ end
        # ~/~ begin <<README.md#nixos-host-modules>>[2]
        ({ config, ... }: tailscaleSetup "${config.sops.secrets."tailscale_auth_key".path}")
        # ~/~ end
    
        nixpkgSetup
        localizationSetup
        sshSetup
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
          # ~/~ begin <<README.md#nixos-host-config>>[2]
          sops = {
            age.keyFile = "/run/sops/age/keys.txt";
            defaultSopsFile = ./secrets.yaml;
            defaultSopsFormat = "yaml";
          };
          # ~/~ end
          # ~/~ begin <<README.md#nixos-host-config>>[3]
          boot.initrd.postDeviceCommands = ''
            mkdir -p /run/sops/age
            cp ${./keys.txt} /run/sops/age/keys.txt
            chmod -R 600 /run/sops/age/keys.txt
          '';
          # ~/~ end
          # ~/~ begin <<README.md#nixos-host-config>>[4]
          sops.secrets."tailscale_auth_key" = { };
          # ~/~ end
          # ~/~ begin <<README.md#nixos-host-config>>[5]
          networking.interfaces = {
            eno1.wakeOnLan.enable = true;
            eno2.wakeOnLan.enable = true;
          }; 
          # ~/~ end
        }
      ];
    };
    # ~/~ end
  };
}
# ~/~ end
