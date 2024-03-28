{
  description = "nix-vm-test";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nix-vm-test = {
      url = "github:numtide/nix-vm-test/pic/mount-relative";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nix-vm-test, ... }: {

    packages.x86_64-linux = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      lib = pkgs.lib;
      debVmTest = {
        diskSize = "+1G";
        sharedDirs = {
          debfiles = {
            source = "./";
            target = "/tmp/sourcedir";
          };
        };
        testScript = ''
          vm.wait_for_unit("multi-user.target")
          vm.succeed("apt-get update")
          # The apt-get install output is breaking the test runner for now.
          # Piping the output to a file and copying it to the host in case of failure.
          # See upstream issue: https://github.com/numtide/nix-vm-test/issues/5
          vm.succeed("apt-get -yq install /tmp/sourcedir/garage_0.9.3_amd64.deb &> /dev/null")
          vm.wait_for_unit("garage.service")
          vm.succeed("garage status | grep 127.0.0.1")
        '';
      };
      rpmVmTest = {
        diskSize = "+1G";
        sharedDirs = {
          debfiles = {
            source = "./";
            target = "/tmp/sourcedir";
          };
        };
        testScript = ''
          vm.wait_for_unit("multi-user.target")
          vm.succeed("yum localinstall -y /tmp/sourcedir/garage-0.9.3-1.x86_64.rpm")
          vm.wait_for_unit("garage.service")
          vm.succeed("garage status | grep 127.0.0.1")
        '';
      };
      debianTests = lib.genAttrs ["12" "13"] (name: nix-vm-test.lib.x86_64-linux.debian.${name} debVmTest);
      ubuntuTests = lib.genAttrs ["23_10" "22_04" ] (name: nix-vm-test.lib.x86_64-linux.ubuntu.${name} debVmTest);
      fedoraTests = lib.genAttrs ["38" "39" ] (name: nix-vm-test.lib.x86_64-linux.fedora.${name} rpmVmTest);
    in (lib.attrsets.mapAttrs' (n: v: lib.attrsets.nameValuePair ("debian-" + n) v ) debianTests) //
       (lib.attrsets.mapAttrs' (n: v: lib.attrsets.nameValuePair ("ubuntu-" + n) v ) ubuntuTests) //
       (lib.attrsets.mapAttrs' (n: v: lib.attrsets.nameValuePair ("fedora-" + n) v ) fedoraTests);
  };
}
