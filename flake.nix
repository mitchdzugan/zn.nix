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
        mkScriptWriters = label: pkgs: exe: {
          "write${label}ScriptBin'" = name: ppg: body:
            writePkgScriptBin name (pkgs ++ ppg) exe body;
          "write${label}ScriptBin" = name: body:
            writePkgScriptBin name pkgs exe body;
        };
        bashW = mkScriptWriters "Bash" [pkgs.bash] "bash";
        bbW = mkScriptWriters "Bb" [pkgs.babashka] "bb";
        uu = bashW.writeBashScriptBin "uu" ''
          base=$(pwd)
          while true; do
            if [ -f "$(pwd)/$1" ]; then
              eval "$2"
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
          exe="\"${pkg}/bin/${pkg.name}\" $@"
          ${uu}/bin/uu "${tgt}" "$exe" \
            "(target:${tgt}) not found in ancestors (path:$(pwd))"
        '';
        zflake = uuWrap "flake.nix" (bbW.writeBbScriptBin "zflake" ''
          (require '[babashka.fs :as fs]
                   '[babashka.process :refer [shell]])

          (defn sh [& cmd]
            (println (str "  " (str/join " " cmd)))
            (apply shell cmd))

          (def zflake-devs-atom (atom []))

          (defn get-zflake-devs []
            (if-not (empty? @zflake-devs-atom) (first @zflake-devs-atom)
              :must-calc))

          (defn zflake-dev-up [[a1 & rest :as all]]
            (println " -- in zflake-dev-up --")
            (println all))

          (defn zflake-dev-down [[a1 & rest :as all]]
            (println " -- in zflake-dev-down --")
            (println all))

          (defn zflake-dev-status [[a1 & rest :as all]]
            (println " -- in zflake-dev-status --")
            (println (get-zflake-devs))
            (println all))

          (defn zflake-dev [[a1 & rest :as all]]
            (case a1
              ("u" "up" ":u" ":up") (zflake-dev-up rest)
              ("d" "down" ":d" ":down") (zflake-dev-down rest)
              ("s" "status" ":s" ":status") (zflake-dev-status rest)
              (zflake-dev-status all)))

          (defn zflake-run [[a1 & rest :as all]]
            (println "[zflake] :run")
            (apply sh "nix" "run" (str ".#" a1) rest))

          (defn zflake [[a1 & rest :as all]]
            (case a1
              ("d" "dev" ":d" ":dev") (zflake-dev rest)
              ("r" "run" ":r" ":run") (zflake-run rest)
              (zflake-run all)))

          (zflake *command-line-args*)
        '');
        pyAppDirs = pkgs.python3.withPackages (p: [p.appdirs]);
        s9n = pkg: (bashW.writeBashScriptBin'
          pkg.name
          [pkg pyAppDirs pkgs.coreutils pkgs.ps pkgs.procps]
          ''
            cmd=$1
            if [ "$cmd" = "" ]; then cmd=status; fi

            cubin="${pkgs.coreutils}/bin"
            pidself="$$"
            ts=$($cubin/date +%s)

            py='from appdirs import *; print(user_cache_dir("s9n", ""))'
            stated=$(echo $py | ${pyAppDirs}/bin/python3)
            execd=$(pwd)
            taskname="${pkg.name}"
            function hash_str () {
              echo $1 | $cubin/md5sum | $cubin/cut -f1 -d" "
              py='from appdirs import *; print(user_cache_dir("s9n", ""))'
              stated=$(echo $py | ${pyAppDirs}/bin/python3)
            }

            function check_is_active () {
              export psres=$(${pkgs.ps}/bin/ps -o args $1)
              py1="import os"
              py2="print(os.environ['psres'].splitlines()[-1].split()[-1])"
              py="$py1;$py2"
              curr_confirm=$(echo $py | ${pyAppDirs}/bin/python3)
              if [ "$curr_confirm" = "$2" ]; then echo 1; fi
            }

            taskid=$(hash_str "[$execd,$taskname]")
            taskdirname="$(basename $execd)"--"$taskname"--"$taskid"
            taskd="$stated/$taskdirname"
            mkdir -p "$taskd/by-pid"
            pid=""
            is_active=""
            echo "$taskd/pid"
            if [ -f "$taskd/pid" ]; then
              pid=$(cat "$taskd/pid")
              pidd="$taskd/by-pid/$pid"
              if [ -d "$pidd" ]; then
                if [ -f "$pidd/pid-confirm" ]; then
                  is_active=$(check_is_active $pid $(cat "$pidd/pid-confirm"))
                fi
              fi
            fi

            function info () {
              >&2 echo "[s9n]#$(basename $execd) :$taskname \"$@\""
            }

            case "$cmd" in
              "s" | "status")
                ia_edn="$([ -z \"$is_active\" ] && echo true || echo false)"
                info "status"
                echo "{:pid $pid"
                echo " :active? $ia_edn"
                echo "}"
                ;;
              "u" | "up")
                if [ "$is_active" = "1" ]; then
                  info already up "{:pid $pid}"
                  exit 0
                fi
                info starting up
                pid_confirm="confirm-$ts-$pidself"
                rm -rf "$taskd/by-pid"
                pwd="$taskd/by-pid/active"
                mkdir -p "$pwd"
                mkfifo "$pwd/in"
                touch "$pwd/out"
                touch "$pwd/err"
                echo "#!${pkgs.bash}/bin/bash"                      > "$pwd/exe"
                echo "cat \"$pwd/in\" | ${pkg}/bin/${pkg.name} \\" >> "$pwd/exe"
                echo "  2> \"$pwd/err\" \\"                        >> "$pwd/exe"
                echo "  1> \"$pwd/out\" \\"                        >> "$pwd/exe"
                chmod +x "$pwd/exe"
                ${pkgs.bash}/bin/bash -c "$pwd/exe $pid_confirm" &
                pid=$!
                disown $pid
                echo $pid_confirm > "$pwd/pid-confirm"
                echo $ts > "$pwd/started"
                ln -s "$pwd" "$taskd/by-pid/$pid"
                echo $pid > "$taskd/pid"
                info is up "{:pid $pid}";;
              "d" | "down")
                if [ ! "$is_active" = "1" ]; then
                  info already down
                  exit 0
                fi
                info shutting down
                pkill -P $pid
                info is down;;
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
      zflake = zflake;
    });
  };
}
