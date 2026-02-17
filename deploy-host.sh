# ~/~ begin <<README.md#deploy-host.sh>>[init]
extra_files=$(mktemp -d)
mkdir -pv ${extra_files}/run/sops/age
cp --verbose --archive ./keys.txt ${extra_files}/run/sops/age/keys.txt
chmod 600 ${extra_files}/run/sops/age/keys.txt

nix run github:nix-community/nixos-anywhere --                                  \
  --flake .#nixoshost                                                           \
  --generate-hardware-config nixos-generate-config ./hardware-configuration.nix \
  --extra-files "${extra_files}"                                                \
  --target-host $1
# ~/~ end
