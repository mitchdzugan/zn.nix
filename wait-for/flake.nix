{
  description = ">[z]< text renderer";
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.zn-nix.url = "github:mitchdzugan/zn.nix";
  inputs.zn-nix.inputs.nixpkgs.follows = "nixpkgs";
  outputs = { self, nixpkgs, zn-nix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        version = builtins.substring 0 8 self.lastModifiedDate;
        pkgs = nixpkgs.legacyPackages.${system};
        zn = zn-nix.mk-zn system;
        ztrRtDeps = with pkgs; [
          fontconfig.lib
          xorg.libX11
          xorg.libXxf86vm
          xorg.libXext
          xorg.libXtst
          xorg.libXi
          xorg.libXcursor
          xorg.libXrandr
          libGL
        ];
        ztrBuildInputs = ztrRtDeps ++ [ pkgs.stdenv.cc.cc.lib pkgs.pkg-config ];
        rtLibPath = zn.mkLibPath ztrRtDeps;
        baseZtrModuleConfig = {
          projectSrc = ./.;
          name = "org.mitchdzugan/ztr";
          main-ns = "ztr.core";
          builder-extra-inputs = ztrBuildInputs;
          builder-preBuild = with pkgs; ''
            export LD_LIBRARY_PATH=${zn.mkLibPath [
              buildPackages.stdenv.cc.cc.lib fontconfig.lib xorg.libX11 libGL
            ]}
          '';
        };
        buildZtrApp = extraConfig: zn.mkCljApp {
          pkgs = pkgs;
          modules = [(extraConfig // baseZtrModuleConfig)];
        };
      in rec {
        packages.default = packages.ztr;
        packages.ztr = pkgs.stdenv.mkDerivation {
          pname = "ztr";
          inherit version;
          src = ./.;
          nativeBuildInputs = [ pkgs.makeWrapper ];
          propagatedBuildInputs = ztrBuildInputs ++ [ packages.ztr-unwrapped ];
          dontBuild = true;
          installPhase = with pkgs; ''
            runHook preInstall
            mkdir -p "$out/bin"
            makeWrapper "${packages.ztr-unwrapped}/bin/ztr" "$out/bin/ztr" \
              --unset WAYLAND_DISPLAY \
              --prefix LD_LIBRARY_PATH : "${rtLibPath}"
            runHook postInstall
          '';
        };
        packages.ztr-unwrapped = buildZtrApp {
          builder-extra-inputs = ztrBuildInputs;
          nativeImage.enable = true;
          nativeImage.extraNativeImageBuildArgs = [
            "--initialize-at-build-time"
            "-J-Dclojure.compiler.direct-linking=true"
            "-Dskija.staticLoad=false"
            "--initialize-at-run-time=io.github.humbleui.skija.impl.Cleanable"
            "--initialize-at-run-time=io.github.humbleui.skija.impl.RefCnt$_FinalizerHolder"
            "--initialize-at-run-time=io.github.humbleui.skija"
            "--initialize-at-build-time=io.github.humbleui.skija.BlendMode"
            "--initialize-at-run-time=org.lwjgl"
            "--native-image-info"
            "-march=compatibility"
            "-H:+JNI"
            "-H:JNIConfigurationFiles=${./.}/.graal-support/jni.json"
            "-H:ResourceConfigurationFiles=${./.}/.graal-support/resources.json"
            "-H:+ReportExceptionStackTraces"
            "--report-unsupported-elements-at-runtime"
            "--verbose"
            "-Dskija.logLevel=DEBUG"
            "-H:DashboardDump=target/dashboard-dump"
          ];
        };
        /* rest used for development */
        packages.build-uberjar = buildZtrApp {};
        packages.trace-run = zn.uuFlakeWrap (zn.writeBashScriptBin'
          "trace-run"
          (ztrBuildInputs ++ [ packages.build-uberjar pkgs.graalvm-ce ])
          ''
            export LD_LIBRARY_PATH="${rtLibPath}"
            gvmh="$GRAALVM_HOME"
            if [ ! -f "$gmvh/bin/java" ]; then
              gmvh="${pkgs.graalvm-ce}"
            fi
            jar_path=$(cat "${packages.build-uberjar}/nix-support/jar-path")
            $gmvh/bin/java \
              -agentlib:native-image-agent=config-merge-dir=./.graal-support
              -jar $jar_path
          ''
        );
        packages.trace-normalize = zn.uuFlakeWrap (zn.writeBbScriptBin
          "trace-normalize"
          ''
            (require '[cheshire.core :as json]
                     '[clojure.string :as str])
            (println "normalizing trace data")
            (def trace-dir "./.graal-support/")
            (def trace-filename (partial str trace-dir))
            (def md (-> (trace-filename "reachability-metadata.json")
                        slurp
                        str/join
                        json/parse-string))
            (def rn-key #(-> %1 (dissoc %2) (assoc %3 (get %1 %2))))
            (defn md-out [l md]
              (spit (trace-filename (str l ".json")) (json/generate-string md)))
            (md-out "jni" (map #(rn-key %1 "type" "name") (get md "jni")))
            (md-out "resources" {"globs" (get md "resources")})
            (println "trace data normalized. namaste and good luck =^)")
          ''
        );
        packages.dev-run = zn.uuFlakeWrap (zn.writeBashScriptBin'
          "dev-run"
          (ztrBuildInputs ++ [pkgs.clojure])
          "LD_LIBRARY_PATH=${rtLibPath} ${pkgs.clojure}/bin/clj -M -m ztr.core"
        );
        packages.watch-and-refresh = zn.uuFlakeWrap (zn.writeBashScriptBin'
          "watch-and-refresh"
          [zn.rep pkgs.watchexec]
          ''
            clj1="(require '[clojure.tools.namespace.repl :as __R])"
            clj="(do $clj1 (__R/refresh))"
            watchexec -e clj,edn -- rep \"\\\"$clj\\\"\"
          ''
        );
        packages.nrepl = zn.uuFlakeWrap (zn.writeBashScriptBin'
          "nrepl"
          (ztrBuildInputs ++ [pkgs.clojure pkgs.gnumake])
          ''
            export LD_LIBRARY_PATH="${rtLibPath}"
            make --makefile="${pkgs.writeText "Makefile" ''
              .PHONY: deps-repl
              HOME=$(shell echo $$HOME)
              HERE=$(shell echo $$PWD)
              .DEFAULT_GOAL := deps-repl
              SHELL = /usr/bin/env bash -Eeu
              # check does removing dev/test do anything..?
              DEPS_MAIN_OPTS ?= "-M:dev:test:repl/conjure"
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
        );
        packages.zflake = zn.zflake;
        zflake-dev = {
          singletons = [
            { pkg = packages.nrepl; pre-up = "rm .nrepl-port 2> /dev/null"; }
            { pkg = packages.watch-and-refresh; }
          ];
          post-up = ''
            trap "exit 0" SIGCONT

            function wait_for_nrepl () {
              needs_init_echo=1
              while [ ! -f .nrepl-port ]; do
                if [ "$needs_init_echo" = "1" ]; then
                  echo "waiting for nrepl - press [q] to [q]uit waiting"
                  needs_init_echo=0
                fi
                echo "  waiting for nrepl..."
                sleep 2
              done
              echo "  nrepl ready - enjoy"
              kill -s SIGCONT "$$"
            }

            wait_for_nrepl &
            wait_for_nrepl_pid="$!"
            nextch=""
            while [ ! "$nextch" = "q" ]; do read -rsn1 nextch; done
            echo "  [q] pressed - nrepl may not be ready"
            kill "$wait_for_nrepl_pid"
          '';
        };
    });
}
