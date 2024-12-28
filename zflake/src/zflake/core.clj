(ns zflake.core
  (:require [babashka.fs :as fs]
            [babashka.process :refer [shell]]
            [cheshire.core :as json]
            [clojure.walk :as walk]
            [clojure.string :as str]
            [jansi-clj.core :as jansi])
  (:gen-class))
(set! *warn-on-reflection* true)

(def ^:dynamic *s9n-bin* nil)
(def ^:dynamic *bash-bin* nil)

(def jansi-map {:black jansi/black
                :black-bright jansi/black-bright
                :white-bright jansi/white-bright
                :yellow jansi/yellow
                :yellow-bright jansi/yellow-bright
                :magenta-bright jansi/magenta-bright
                :cyan-bright jansi/cyan-bright
                :magenta jansi/magenta
                :cyan jansi/cyan
                :green jansi/green
                :red jansi/red
                :b jansi/bold
                :i jansi/italic})

(defn colorize [& sections]
  (->> sections
       (map (fn [[s & styles]] (reduce #((get jansi-map %2) %1) s styles)))
       (str/join "")))

(defn sh-v [& cmd]
  (->> [["⦗" :b :black-bright]
        ["zflake/" :b :yellow-bright]
        ["exec" :b :magenta-bright]
        ["⦘" :b :black-bright]
        [": " :b :black-bright]
        [(str/join " " cmd) :green]]
       (apply colorize)
       println)
  (apply shell cmd))

(defn once [f]
  (let [state (atom [])]
    (fn []
      (if-not (empty? @state) (first @state)
        (let [res (f)]
          (reset! state [res])
          res)))))

(defmacro defn-once [name & rest]
  {:clj-kondo/lint-as 'clojure.core/def}
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
           *s9n-bin* execd taskname runsh cmd)))

(defn zflake-s9n-cmds [cmd & _]
  (get-zflake-dev)
  (let [ask-cfg #(get (get-zflake-dev) (apply str %&))]
    (shell *bash-bin* "-c" (ask-cfg "pre-" cmd))
    (doseq [s9n (ask-cfg "singletons")] (zflake-s9n-cmd cmd s9n))
    (shell *bash-bin* "-c" (ask-cfg "post-" cmd))))

(def zflake-dev-up (partial zflake-s9n-cmds "up"))
(def zflake-dev-down (partial zflake-s9n-cmds "down"))
(def zflake-dev-status (partial zflake-s9n-cmds "status"))

(defn zflake-dev [[a1 & rest :as all]]
  (case a1
    ("u" "up" ":u" ":up") (zflake-dev-up rest)
    ("d" "down" ":d" ":down") (zflake-dev-down rest)
    ("s" "status" ":s" ":status") (zflake-dev-status rest)
    (zflake-dev-status all)))

(defn zflake-run [[a1 & rest]]
  (apply sh-v "nix" "run" (str ".#" a1) rest))

(defn zflake [[a1 & rest :as all]]
  (case a1
    ("d" "dev" ":d" ":dev") (zflake-dev rest)
    ("r" "run" ":r" ":run") (zflake-run rest)
    (zflake-run all)))

(defn -main [s9n-bin bash-bin & args]
  (binding [*s9n-bin* s9n-bin *bash-bin* bash-bin]
    (zflake args)) (shutdown-agents))
