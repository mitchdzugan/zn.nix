(ns wait-for.core
  (:require [clojure.core.async :as a]
            [clojure.set]
            [babashka.fs :as fs]
            [babashka.process :refer [shell]]
            [cheshire.core :as json]
            [clojure.walk :as walk]
            [clojure.string :as str]
            [jansi-clj.core :as jansi]
            [z.spinner :as spinner]
            [z.spinner.worm :as worm])
  (:import (org.jline.reader LineReader LineReaderBuilder)
           (org.jline.reader.impl LineReaderImpl)
           (org.jline.terminal Terminal TerminalBuilder))
  (:gen-class))
(set! *warn-on-reflection* true)

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

(defn lrb-terminal [^LineReaderBuilder lrb ^Terminal t] (.terminal lrb t))
(defn tb-system-true [^TerminalBuilder tb] (.system tb true))
(defn tb-build [^TerminalBuilder tb] (.build tb))
(defn lrb-build [^LineReaderBuilder lrb] (.build lrb))

(defn enter-raw-mode [^Terminal t] (.enterRawMode t))
(defn read-character [^LineReaderImpl lr] (.readCharacter lr))

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
                                               (spinner/styled %1)))]
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
                 (loop [spinner (spinner/pre-style worm/spinner)]
                   (out spinner)
                   (let [[v c] (a/alts! [tc vc])]
                     (if (= c vc)
                       (do (out (if v :done :err)) v)
                       (recur (spinner/step spinner)))))))))

(defn -main [& args]
  (wait-for {:name "nrepl"
             :shtest ["test" "-f" ".nrepl-port"]})
  (shutdown-agents))
