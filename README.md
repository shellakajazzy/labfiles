[![Entangled badge](https://img.shields.io/badge/entangled-Use%20the%20source!-%2300aeff)](https://entangled.github.io/)

# `labfiles`
The configuration files / design documents for my homelab network and server.

## Hardware & Network Anatomy
My home server is a Dell PowerEdge T420, which is running NixOS with `microvm.nix` on top of it.

## Nix Flake
I use NixOS for both the host and the VMs running on it.
I will store all of the configurations in a single flake file.

[`./flake.nix`](./flake.nix):
``` {.nix file="flake.nix"}
{
  description = "Flake containing the configuration for Jason G's homelab network and server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    <<flake-inputs>>
  };

  outputs = { self, nixpkgs, ... } @ inputs: let
    <<flake-declarations>>
  in {
    <<nixos-host-declaration>>
  };
}
```

## Functions
These are functions that are shared between multiple configs.

### Nix (The Package Manager) Setup
This enables flakes and other experimental features for the Nix package manager, as well as various other features.

`flake-declarations`:
``` {.nix #flake-declarations}
nixpkgSetup = {
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "@wheel" "root" ];
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.11";
};
```

### Localization Setup
Required for NixOS configurations.

`flake-declarations`:
``` {.nix #flake-declarations}
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
```

### Bootloader Setup
GRUB is my bootloader of choice.

`flake-declarations`:
``` {.nix #flake-declarations}
bootloaderSetup = {
  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "nodev" ];
  boot.growPartition = true;
};
```

### User Setup
The user should have the same name as the machine, and the root user should not be able to be logged into.

`flake-declarations`:
``` {.nix #flake-declarations}
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
```

TODO: implement setting up user password using `nix-sops` as well as SSHing into users with a key
- Will do once secrets and SSH are setup

### Networking Setup
This sets up the hostname of the machine as well as getting networking up.

`flake-declarations`:
``` {.nix #flake-declarations}
networkingSetup = hostname: {
  networking.networkmanager.enable = true;
  networking.hostName = "${hostname}";
};
```

## Host Configuration

`nixos-host-declaration`:
``` {.nix #nixos-host-declaration}
nixosConfigurations.nixoshost = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";  
  modules = [
    <<nixos-host-modules>>

    nixpkgSetup
    localizationSetup
    (userSetup "nixoshost")
    (networkingSetup "nixoshost")

    ./hardware-configuration.nix
    {
      <<nixos-host-config>>
    }
  ];
};
```

### Disk Setup
The NixOS Host Machine is running on my Dell PowerEdge T420 with 8x 1TB hard drives and a single 256GB SSD.
It should be configured to run RAID on the hard drives and a normal boot disk setup on the SSD.
To achieve this, I will be using `disko` to partition and manage my hard drives.


First, I need to import `disko`.

`flake-inputs`:
``` {.nix #flake-inputs}
disko = {
  url = "github:nix-community/disko";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then, I need to add `disko` as a NixOS module to my host's configuration.

`nixos-host-modules`:
``` {.nix #nixos-host-modules}
inputs.disko.nixosModules.disko
```

For the RAID disks, I also want to abstract out their configuration in the

`flake-declarations`:
``` {.nix #flake-declarations}
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
```

Finally, I setup the disks in the host's NixOS configuration.

`nixos-host-config`:
``` {.nix #nixos-host-config}
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
```

### Bootloader Config
Because the host is deployed using `nixos-anywhere`, I need to set special boot options for it.

`nixos-host-config`:
``` {.nix #nixos-host-config}
boot.loader.grub = {
  device = "nodev";
  efiSupport = true;
  efiInstallAsRemovable = true;
};
```
