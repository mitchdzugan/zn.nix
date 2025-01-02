(ns zflake.core
  (:require [clojure.core.async :as a]
            [clojure.set]
            [babashka.fs :as fs]
            [babashka.process :refer [shell]]
            [cheshire.core :as json]
            [clojure.walk :as walk]
            [clojure.string :as str]
            [z.spinner :as spinner]
            [z.spinner.conway :as gol]
            [z.style :as st]
            [z.util :as u :refer [defn-once]])
  (:gen-class))
(set! *warn-on-reflection* true)

(def ^:dynamic *s9n-bin* nil)
(def ^:dynamic *bash-bin* nil)

(defn sh-v
  [& cmd]
  (->>
    [["⦗" :b :black-bright] ["zflake/" :b :yellow-bright]
     ["exec" :b :magenta-bright] ["⦘" :b :black-bright] [": " :b :black-bright]
     [(str/join " " cmd) :green]]
    st/%*
    println)
  (apply shell cmd))

(defn-once
  get-nix-system
  (->
    {:out :string :err :string}
    (shell "nix" "eval" "--impure" "--raw" "--expr" "builtins.currentSystem")
    :out
    (try (catch Exception _ nil))))

(defn get-zflake-dev-impl
  []
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
    (->
      {:out :string :err :string}
      (shell "nix" "eval" "--impure" "--json" "--expr" n)
      :out
      json/parse-string
      (update "singletons"
              (->>
                (fn [s9n]
                  (merge (walk/keywordize-keys s9n)
                         {:runsh (str "nix run .#" (get s9n "taskname"))
                          :execd (str (fs/cwd))}))
                (partial map)))
      (try (catch Exception e (println e) {})))))

(defn-once nix-realize-extra-deps
           []
           (let [nix-system (get-nix-system)
                 n-getFlake (str "(builtins.getFlake \"" (fs/cwd) "\")")
                 n-zflakeExtraDeps
                   (str ".outputs.zflake-dev." nix-system ".extra-deps")
                 n-zflakeExtraDepsFn (str "(f: f" n-zflakeExtraDeps ")")
                 n (str "(" n-zflakeExtraDepsFn n-getFlake ")")
                 shell-opts {:out :string :err :string}]
             (->
               (->>
                 (shell shell-opts "nix-instantiate" "--impure" "--expr" n)
                 ((comp str/split-lines str/trim :out))
                 (apply shell shell-opts "nix-store" "--realize"))
               (try true (catch Exception e (println e) false)))))

(defn-once get-zflake-dev
           (let [tstyles {:done [["🭪" :i :yellow] ["✔" :b :green]
                                 ["🭨" :i :yellow]]}
                 out #(st/re-println (st/%** ["⦗" :b :black-bright]
                                             ["zflake" :b :yellow-bright]
                                             ["⦘" :b :black-bright]
                                             [" retreiving nix data "]
                                             ["[" :b :black-bright]
                                             [(st/%* (or (get tstyles %1)
                                                         (spinner/styled %1)))]
                                             ["]" :b :black-bright]))
                 done? (atom false)
                 tc (a/chan)
                 vc (a/chan)]
             (a/go (while (not @done?) (Thread/sleep 120) (a/>! tc true)))
             (a/go (get-nix-system)
                   (let [czflake-dev (a/go (get-zflake-dev-impl))]
                     (a/<! (a/go (nix-realize-extra-deps)))
                     (a/>! vc (a/<! czflake-dev)))
                   (reset! done? true))
             (a/<!! (a/go (println)
                          (loop [spinner (spinner/pre-style gol/spinner)]
                            (out spinner)
                            (let [[v c] (a/alts! [tc vc])]
                              (if (= c vc)
                                (do (out :done) v)
                                (recur (spinner/step spinner)))))))))

(defn zflake-s9n-cmd
  [cmd {:keys [execd taskname runsh] :as cfg}]
  (let [pre (get cfg (keyword (str "pre-" cmd)) "")
        post (get cfg (keyword (str "post-" cmd)) "")]
    (shell {:extra-env {"ZFLAKE_CMD_PRE" pre "ZFLAKE_CMD_POST" post}}
           *s9n-bin*
           execd
           taskname
           runsh
           cmd)))

(defn zflake-s9n-cmds
  [cmd & _]
  (get-zflake-dev)
  (let [ask-cfg #(get (get-zflake-dev) (apply str %&))]
    (shell *bash-bin* "-c" (ask-cfg "pre-" cmd))
    (doseq [s9n (ask-cfg "singletons")] (zflake-s9n-cmd cmd s9n))
    (shell *bash-bin* "-c" (ask-cfg "post-" cmd))))

(def zflake-dev-up (partial zflake-s9n-cmds "up"))
(def zflake-dev-down (partial zflake-s9n-cmds "down"))
(def zflake-dev-status (partial zflake-s9n-cmds "status"))

(defn zflake-dev
  [[a1 & rest :as all]]
  (case a1
    ("u" "up" ":u" ":up") (zflake-dev-up rest)
    ("d" "down" ":d" ":down") (zflake-dev-down rest)
    ("s" "status" ":s" ":status") (zflake-dev-status rest)
    (zflake-dev-status all)))

(defn zflake-run [[a1 & rest]] (apply sh-v "nix" "run" (str ".#" a1) "--" rest))

(defn zflake
  [[a1 & rest :as all]]
  (case a1
    ("d" "dev" ":d" ":dev") (zflake-dev rest)
    ("r" "run" ":r" ":run") (zflake-run rest)
    (zflake-run all)))

(defn -main
  [s9n-bin bash-bin & args]
  (binding [*s9n-bin* s9n-bin *bash-bin* bash-bin] (zflake args))
  (shutdown-agents))
