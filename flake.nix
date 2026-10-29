{
  description = "Hensou plain Qt Quick kit and Rust/cxx-qt demo";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/4975466d324710c576dc11ad614684e6bd8cad8e";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      qt = pkgs.qt6.env "hensou-qt-${pkgs.qt6.qtbase.version}" (with pkgs.qt6; [
        qtbase qtdeclarative qtwayland qtsvg
      ]);
      kit = pkgs.runCommand "hensou-qml-0.1.0" { } ''
        mkdir -p $out/lib/qt-6/qml
        cp -R ${./kit/qml}/Hensou $out/lib/qt-6/qml/Hensou
      '';
      source = pkgs.lib.cleanSource self;
      tools = pkgs.rustPlatform.buildRustPackage {
        pname = "hensou-xtask";
        version = "0.1.0";
        src = source;
        cargoLock.lockFile = ./Cargo.lock;
        cargoBuildFlags = [ "--package" "hensou-xtask" ];
        cargoTestFlags = [ "--package" "hensou-xtask" ];
        meta.mainProgram = "xtask";
      };
      demo = pkgs.rustPlatform.buildRustPackage {
        pname = "hensou-demo";
        version = "0.1.0";
        src = source;
        cargoLock.lockFile = ./Cargo.lock;
        cargoBuildFlags = [ "--package" "hensou-demo" ];
        # UI behavior is tested on a real Wayland display by tools/test-demo.sh.
        doCheck = false;
        nativeBuildInputs = [ pkgs.pkg-config pkgs.qt6.wrapQtAppsHook ];
        buildInputs = [ qt ];
        QMAKE = "${qt}/bin/qmake";
        qtWrapperArgs = [
          "--set" "HENSOU_QML_IMPORT_PATH" "${kit}/lib/qt-6/qml"
          "--prefix" "QML_IMPORT_PATH" ":" "${kit}/lib/qt-6/qml"
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
        hensou-qml = kit;
        hensou-demo = demo;
        hensou-xtask = tools;
        default = demo;
      };
      checks.${system}.workspace = tools;
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          cargo rustc rustfmt clippy pkg-config cmake ninja qt
          python3 nodejs sway grim wtype jq
        ];
        QMAKE = "${qt}/bin/qmake";
        QT_PLUGIN_PATH = "${qt}/lib/qt-6/plugins";
        QML_IMPORT_PATH = "${qt}/lib/qt-6/qml";
      };
      formatter.${system} = pkgs.nixfmt-tree;
    };
}
