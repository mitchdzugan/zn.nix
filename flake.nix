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
        writePkgScriptBin = name: ppg: exe: body: ((pkgs.writeTextFile {
          name = name;
          executable = true;
          destination = "/bin/${name}";
          text = ''
            #!/usr/bin/env ${exe}
            ${body}
          '';
        }) // { propagatedBuildInputs = ppg; });
        mkScriptWriters = label: pkg: exe: {
          "write${label}ScriptBin'" = name: ppg: body:
            writePkgScriptBin name ([ pkg ] ++ ppg) exe body;
          "write${label}ScriptBin" = name: body:
            writePkgScriptBin name [ pkg ] exe body;
        };
        bashW = mkScriptWriters "Bash" pkgs.bash "bash";
        bbW = mkScriptWriters "Bb" pkgs.babashka "bb";
        uu = bashW.writeBashScriptBin "uu" ''
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
        bp = bashW.writeBashScriptBin "bp" ''
          uu "bb.edn" "bb $@" "not in a bb project [$(pwd)]"
        '';
        uuWrap = tgt: pkg: bashW.writeBashScriptBin' pkg.name [uu pkg ] ''
          ${uu}/bin/uu \
            "${tgt}" \
            "\"${pkg}/bin/${pkg.name}\" $@" \
            "(target:${tgt}) not found in ancestors (path:$(pwd))"
        '';
        pyAppDirs = pkgs.python3.withPackages (p: [p.appdirs]);
        s9n = pkg: (bashW.writeBashScriptBin'
          pkg.name
          [pkg pyAppDirs]
          ''
            cmd=$1
            if [ "$cmd" = "" ]; then cmd=status; fi
            py='from appdirs import *; print(user_cache_dir("s9n", ""))'
            stated=$(echo $py | ${pyAppDirs}/bin/python3)
            execd=$(pwd)
            taskname="${pkg.name}"

            case "$cmd" in
              "s" | "status")
                echo "status";;
              "u" | "up")
                echo "up";;
              "d" | "down")
                echo "down";;
              "j" | "join")
                echo "join";;
              "o" | "out")
                echo "out";;
              "e" | "error")
                echo "error";;
              "l" | "logs" | "out-error")
                echo "logs";;
              *)
                echo "unknown command - $cmd"
                exit 1
            esac

            # ${pkg}/bin/${pkg.name}
          ''
        );
      in (bbW // bashW // {
      mkLibPath = mkLibPath;
      mkCljApp = clj-nix.lib.mkCljApp;
      writePkgScriptBin = writePkgScriptBin;
      uu = uu;
      bp = bp;
      jsim = jsim.packages.${system}.jsim;
      rep = rep.packages.${system}.rep;
      uuWrap = uuWrap;
      uuFlakeWrap = pkg: uuWrap "flake.nix" pkg;
      uuNodeWrap = pkg: uuWrap "package.json" pkg;
      uuBbWrap = pkg: uuWrap "bb.edn" pkg;
      uuCljWrap = pkg: uuWrap "deps.edn" pkg;
      uuRustWrap = pkg: uuWrap "Cargo.toml" pkg;
      s9n = s9n;
      s9nFlakeRoot = pkg: uuWrap "flake.nix" (s9n pkg);
    });
  };
}
