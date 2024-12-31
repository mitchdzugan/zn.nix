(ns zflake.core
  (:require [clojure.core.async :as a]
            [babashka.fs :as fs]
            [babashka.process :refer [shell]]
            [cheshire.core :as json]
            [clojure.walk :as walk]
            [clojure.string :as str]
            [jansi-clj.core :as jansi])
  (:gen-class))
(set! *warn-on-reflection* true)

(def ^:dynamic *s9n-bin* nil)
(def ^:dynamic *bash-bin* nil)

(def jansi-map
  {:black jansi/black
   :red jansi/red
   :yellow jansi/yellow
   :green jansi/green
   :blue jansi/blue
   :magenta jansi/magenta
   :cyan jansi/cyan
   :white jansi/white
   :black-bright jansi/black-bright
   :red-bright jansi/red-bright
   :yellow-bright jansi/yellow-bright
   :green-bright jansi/green-bright
   :blue-bright jansi/blue-bright
   :magenta-bright jansi/magenta-bright
   :cyan-bright jansi/cyan-bright
   :white-bright jansi/white-bright
   :b jansi/bold
   :i jansi/italic})

(defn colorize
  [& sections]
  (->> sections
    (map (fn [[s & styles]] (reduce #((get jansi-map %2) %1) s styles)))
    (str/join "")))

(defn sh-v
  [& cmd]
  (->> [["⦗" :b :black-bright] ["zflake/" :b :yellow-bright]
        ["exec" :b :magenta-bright] ["⦘" :b :black-bright]
        [": " :b :black-bright] [(str/join " " cmd) :green]]
    (apply colorize)
    println)
  (apply shell cmd))

(defn once
  [f]
  (let [state (atom [])]
    (fn []
      (if-not (empty? @state)
        (first @state)
        (let [res (f)]
          (reset! state [res])
          res)))))

(defmacro defn-once
  [name & rest]
  {:clj-kondo/lint-as 'clojure.core/def}
  `(def ~name (once (fn [] ~@rest))))

(defn-once
  get-nix-system
  (-> {:out :string :err :string}
    (shell "nix" "eval" "--impure" "--raw" "--expr" "builtins.currentSystem")
    :out
    (try (catch Exception _ nil))))

(defn re-println
  [& args]
  (print (jansi/erase-line))
  (print (jansi/cursor-up 1))
  (print (jansi/erase-line))
  (apply println args))

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
    (-> {:out :string :err :string}
      (shell "nix" "eval" "--impure" "--json" "--expr" n)
      :out
      json/parse-string
      (update "singletons"
              (->> (fn [s9n]
                     (merge (walk/keywordize-keys s9n)
                            {:runsh (str "nix run .#" (get s9n "taskname"))
                             :execd (str (fs/cwd))}))
                (partial map)))
      (try (catch Exception e (println e) {})))))

(def t true)
(def f false)
(def bpairs
  [[[f f f f f f] " "]
   [[t f f f f f] "🬀"]
   [[f t f f f f] "🬁"]
   [[t t f f f f] "🬂"]
   [[f f t f f f] "🬃"]
   [[t f t f f f] "🬄"]
   [[f t t f f f] "🬅"]
   [[t t t f f f] "🬆"]
   [[f f f t f f] "🬇"]
   [[t f f t f f] "🬈"]
   [[f t f t f f] "🬉"]
   [[t t f t f f] "🬊"]
   [[f f t t f f] "🬋"]
   [[t f t t f f] "🬌"]
   [[f t t t f f] "🬍"]
   [[t t t t f f] "🬎"]
   [[f f f f t f] "🬏"]
   [[t f f f t f] "🬐"]
   [[f t f f t f] "🬑"]
   [[t t f f t f] "🬒"]
   [[f f t f t f] "🬓"]
   [[t f t f t f] "▌"]
   [[f t t f t f] "🬔"]
   [[t t t f t f] "🬕"]
   [[f f f t t f] "🬖"]
   [[t f f t t f] "🬗"]
   [[f t f t t f] "🬘"]
   [[t t f t t f] "🬙"]
   [[f f t t t f] "🬚"]
   [[t f t t t f] "🬛"]
   [[f t t t t f] "🬜"]
   [[t t t t t f] "🬝"]
   [[f f f f f t] "🬞"]
   [[t f f f f t] "🬟"]
   [[f t f f f t] "🬠"]
   [[t t f f f t] "🬡"]
   [[f f t f f t] "🬢"]
   [[t f t f f t] "🬣"]
   [[f t t f f t] "🬤"]
   [[t t t f f t] "🬥"]
   [[f f f t f t] "🬦"]
   [[t f f t f t] "🬧"]
   [[f t f t f t] "▐"]
   [[t t f t f t] "🬨"]
   [[f f t t f t] "🬩"]
   [[t f t t f t] "🬪"]
   [[f t t t f t] "🬫"]
   [[t t t t f t] "🬬"]
   [[f f f f t t] "🬭"]
   [[t f f f t t] "🬮"]
   [[f t f f t t] "🬯"]
   [[t t f f t t] "🬰"]
   [[f f t f t t] "🬱"]
   [[t f t f t t] "🬲"]
   [[f t t f t t] "🬳"]
   [[t t t f t t] "🬴"]
   [[f f f t t t] "🬵"]
   [[t f f t t t] "🬶"]
   [[f t f t t t] "🬷"]
   [[t t f t t t] "🬸"]
   [[f f t t t t] "🬹"]
   [[t f t t t t] "🬺"]
   [[f t t t t t] "🬻"]
   [[t t t t t t] "█"]])

(def by-vec (into {} bpairs))
(def by-bc (into {} (map #(into [] (reverse %1)) bpairs)))

(defn rand-b [] (< (rand) 0.5))
(defn next-loading-str [[e1 e2 e3]]
  (let [c1 (nth e1 0)
        c2 (nth e2 0)
        c3 (nth e3 0)
        v1 (get by-bc c1)
        v2 (get by-bc c2)
        v3 (get by-bc c3)
        f1 [(nth v1 1) (nth v2 0)
            (nth v1 3) (nth v2 2)
            (nth v1 5) (nth v2 4)]
        f2v (rand-b)
        f2y (rand-b)
        f2 [(not f2y) f2v
            (not (nth v2 3)) (not (nth v2 3))
            (not f2v) f2y]
        f3 [(nth v2 1) (nth v3 0)
            (nth v2 3) (nth v3 2)
            (nth v2 5) (nth v3 4)]]
    [(assoc e1 0 (get by-vec f1))
     (assoc e2 0 (get by-vec f2))
     (assoc e3 0 (get by-vec f3))]))

(def next-loading
  ((fn []
     (let [end? #(= 0 (+ (* %1 %1) (* -3 %1) 2))
           lsyms
             [{:c " " :l 9 :r 0 :inv? false} {:c "🬼" :l 1 :r 0 :inv? false}
              {:c "🬽" :l 1 :r 0 :inv? false} {:c "🬾" :l 2 :r 0 :inv? false}
              {:c "🬿" :l 2 :r 0 :inv? false} {:c "🭀" :l 3 :r 0 :inv? false}
              {:c "🭁" :l 2 :r 3 :inv? false} {:c "🭂" :l 2 :r 3 :inv? false}
              {:c "🭃" :l 1 :r 3 :inv? false} {:c "🭄" :l 1 :r 3 :inv? false}
              {:c "🭅" :l 0 :r 3 :inv? false} {:c "🭆" :l 1 :r 2 :inv? false}
              {:c "🭇" :l 0 :r 1 :inv? false} {:c "🭈" :l 0 :r 1 :inv? false}
              {:c "🭉" :l 0 :r 2 :inv? false} {:c "🭊" :l 0 :r 2 :inv? false}
              {:c "🭋" :l 0 :r 3 :inv? false} {:c "🭌" :l 3 :r 2 :inv? false}
              {:c "🭍" :l 3 :r 2 :inv? false} {:c "🭎" :l 3 :r 1 :inv? false}
              {:c "🭏" :l 3 :r 1 :inv? false} {:c "🭐" :l 3 :r 0 :inv? false}
              {:c "🭑" :l 3 :r 1 :inv? false} {:c "🭒" :l 2 :r 3 :inv? true}
              {:c "🭓" :l 2 :r 3 :inv? true} {:c "🭔" :l 1 :r 3 :inv? true}
              {:c "🭕" :l 1 :r 3 :inv? true} {:c "🭖" :l 0 :r 3 :inv? true}
              {:c "🭗" :l 1 :r 0 :inv? true} {:c "🭘" :l 1 :r 0 :inv? true}
              {:c "🭙" :l 2 :r 0 :inv? true} {:c "🭚" :l 2 :r 0 :inv? true}
              {:c "🭛" :l 3 :r 0 :inv? true} {:c "🭜" :l 2 :r 1 :inv? true}
              {:c "🭝" :l 3 :r 2 :inv? true} {:c "🭞" :l 3 :r 2 :inv? true}
              {:c "🭟" :l 3 :r 1 :inv? true} {:c "🭠" :l 3 :r 1 :inv? true}
              {:c "🭡" :l 3 :r 0 :inv? true} {:c "🭢" :l 0 :r 1 :inv? true}
              {:c "🭣" :l 0 :r 1 :inv? true} {:c "🭤" :l 0 :r 2 :inv? true}
              {:c "🭥" :l 0 :r 2 :inv? true} {:c "🭦" :l 0 :r 3 :inv? true}
              {:c "🭧" :l 1 :r 3 :inv? true}]
           get-next-by-c
             (->> lsyms
               (map (fn [{:keys [c r inv?]}]
                      (let [legal (-> #(and (= r (:l %1))
                                            (or (= inv? (:inv? %1)) (end? r)))
                                    (filter lsyms))
                            lkup (->> legal (map :c) (into []))
                            num (count lkup)]
                        [c (fn [] (nth lkup (int (* (rand) num))))])))
               (into {}))
            get-next-by-c {" " #(-> "🮕")
                           "🮕" #(-> "🮖")
                           "🮖" #(-> "🮘")
                           "🮘" #(-> "🮙")
                           "🮙" #(-> "🮕")
                           }]
       (fn [curr] ((get get-next-by-c curr #(-> " "))))))))

(defn-once
  get-zflake-dev
  (let [s* (atom {0 [[" " :b :yellow]
                     ["🬋" :b :yellow]
                     [" " :b :yellow]]
                  :done [["🭪" :i :yellow] ["✔" :b :green] ["🭨" :i :yellow]]})
        -impl (fn [k]
                (next-loading-str (get @s* (dec k)))
                #_(let [[_ a b] (get @s* (dec k))]
                  [a b (update b 0 next-loading)]))
        styled #(let [r (or (get @s* %1) (-impl %1))]
                  (swap! s* assoc %1 r)
                  r)
        out #((if %1 re-println println)
                (colorize ["⦗" :b :black-bright]
                          ["zflake" :b :yellow-bright]
                          ["⦘" :b :black-bright]
                          [" retreiving nix data "]
                          ["[" :b :black-bright]
                          [(apply colorize (styled %2))]
                          ["]" :b :black-bright]))
        done? (atom false)
        tc (a/chan)
        vc (a/chan)]
    (a/go (while (not @done?) (Thread/sleep 120) (a/>! tc true)))
    (a/go (a/>! vc (get-zflake-dev-impl)) (reset! done? true))
    (a/<!! (a/go (out false 0)
                 (loop [i 1]
                   (out true i)
                   (let [[v c] (a/alts! [tc vc])]
                     (if (= c vc) (do (out true :done) v) (recur (inc i)))))))))

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
