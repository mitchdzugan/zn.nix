(ns wait-for.core
  (:require [clojure.core.async :as a]
            [clojure.set]
            [babashka.fs :as fs]
            [babashka.process :refer [shell]]
            [cheshire.core :as json]
            [clojure.walk :as walk]
            [clojure.string :as str]
            [jansi-clj.core :as jansi])
  (:import (org.jline.reader LineReader LineReaderBuilder)
           (org.jline.reader.impl LineReaderImpl)
           (org.jline.terminal Terminal TerminalBuilder))
  (:gen-class))
(set! *warn-on-reflection* true)

(defn board
  ([width height]
   (board width height 0))
  ([width height pct-alive]
   (let [n-alive (* width height pct-alive 1/100)
         n-dead  (- (* width height) n-alive)]
     (with-meta
       (->> (concat (repeat n-alive :x) (repeat n-dead :_))
          (shuffle)
          (apply vector))
       {:dim [width height]}))))

(defn board-shape
  [board]
  (-> board meta :dim))

(defn posision-shift
  [[w h] i [sx sy]]
  (let [x (mod i w)
        y (quot i w)
        x' (+ x sx)
        y' (+ y sy)
        ;; wrapping
        x' (if (< x' 0)  (+ w x')   x')
        x' (if (>= x' w) (mod x' w) x')
        y' (if (< y' 0)  (+ h y')   y')
        y' (if (>= y' h) (mod y' h) y')]
    (+ x' (* w y'))))

(defn neighbours
  "given a board and linear positions it return the "
  [board i]
  (let [dim (board-shape board)
        loc (partial posision-shift dim i)]
    (map (partial get board)
         [(loc [-1 -1]) (loc [0 -1]) (loc [+1 -1])
          (loc [-1 0])    #_i        (loc [+1 0])
          (loc [-1 +1]) (loc [0 +1]) (loc [+1 +1])])))

