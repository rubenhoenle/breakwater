{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, treefmt-nix }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
      treefmtEval = treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs.nixpkgs-fmt.enable = true;
      };

      buildInputs = with pkgs; [
        pkg-config
        clang
        libclang
        libvncserver
        libvncserver.dev

        # Needed for native-display feature
        wayland
        libGL
        libxkbcommon
      ];

      breakwater = pkgs.rustPlatform.buildRustPackage {
        pname = "breakwater";
        version = "1.0.0";
        src = ./.;
        cargoLock = {
          lockFile = ./Cargo.lock;
          outputHashes = {
            "vncserver-0.2.2" = "sha256-WGOBBILBheqRhA+yL+BX6ZizTk13bgg9rK4n12bsSGo=";
          };
        };

        buildInputs = buildInputs;
        nativeBuildInputs = buildInputs;

        LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
        LIBVNCSERVER_HEADER_FILE = "${pkgs.libvncserver.dev}/include/rfb/rfb.h";

        # Needed for native-display feature
        WINIT_UNIX_BACKEND = "wayland";
        LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}";
        XDG_DATA_DIRS = builtins.getEnv "XDG_DATA_DIRS";

        RUSTC_BOOTSTRAP = 1;
      };
    in
    {
      formatter.${system} = treefmtEval.config.build.wrapper;
      checks.${system}.formatter = treefmtEval.config.build.check self;

      packages.${system} = {
        default = breakwater;
      };
    };
}
