{
  description = "nix flake with various stuff i like to use";
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  inputs.clj-nix.url = "github:jlesquembre/clj-nix";
  inputs.jsim.url = "github:mitchdzugan/jsim";
  inputs.jsim.inputs.nixpkgs.follows = "nixpkgs";
  inputs.rep.url = "github:eraserhd/rep";
  inputs.rep.inputs.nixpkgs.follows = "nixpkgs";
  outputs = { self, nixpkgs, jsim, rep, clj-nix, ... }: {
    mk-zn = system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        mkLibPath = deps: "${builtins.concatStringsSep "/lib:" deps}/lib";
        writePkgScriptBin' = ppg: pkg: name: body: ((pkgs.writeTextFile {
          name = name;
          executable = true;
          destination = "/bin/${name}";
          text = ''
            #!${pkg}/bin/${pkg.executable}
            ${body}
          '';
        }) // { propagatedBuildInputs = [pkg] ++ ppg; });
        writePkgScriptBin = p: n: b: (writePkgScriptBin' [] p n b);
        uu = writePkgScriptBin pkgs.bash "uu" ''
          base=$(pwd)
          while true; do
            if [ -f "$(pwd)/$1" ]; then
              eval $2
              exit 0
            elif [ "$(pwd)" = "/" ]; then
              >&2 echo $3
              exit 1
            fi
            cd ..
          done
        '';
        bp = writePkgScriptBin' [ uu ] pkgs.bash "bp" ''
          uu "bb.edn" "bb $@" "not in a bb project [$(pwd)]"
        '';
      in {
      mkLibPath = mkLibPath;
      mkCljApp = clj-nix.lib.mkCljApp;
      writePkgScriptBin = writePkgScriptBin;
      uu = uu;
      bp = bp;
      jsim = jsim.packages.${system}.jsim;
      rep = rep.packages.${system}.rep;
    };
  };
}
