{
  description = "nix flake with various stuff i like to use";
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  inputs.clj-nix.url = "github:jlesquembre/clj-nix";
  inputs.jsim.url = "github:mitchdzugan/jsim";
  inputs.jsim.inputs.nixpkgs.follows = "nixpkgs";
  inputs.rep.url = "github:eraserhd/rep";
  inputs.rep.inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.url = "github:nix-community/home-manager";
  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";
  inputs.ssbm.url = "github:mitchdzugan/ssbm-nix";
  inputs.zkg.url = "github:mitchdzugan/zkg";
  inputs.zkg.inputs.nixpkgs.follows = "nixpkgs";
  inputs.zkm.url = "github:mitchdzugan/zkm";
  inputs.zkm.inputs.nixpkgs.follows = "nixpkgs";
  inputs.ztr.url = "github:mitchdzugan/ztr";
  inputs.ztr.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixgl.url = "github:nix-community/nixGL";
  inputs.nixgl.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nur.url = "github:nix-community/NUR";
  outputs = {
    self,
    nixpkgs,
    jsim,
    rep,
    clj-nix,
    ssbm,
    zkg,
    zkm,
    ztr,
    home-manager,
    nixgl,
    nur,
    ...
  }@attrs: {
    mk-zn = system:
      let
        lib = nixpkgs.lib;
        pkgs = nixpkgs.legacyPackages.${system};
        mkLibPath = deps: "${builtins.concatStringsSep "/lib:" deps}/lib";
        writePkgScriptBin = shPkg: name: ppg: exe: body: ((pkgs.writeTextFile {
          name = name;
          executable = true;
          destination = "/bin/${name}";
          text = ''
            #!${shPkg}/bin/${exe}
            ${body}
          '';
        }) // { propagatedBuildInputs = ppg; });
        mkScriptWriters = label: shPkg: exe: {
          "write${label}ScriptBin'" = name: ppg: body:
            writePkgScriptBin shPkg name ([shPkg] ++ ppg) exe body;
          "write${label}ScriptBin" = name: body:
            writePkgScriptBin shPkg name [shPkg] exe body;
        };
        bashW = mkScriptWriters "Bash" pkgs.bash "bash";
        bbW = mkScriptWriters "Bb" pkgs.babashka "bb";
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

            BLACK_BRIGHT='\033[0;90m'
            YELLOW_BRIGHT='\033[0;93m'
            BLUE='\033[0;34m'
            MAGENTA='\033[0;35m'
            MAGENTA_BRIGHT='\033[0;95m'
            CYAN='\033[0;36m'
            BOLD='\033[1m'
            NC='\033[0m'

            function info () {
              m="$1"
              shift
              outs=""
              function add_to_out () {
                content="$1"
                shift
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
                ia_edn="$([ "$is_active" = "1" ] && echo true || echo false)"
                if [ "$is_active" = "1" ]; then
                  info status active $MAGENTA :pid $NC $pid
                else
                  info status inactive
                fi;;
              "u" | "up")
                info up initiating
                pid_confirm="confirm-$ts-$pidself"
                rm -rf "$taskd/by-pid"
                pwd="$taskd/by-pid/active"
                mkdir -p "$pwd"
                mkfifo "$pwd/in"
                touch "$pwd/out"
                touch "$pwd/err"
                echo "#!${pkgs.bash}/bin/bash"         > "$pwd/exe"
                echo "cd \"$execd\""                  >> "$pwd/exe"
                m="cat \"$pwd/in\" | ($runsh"
                m="$m 2> \"$pwd/err\""
                m="$m 1> \"$pwd/out\")"
                echo "$m"                             >> "$pwd/exe"
                echo "echo \"\$?\" > \"$pwd/status\"" >> "$pwd/exe"
                echo "$cubin/date +%s > \"$pwd/end\"" >> "$pwd/exe"
                chmod +x "$pwd/exe"
                ${pkgs.bash}/bin/bash -c "$pwd/exe $pid_confirm" &
                pid=$!
                disown $pid
                echo $pid_confirm > "$pwd/pid-confirm"
                echo $ts > "$pwd/start"
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
        cljlib-path = "${./cljlib/.}";
        mkScript-add-cljlib = dest: ''
          mkdir -p ${dest}/z/spinner
          function add_clj () {
            cat "${cljlib-path}/z/$1" > "./${dest}/z/$1"
          }
          add_clj "spinner.clj"
          add_clj "spinner/worm.clj"
          add_clj "spinner/conway.clj"
          add_clj "style.clj"
          add_clj "unicode.clj"
          add_clj "util.clj"
        '';
        mkCljNative = psrc: name: eargs: (clj-nix.lib.mkCljApp {
          pkgs = pkgs;
          modules = [
            {
              builder-preBuild = mkScript-add-cljlib "src";
              projectSrc = psrc;
              name = "org.mitchdzugan/${name}";
              main-ns = "${name}.core";
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
              ] ++ eargs;
            }
          ];
        });
        wait-for = mkCljNative ./wait-for/. "wait-for" [
          "-H:JNIConfigurationFiles=${./.}/wait-for/.graal-support/jni.json"
          "-H:ResourceConfigurationFiles=${./.}/wait-for/.graal-support/resources.json"
          "--initialize-at-run-time=org.jline.nativ.Kernel32$MOUSE_EVENT_RECORD"
          "--initialize-at-run-time=org.jline.nativ.Kernel32$COORD"
          "--initialize-at-run-time=org.jline.nativ.Kernel32$FOCUS_EVENT_RECORD"
          "--initialize-at-run-time=org.jline.nativ.Kernel32$CONSOLE_SCREEN_BUFFER_INFO"
          "--initialize-at-run-time=org.jline.nativ.Kernel32$SMALL_RECT"
          "--initialize-at-run-time=org.jline.nativ.Kernel32$WINDOW_BUFFER_SIZE_RECORD"
          "--initialize-at-run-time=org.jline.nativ.Kernel32$MENU_EVENT_RECORD"
          "--initialize-at-run-time=org.jline.nativ.Kernel32$CHAR_INFO"
          "--initialize-at-run-time=org.jline.nativ.Kernel32$INPUT_RECORD"
          "--initialize-at-run-time=org.jline.nativ.Kernel32$KEY_EVENT_RECORD"
          "--initialize-at-run-time=org.jline.nativ.Kernel32"
        ];
        zflake-unwrapped = mkCljNative ./zflake/. "zflake" [];
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
        uuFlakeWrap = pkg: uuWrap "flake.nix" pkg;
        mk-enhanced-nrepl = n: alias: deps: pre-run: (uuFlakeWrap (
          bashW.writeBashScriptBin' n (deps ++ [pkgs.clojure pkgs.gnumake]) ''
            ${pre-run}
            make --makefile="${pkgs.writeText "Makefile" ''
              .PHONY: deps-repl
              HOME=$(shell echo $$HOME)
              HERE=$(shell echo $$PWD)
              .DEFAULT_GOAL := deps-repl
              SHELL = /usr/bin/env bash -Eeu
              DEPS_MAIN_OPTS ?= "-M:dev:test:${alias}"
              ENRICH_CLASSPATH_VERSION="1.19.3"

              # Create and cache a `clojure` command. deps.edn is mandatory; the others are optional but are taken into account for cache recomputation.
              # It's important not to silence with step with @ syntax, so that Enrich progress can be seen as it resolves dependencies.
              .enrich-classpath-deps-repl: deps.edn $(wildcard $(HOME)/.clojure/deps.edn) $(wildcard $(XDG_CONFIG_HOME)/.clojure/deps.edn)
              	cd $$(mktemp -d -t enrich-classpath.XXXXXX); clojure -Sforce -Srepro -J-XX:-OmitStackTraceInFastThrow -J-Dclojure.main.report=stderr -Sdeps '{:deps {mx.cider/tools.deps.enrich-classpath {:mvn/version $(ENRICH_CLASSPATH_VERSION)}}}' -M -m cider.enrich-classpath.clojure "clojure" "$(HERE)" "true" $(DEPS_MAIN_OPTS) | grep "^clojure" > $(HERE)/$@

              # Launches a repl, falling back to vanilla Clojure repl if something went wrong during classpath calculation.
              deps-repl: .enrich-classpath-deps-repl
              	@if grep --silent "^clojure" .enrich-classpath-deps-repl; then \
              		eval $$(cat .enrich-classpath-deps-repl); \
              	else \
              		echo "Falling back to Clojure repl... (you can avoid further falling back by removing .enrich-classpath-deps-repl)"; \
              		clojure $(DEPS_MAIN_OPTS); \
              	fi
            ''}"
          ''
        ));
        zn = (bbW // bashW // {
          mkScriptWriters = mkScriptWriters;
          mkLibPath = mkLibPath;
          mkCljApp = clj-nix.lib.mkCljApp;
          writePkgScriptBin = writePkgScriptBin;
          uu = uu;
          bp = bp;
          jsim = jsim.packages.${system}.jsim;
          rep = rep.packages.${system}.rep;
          uuWrap = uuWrap;
          uuFlakeWrap = uuFlakeWrap;
          uuNodeWrap = pkg: uuWrap "package.json" pkg;
          uuBbWrap = pkg: uuWrap "bb.edn" pkg;
          uuCljWrap = pkg: uuWrap "deps.edn" pkg;
          uuRustWrap = pkg: uuWrap "Cargo.toml" pkg;
          s9n = s9n;
          s9n-raw = s9n-raw;
          s9nFlakeRoot = pkg: uuWrap "flake.nix" (s9n pkg);
          zflake = zflake;
          wait-for = wait-for;
          mkScript-add-cljlib = mkScript-add-cljlib;
          mk-enhanced-nrepl = mk-enhanced-nrepl;
          reply = (uuWrap ".nrepl-port" (bashW.writeBashScriptBin'
            "reply"
            [pkgs.clojure]
            ''
              ${pkgs.clojure}/bin/clojure \
                -Sdeps '{:deps {reply/reply {:mvn/version "0.5.0"}}}' \
                -M -m reply.main --attach $(cat .nrepl-port) \
                $@
            ''
          ));
          nixRebuild = (bashW.writeBashScriptBin'
            "nixRebuild"
            []
            ''
              if [ "$1" == "boot" ]; then
                sudo bash -c 'cd /etc/nixos && nix flake update && nixos-rebuild boot'
              else
                sudo bash -c 'cd /etc/nixos && nix flake update && nixos-rebuild switch'
              fi
            ''
          );
        });
        nurpkgs = import nixpkgs {
          inherit system;
          overlays = [ nur.overlays.default ];
        };
      in (zn // {
        nixosModules.wslConfiguration = import ./os/wsl/configuration.nix {
          inherit pkgs lib zn ssbm zkg zkm ztr home-manager nixgl nur nurpkgs;
        };
      });
  };
}
