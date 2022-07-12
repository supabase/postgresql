# TODO caching for CI
with import (builtins.fetchTarball {
  name = "2021-09-29";
  url = "https://github.com/NixOS/nixpkgs/archive/76b1e16c6659ccef7187ca69b287525fea133244.tar.gz";
  sha256 = "1vsahpcx80k2bgslspb0sa6j4bmhdx77sw6la455drqcrqhdqj6a";
}) {};
let
  prefix = "pg";
  pgBuildDir = "$PWD/build";
  styleScript = writeShellScriptBin "${prefix}-style" ''
    set -euo pipefail

    echo 'Running pgindent on changed files...'
    changed=$(${git}/bin/git diff-index --name-only HEAD -- '*.c')
    for x in $changed; do
      ./src/tools/pgindent/pgindent $x
    done

    ./src/tools/pgindent/pgperltidy
  '';
  buildScript = writeShellScriptBin "${prefix}-build" ''
    set -euo pipefail

    [ ! -d build ] && ./configure --enable-cassert --prefix ${pgBuildDir} --with-CC="ccache gcc"

    make -j16
    make install -j16
  '';
  cleanScript = writeShellScriptBin "${prefix}-clean" ''
    rm -rf ${pgBuildDir}
  '';
  testModuleScript = writeShellScriptBin "${prefix}-test-module" ''
    set -euo pipefail

    cd src/test/modules/$1
    make check
  '';
  docsScript = writeShellScriptBin "${prefix}-serve-docs" ''
    set -euo pipefail

    make install-docs -j16

    cd ${pgBuildDir}/share/doc/html

    python -mSimpleHTTPServer 5050
  '';
in
mkShell {
  buildInputs = [
    readline zlib bison flex ctags ccache git bash
    python libxml2 libxslt # for docs
    (callPackage ./nix/PerlTidy.nix {})
    (callPackage ./nix/pg_bsd_ident.nix {})
    (callPackage ./nix/pgScript.nix {inherit prefix pgBuildDir;})
    styleScript
    buildScript
    cleanScript
    testModuleScript
    docsScript
  ];
  shellHook = ''
    export HISTFILE=.history
    export OUR_SHELL="${bash}/bin/bash"
  '';
}
