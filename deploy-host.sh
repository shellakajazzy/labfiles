# ~/~ begin <<README.md#deploy-host.sh>>[init]
extra_files=$(mktemp -d)
sudo mkdir -pv ${extra_files}/run/sops/age
sudo cp --verbose --archive $1 ${extra_files}/run/sops/age/keys.txt
sudo chmod 600 ${extra_files}/run/sops/age/keys.txt

nix run github:nix-community/nixos-anywhere --                                  \
  --flake .#nixoshost                                                           \
  --generate-hardware-config nixos-generate-config ./hardware-configuration.nix \
  --extra-files "${extra_files}"                                                \
  --target-host $2
# ~/~ end