(defn cell-transition
  [board cell-index]
  (let [nbr       (neighbours board cell-index)
        num-alive (->> nbr (filter #(= % :x)) count)
        cell      (get board cell-index)]
    (case num-alive
        2 cell
        3 :x
        :_)))

(defn transition
  [board]
  (with-meta
    (mapv (partial cell-transition board) (range (count board)))
    (meta board)))


(defn display
  [board & {:keys [live empty sep]
            :or {live ":x" empty ":_" sep " "}}]
  (let [[w h] (board-shape board)
        fmt {:_ empty
             :x live}]
    (->> board
       (map fmt)
       (partition w)
       (map (partial str/join sep))
       (str/join "\n"))))

(defn run-gol
  []
  (loop [b (board 24 12 50)]
    (println b)
    (println "--------")
    (println (display b :live "#" :empty " " :sep ""))
    ; (Thread/sleep 1000)
    (recur (transition b)))
  (System/exit 0))

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

(defn re-println
  [& args]
  (print (jansi/erase-line))
  (print (jansi/cursor-up 1))
  (print (jansi/erase-line))
  (apply println args))

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
(def gol-w 14)
(def gol-h 12)
(def gol-pad 4)
(def gol-board (atom (board gol-w gol-h 40)))
(def gol-pos #(+ (+ %1 gol-pad) (* (+ %2 gol-pad) gol-w)))

(defn gol-view []
  (let [b @gol-board
        gol? #(= :x (nth b (gol-pos %1 %2)))
        f1 [(gol? 0 0) (gol? 1 0)
            (gol? 0 1) (gol? 1 1)
            (gol? 0 2) (gol? 1 2)]
        f2 [(gol? 2 0) (gol? 3 0)
            (gol? 2 1) (gol? 3 1)
            (gol? 2 2) (gol? 3 2)]
        f3 [(gol? 4 0) (gol? 5 0)
            (gol? 4 1) (gol? 5 1)
            (gol? 4 2) (gol? 5 2)]]
    [f1 f2 f3]))

(defn transition! []
  (let [gol-swap #(if (= :x %1) :_ :x)
        m (meta @gol-board)
        pre-view (gol-view)]
    (swap! gol-board transition)
    (let [post-view (gol-view)]
      (when (= pre-view post-view)
        (let [rng-int #(int (* (rand) %1))
              rng-pos (gol-pos (rng-int 6) (rng-int 3))]
          (swap! gol-board #(with-meta (update %1 rng-pos gol-swap) m)))))))

(defn next-loading-str-gol []
  (transition!)
  (let [[f1 f2 f3] (gol-view)]
    [[(get by-vec f1) :b :yellow]
     [(get by-vec f2) :b :yellow]
     [(get by-vec f3) :b :yellow]]))

(defn dir-opp [d] (if (= d :clock) :counter :clock))
(defn loader-next [l] (update l :state (:next l)))
(defn loader-styled [l] ((:styled l) (:state l)))
(def next-clock
  {[0 0] [1 0]
   [1 0] [2 0]
   [2 0] [3 0]
   [3 0] [4 0]
   [4 0] [5 0]
   [5 0] [5 1]
   [5 1] [5 2]
   [5 2] [4 2]
   [4 2] [3 2]
   [3 2] [2 2]
   [2 2] [1 2]
   [1 2] [0 2]
   [0 2] [0 1]
   [0 1] [0 0]})
(def next-counter
  (reduce #(assoc %1 (get next-clock %2) %2) {} (keys next-clock)))

(defn vpath-of [[x y]] [(quot x 2) (+ (mod x 2) (* 2 y))])

(defn get-next-pos [dir pos]
  (get (if (= dir :clock) next-clock next-counter) pos))

; spawn :counter [0 1]
; spawn :clock [5 1]

(defn loader-worm-styled [{:keys [dir pos size droplet]}]
   (let [vinit (get by-bc " ")
         basevs [vinit vinit vinit]
         clock? (= dir :clock)
         color-for #(if (= :clock %1) :magenta :cyan)
         hit? (= :hit droplet)
         color-out-dir ((if hit? dir-opp identity) dir)
         color-in-dir ((if (or (nil? droplet) hit?)
                         identity dir-opp) dir)
         color-out (color-for color-out-dir)
         color-in (color-for color-in-dir)
         paints-from-droplet (case droplet
                               :spawn [[(if clock? 3 2) 0]]
                               :fall [[(if clock? 3 2) 1]]
                               [])
         paints (->> (range size)
                     (reduce (fn [{:keys [res curr]} _]
                               {:curr (get-next-pos (dir-opp dir) curr)
                                :res (conj res curr)})
                             {:res paints-from-droplet :curr pos})
                     :res)
         chars (->> paints
                    (map vpath-of)
                    (reduce #(assoc-in %1 %2 true) basevs))]
   [[(get by-vec (nth chars 0)) :b color-out]
    [(get by-vec (nth chars 1)) :b color-in]
    [(get by-vec (nth chars 2)) :b color-out]]))

(def loader-worm
  {:state {:dir :counter :pos [0 0] :size 0 :droplet nil}
   :next (fn [{:keys [dir pos size droplet initial-pos did-loop?]}]
           (let [works-every-time? (< (rand) 0.6)
                 next-dir (if (and (= droplet :fall)
                                   (or (and (= dir :counter) (= pos [1 2]))
                                       (and (= dir :clock) (= pos [4 2]))))
                            (dir-opp dir)
                            dir)
                 next-pos (if (= dir next-dir)
                           (get-next-pos dir pos)
                           (reduce (fn [p _] (get-next-pos next-dir p))
                                   pos
                                   (range (dec (dec size)))))
                 next-size (min 4 (inc size))
                 next-droplet (case droplet
                                :spawn :fall
                                :fall :hit
                                :hit nil
                                (if (and did-loop?
                                         works-every-time?
                                         (> size 1)
                                         (or (and (= dir :counter) (= pos [0 1]))
                                             (and (= dir :clock) (= pos [5 1]))))
                                  :spawn
                                  nil))
                 next-initial-pos (cond
                                    (nil? initial-pos) pos
                                    (= next-dir dir) initial-pos
                                    :else nil)
                 next-did-loop? (or did-loop? (= pos initial-pos))
                 next-state {:dir next-dir
                             :pos next-pos
                             :size next-size
                             :droplet next-droplet
                             :initial-pos next-initial-pos
                             :did-loop? next-did-loop?}]
             (assoc next-state :styles (loader-worm-styled next-state))))
   :styled (fn [{:keys [styles]}] styles)})

(defn lrb-terminal [^LineReaderBuilder lrb ^Terminal t] (.terminal lrb t))
(defn tb-system-true [^TerminalBuilder tb] (.system tb true))
(defn tb-build [^TerminalBuilder tb] (.build tb))
(defn lrb-build [^LineReaderBuilder lrb] (.build lrb))

(defn enter-raw-mode [^Terminal t] (.enterRawMode t))
(defn read-character [^LineReaderImpl lr] (.readCharacter lr))

"q pressed: * not ready"
"   * ready - enjoy :^)"
"waiting for *"
"  "
(defn wait-for [{:keys [name shtest]}]
  (let [tstyles {:err  [[" " :i :cyan] ["✖" :b :red  ] [" " :i :magenta]]
                 :done [[" " :i :cyan] ["✔" :b :green] [" " :i :magenta]]}
        out #(re-println
                (colorize [(apply colorize
                                 (case %1
                                   :err [["q" :b :yellow]
                                         [" press: "]
                                         [name :b :blue]
                                         [" is not up "]]
                                   :done [[name :b :blue]
                                          [" now up - enjoy"]
                                          [" :^) " :b :yellow-bright]]
                                   [["       waiting for"]
                                    [(str " " name " ") :b :blue]]))]
                          ["[" :b :black-bright]
                          [(apply colorize (or (get tstyles %1)
                                               (loader-styled %1)))]
                          ["]" :b :black-bright]
                          [(apply colorize (if (#{:err :done} %1)
                                             []
                                             [[" press "]
                                              ["q" :b :yellow]
                                              [" to quit waiting"]]))]))
        done? (atom false)
        tc (a/chan)
        vc (a/chan)]
    (a/go (while (not @done?) (Thread/sleep 50) (a/>! tc true)))
    (a/go
      (let [terminal (-> (TerminalBuilder/builder) tb-system-true tb-build)]
        (enter-raw-mode terminal)
        (let [reader (-> (LineReaderBuilder/builder)
                         (lrb-terminal terminal)
                         lrb-build)]
          (loop [] (when-not (= 113 (read-character reader)) (recur)))
          (a/>! vc false))))
    (a/go
      (loop []
        (let [succ? (try (apply shell shtest) true
                         (catch Exception _ (Thread/sleep 500) false))]
          (when-not succ? (recur))))
      (a/>! vc true)
      (reset! done? true))
    (a/<!! (a/go (println)
                 (loop [loader (loader-next loader-worm)]
                   (out loader)
                   (let [[v c] (a/alts! [tc vc])]
                     (if (= c vc)
                       (do (out (if v :done :err)) v)
                       (recur (loader-next loader)))))))))

(defn -main [& args]
  (wait-for {:name "nrepl"
             :shtest ["test" "-f" ".nrepl-port"]})
  (shutdown-agents))
