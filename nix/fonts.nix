{
  pkgs,
  chicagoflf-src,
  w95fa-src,
}:
let
  chicagoflf = pkgs.stdenvNoCC.mkDerivation {
    pname = "chicagoflf";
    version = "2.1";
    src = chicagoflf-src;
    dontBuild = true;
    installPhase = ''
      install -Dm644 ChicagoFLF.ttf "$out/share/fonts/truetype/ChicagoFLF.ttf"
      install -Dm644 README.ChicagoFLF "$out/share/doc/chicagoflf/README.ChicagoFLF"
    '';
    meta.license = pkgs.lib.licenses.publicDomain;
  };
  w95fa-grid = pkgs.stdenvNoCC.mkDerivation {
    pname = "w95fa-grid";
    version = "1.002-grid1";
    src = w95fa-src;
    nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.fonttools ])) ];
    buildPhase = ''
      python3 ${../tools/w95fa-grid.py} W95FA/W95FA.otf W95FAGrid.ttf
    '';
    installPhase = ''
      install -Dm644 W95FAGrid.ttf "$out/share/fonts/truetype/W95FAGrid.ttf"
      install -Dm644 W95FA/OFL.txt "$out/share/licenses/w95fa-grid/OFL.txt"
    '';
    meta.license = pkgs.lib.licenses.ofl;
  };
in
{
  inherit chicagoflf w95fa-grid;
  hensou-fonts = pkgs.symlinkJoin {
    name = "hensou-fonts";
    paths = [
      chicagoflf
      w95fa-grid
    ];
  };
}
