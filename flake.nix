{
  description = "Hensou plain Qt Quick kit and Rust/cxx-qt demo";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/4975466d324710c576dc11ad614684e6bd8cad8e";

  inputs.chicagoflf-src = {
    url = "https://fontlibrary.org/assets/downloads/chicagoflf/a2e4a3d14e40fa7076a0a1bc06f3de43/chicagoflf.zip";
    flake = false;
  };
  inputs.w95fa-src = {
    url = "https://fontsarena.com/wp-content/uploads/2020/01/W95FA.zip";
    flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      chicagoflf-src,
      w95fa-src,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      qt = pkgs.qt6.env "hensou-qt-${pkgs.qt6.qtbase.version}" (
        with pkgs.qt6;
        [
          qtbase
          qtdeclarative
          qtwayland
          qtsvg
        ]
      );
      kit = pkgs.runCommand "hensou-qml-0.1.0" { } ''
        mkdir -p $out/lib/qt-6/qml
        cp -R ${./kit/qml}/Hensou $out/lib/qt-6/qml/Hensou
      '';
      fonts = import ./nix/fonts.nix { inherit pkgs chicagoflf-src w95fa-src; };
      source = pkgs.lib.cleanSource self;
      tools = pkgs.rustPlatform.buildRustPackage {
        pname = "hensou-xtask";
        version = "0.1.0";
        src = source;
        cargoLock.lockFile = ./Cargo.lock;
        cargoBuildFlags = [
          "--package"
          "hensou-xtask"
        ];
        cargoTestFlags = [
          "--package"
          "hensou-xtask"
        ];
        meta.mainProgram = "xtask";
      };
      demo = pkgs.rustPlatform.buildRustPackage {
        pname = "hensou-demo";
        version = "0.1.0";
        src = source;
        cargoLock.lockFile = ./Cargo.lock;
        cargoBuildFlags = [
          "--package"
          "hensou-demo"
        ];
        # UI behavior is tested on a real Wayland display by tools/test-demo.sh.
        doCheck = false;
        nativeBuildInputs = [
          pkgs.pkg-config
          pkgs.autoPatchelfHook
          pkgs.lld
          pkgs.qt6.wrapQtAppsHook
        ];
        buildInputs = with pkgs.qt6; [
          qtbase
          qtdeclarative
          qtwayland
          qtsvg
          pkgs.libglvnd
          pkgs.stdenv.cc.cc.lib
        ];
        # cxx-qt initialization archives require an order-independent ELF linker.
        RUSTFLAGS = "-C link-arg=-fuse-ld=lld";
        QMAKE = "${qt}/bin/qmake";
        # Qt setup hooks select qtbase qmake; restore the merged PRL prefix.
        preBuild = ''
          export QMAKE=${qt}/bin/qmake
        '';
        qtWrapperArgs = [
          "--set"
          "HENSOU_FONT_DIRECTORY"
          "${fonts.hensou-fonts}/share/fonts/truetype"
          "--set"
          "HENSOU_QML_IMPORT_PATH"
          "${kit}/lib/qt-6/qml"
          "--prefix"
          "QML_IMPORT_PATH"
          ":"
          "${kit}/lib/qt-6/qml"
        ];
        meta = {
          description = "Interactive standalone Hensou Qt Quick demo";
          license = pkgs.lib.licenses.mit;
          platforms = [ system ];
          mainProgram = "hensou-demo";
        };
      };
    in
    {
      packages.${system} = {
        inherit (fonts) chicagoflf w95fa-grid hensou-fonts;
        hensou-qml = kit;
        hensou-demo = demo;
        hensou-xtask = tools;
        default = demo;
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
          qt
          mesa.drivers
          python3
          nodejs
          sway
          grim
          wtype
          jq
          nixfmt
          ruff
          shellcheck
          lld
        ];
        buildInputs = [ pkgs.libglvnd ];
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
          qt
          pkgs.libglvnd
          pkgs.stdenv.cc.cc.lib
        ];
        LIBGL_DRIVERS_PATH = "${pkgs.mesa.drivers}/lib/dri";
        __EGL_VENDOR_LIBRARY_FILENAMES = "${pkgs.mesa.drivers}/share/glvnd/egl_vendor.d/50_mesa.json";
        RUSTFLAGS = "-C link-arg=-fuse-ld=lld";
        HENSOU_FONT_DIRECTORY = "${fonts.hensou-fonts}/share/fonts/truetype";
        QMAKE = "${qt}/bin/qmake";
        QT_PLUGIN_PATH = "${qt}/lib/qt-6/plugins";
        QML_IMPORT_PATH = "${qt}/lib/qt-6/qml";
      };
      formatter.${system} = pkgs.nixfmt-tree;
    };
}
