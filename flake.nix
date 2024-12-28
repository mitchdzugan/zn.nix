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
              >&2 echo "[s9n]#$(basename $execd) :$taskname \"$@\""
            }

            case "$cmd" in
              "u" | "up")
                if [ "$is_active" = "1" ]; then
                  info already up "{:pid $pid}"
                  exit 0
                fi;;
              "d" | "down")
                if [ ! "$is_active" = "1" ]; then
                  info already down
                  exit 0
                fi;;
            esac

            bash -c "$ZFLAKE_CMD_PRE"
            case "$cmd" in
              "s" | "status")
                ia_edn="$([ -z \"$is_active\" ] && echo true || echo false)"
                info "status"
                echo "{:pid $pid"
                echo " :active? $ia_edn"
                echo "}";;
              "u" | "up")
                info starting up
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
                info is up "{:pid $pid}";;
              "d" | "down")
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
              bash -c "$ZFLAKE_CMD_POST"
            esac
          '';
        zflake = uuWrap "flake.nix" (bbW.writeBbScriptBin'
          "zflake"
          [s9n-raw pkgs.bash]
          ''
            (require '[babashka.fs :as fs]
                     '[babashka.process :refer [shell exec]]
                     '[clojure.walk :as walk])

            (defn sh-v [& cmd]
              (println (str "  " (str/join " " cmd)))
              (apply shell cmd))

            (defn once [f]
              (let [state (atom [])]
                (fn []
                  (if-not (empty? @state) (first @state)
                    (let [res (f)]
                      (reset! state [res])
                      res)))))

            (defmacro defn-once [name & rest]
              `(def ~name (once (fn [] ~@rest))))

            (defn-once get-nix-system
              (-> {:out :string :err :string}
                  (shell "nix" "eval" "--impure" "--raw" "--expr"
                         "builtins.currentSystem")
                  :out
                  (try (catch Exception _ nil))))

            (defn-once get-zflake-dev
              (let [nix-system (get-nix-system)
                    n-getFlake (str "(builtins.getFlake \"" (fs/cwd) "\")")
                    n-zflakeDev (str ".outputs.zflake-dev." nix-system)
                    n-zflakeDevFn (str "(f: f" n-zflakeDev ")")
                    n-zflakeDevSys (str "(" n-zflakeDevFn n-getFlake ")")
                    ks (mapcat #(-> [(str "post-" %1) (str "pre-" %1)])
                               ["up" "down" "status"])
                    n-inits (str "{" (reduce #(str %1 %2 "=\"\";") "" ks) "}")
                    n-s9nMapFn "(s: s // { taskname = s.pkg.name; })"
                    n-s9nMap (str "(builtins.map " n-s9nMapFn " z.singletons)")
                    n-attrsFinal (str "{singletons=" n-s9nMap ";}")
                    n-fixFn (str "(z: (" n-inits " // z // " n-attrsFinal "))")
                    n (str "(" n-fixFn n-zflakeDevSys ")")]
                (-> {:out :string :err :string}
                    (shell "nix" "eval" "--impure" "--json" "--expr" n)
                    :out
                    json/parse-string
                    (update "singletons"
                            (->> (fn [s9n]
                                   (merge (walk/keywordize-keys s9n)
                                          {:runsh (str "nix run .#"
                                                       (get s9n "taskname"))
                                           :execd (str (fs/cwd))}))
                                 (partial map)))
                    (try (catch Exception _ nil)))))

            (defn zflake-s9n-cmd [cmd {:keys [execd taskname runsh] :as cfg}]
              (let [pre (get cfg (keyword (str "pre-" cmd)) "")
                    post (get cfg (keyword (str "post-" cmd)) "")]
                (shell {:extra-env {"ZFLAKE_CMD_PRE" pre
                                    "ZFLAKE_CMD_POST" post}}
                       "${s9n-raw}/bin/s9n-raw" execd taskname runsh cmd)))

            (defn zflake-s9n-cmds [cmd & _]
              (println (str "[zflake] :dev :" cmd))
              (let [ask-cfg #(get (get-zflake-dev) (apply str %&))]
                (shell "${pkgs.bash}/bin/bash" "-c" (ask-cfg "pre-" cmd))
                (doseq [s9n (ask-cfg "singletons")] (zflake-s9n-cmd cmd s9n))
                (shell "${pkgs.bash}/bin/bash" "-c" (ask-cfg "post-" cmd))))

            (def zflake-dev-up (partial zflake-s9n-cmds "up"))
            (def zflake-dev-down (partial zflake-s9n-cmds "down"))
            (def zflake-dev-status (partial zflake-s9n-cmds "status"))

            (defn zflake-dev [[a1 & rest :as all]]
              (case a1
                ("u" "up" ":u" ":up") (zflake-dev-up rest)
                ("d" "down" ":d" ":down") (zflake-dev-down rest)
                ("s" "status" ":s" ":status") (zflake-dev-status rest)
                (zflake-dev-status all)))

            (defn zflake-run [[a1 & rest :as all]]
              (println "[zflake] :run")
              (apply sh-v "nix" "run" (str ".#" a1) rest))

            (defn zflake [[a1 & rest :as all]]
              (case a1
                ("d" "dev" ":d" ":dev") (zflake-dev rest)
                ("r" "run" ":r" ":run") (zflake-run rest)
                (zflake-run all)))

            (zflake *command-line-args*)
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
