{
  description = "Hensou desktop kit and apps";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/4975466d324710c576dc11ad614684e6bd8cad8e";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      tools = pkgs.rustPlatform.buildRustPackage {
        pname = "hensou-xtask";
        version = "0.1.0";
        src = pkgs.lib.cleanSource self;
        cargoLock.lockFile = ./Cargo.lock;
        doCheck = true;
        meta = {
          description = "Development checks for the Hensou workspace";
          license = pkgs.lib.licenses.mit;
          platforms = [ system ];
          mainProgram = "xtask";
        };
      };
    in
    {
      packages.${system} = {
        hensou-xtask = tools;
        default = tools;
      };
      checks.${system}.workspace = tools;
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          cargo
          rustc
          rustfmt
          clippy
          pkg-config
          cmake
          ninja
          (qt6.env "hensou-qt" (
            with qt6;
            [
              qtbase
              qtdeclarative
              qtwayland
              qtsvg
            ]
          ))
        ];
      };
      formatter.${system} = pkgs.nixfmt-tree;
    };
}
