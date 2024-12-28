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
        pyAppDirs = pkgs.python3.withPackages (p: [p.appdirs]);
        s9n-raw = bashW.writeBashScriptBin'
          "s9n-raw"
          [pyAppDirs pkgs.coreutils pkgs.ps pkgs.procps]
          ''
            execd="$1"
            taskname="$2"
            runsh="$3"
            cmd="$4"
            if [ "$cmd" = "" ]; then cmd=status; fi

            cubin="${pkgs.coreutils}/bin"
            pidself="$$"
            ts=$($cubin/date +%s)

            py='from appdirs import *; print(user_cache_dir("s9n", ""))'
            stated=$(echo $py | ${pyAppDirs}/bin/python3)
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
              m="$1"
              shift
              BLACK_BRIGHT='\033[0;90m'
              YELLOW_BRIGHT='\033[0;93m'
              BLUE='\033[0;34m'
              MAGENTA='\033[0;35m'
              MAGENTA_BRIGHT='\033[0;95m'
              CYAN='\033[0;36m'
              BOLD='\033[1m'
              outs=""
              function add_to_out () {
                content="$1"
                shift
                NC='\033[0m'
                for st in "$@"; do outs="$outs$st"; done
                outs="$outs$content$NC"
              }
              add_to_out "⦗" $BLACK_BRIGHT $BOLD
              add_to_out "s9n/" $YELLOW_BRIGHT $BOLD
              add_to_out "$m" $MAGENTA_BRIGHT $BOLD
              add_to_out "⦘" $BLACK_BRIGHT $BOLD
              add_to_out "\\$(basename $execd)" $CYAN
              add_to_out " :$taskname" $MAGENTA
              >&2 echo -e "$outs $@"
              # >&2 echo "[s9n/$m]#$(basename $execd) :$taskname $@"
            }

            case "$cmd" in
              "u" | "up")
                if [ "$is_active" = "1" ]; then
                  info up already up "{:pid $pid}"
                  exit 0
                fi;;
              "d" | "down")
                if [ ! "$is_active" = "1" ]; then
                  info down already down
                  exit 0
                fi;;
            esac

            bash -c "$ZFLAKE_CMD_PRE"
            case "$cmd" in
              "s" | "status")
                ia_edn="$([ -z \"$is_active\" ] && echo true || echo false)"
                info status
                echo "{:pid $pid"
                echo " :active? $ia_edn"
                echo "}";;
              "u" | "up")
                info up initiating
                pid_confirm="confirm-$ts-$pidself"
                rm -rf "$taskd/by-pid"
                pwd="$taskd/by-pid/active"
                mkdir -p "$pwd"
                mkfifo "$pwd/in"
                touch "$pwd/out"
                touch "$pwd/err"
                echo "#!${pkgs.bash}/bin/bash"      > "$pwd/exe"
                echo "cd \"$execd\""               >> "$pwd/exe"
                echo "cat \"$pwd/in\" | $runsh \\" >> "$pwd/exe"
                echo "  2> \"$pwd/err\" \\"        >> "$pwd/exe"
                echo "  1> \"$pwd/out\" \\"        >> "$pwd/exe"
                chmod +x "$pwd/exe"
                ${pkgs.bash}/bin/bash -c "$pwd/exe $pid_confirm" &
                pid=$!
                disown $pid
                echo $pid_confirm > "$pwd/pid-confirm"
                echo $ts > "$pwd/started"
                ln -s "$pwd" "$taskd/by-pid/$pid"
                echo $pid > "$taskd/pid"
                info up completed "{:pid $pid}";;
              "d" | "down")
                info down initiating
                pkill -P $pid
                info down completed;;
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
              bash -c "$ZFLAKE_CMD_POST"
            esac
          '';
        zflake-unwrapped = clj-nix.lib.mkCljApp {
          pkgs = pkgs;
          modules = [
            {
              projectSrc = ./zflake/.;
              name = "org.mitchdzugan/zflake";
              main-ns = "zflake.core";
              builder-extra-inputs = [];
              nativeImage.enable = true;
              nativeImage.extraNativeImageBuildArgs = [
                "--initialize-at-build-time"
                "-J-Dclojure.compiler.direct-linking=true"
                "--native-image-info"
                "-march=compatibility"
                "-H:+JNI"
                "-H:+ReportExceptionStackTraces"
                "--report-unsupported-elements-at-runtime"
                "--verbose"
                "-H:DashboardDump=target/dashboard-dump"
              ];
            }
          ];
        };
        zflake = uuWrap "flake.nix" (bashW.writeBashScriptBin'
          "zflake"
          [s9n-raw zflake-unwrapped]
          ''
            S9N_BIN="${s9n-raw}/bin/s9n-raw"
            BASH_BIN="${pkgs.bash}/bin/bash"
            "${zflake-unwrapped}/bin/zflake" "$S9N_BIN" "$BASH_BIN" $@
          ''
        );
        s9n = pkg: (bashW.writeBashScriptBin' pkg.name [s9n-raw pkg] ''
          cmd=$1
          execd="$(pwd)"
          taskname="${pkg.name}"
          runsh="${pkg}/bin/${pkg.name}"
          ${s9n-raw}/bin/s9n-raw "$execd" "$taskname" "$runsh" "$cmd"
        '');
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
