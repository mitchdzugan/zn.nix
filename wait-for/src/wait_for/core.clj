(ns wait-for.core
  (:require [clojure.core.async :as a]
            [clojure.set]
            [babashka.cli :as cli]
            [babashka.process :refer [shell]]
            [z.spinner :as spinner]
            [z.spinner.worm :as worm]
            [z.style :as st])
  (:import (org.jline.reader LineReaderBuilder)
           (org.jline.reader.impl LineReaderImpl)
           (org.jline.terminal Terminal TerminalBuilder))
  (:gen-class))
(set! *warn-on-reflection* true)

(defn lrb-terminal [^LineReaderBuilder lrb ^Terminal t] (.terminal lrb t))
(defn tb-system-true [^TerminalBuilder tb] (.system tb true))
(defn tb-build [^TerminalBuilder tb] (.build tb))
(defn lrb-build [^LineReaderBuilder lrb] (.build lrb))

(defn enter-raw-mode [^Terminal t] (.enterRawMode t))
(defn read-character [^LineReaderImpl lr] (.readCharacter lr))

(defn wait-for [{:keys [name shtest]}]
  (let [tstyles {:err  [[" " :i :cyan] ["✖" :b :red  ] [" " :i :magenta]]
                 :done [[" " :i :cyan] ["✔" :b :green] [" " :i :magenta]]}
        out #(st/re-println
                (st/%** ["  waiting for"]
                        [(str " " name " ") :b :blue]
                        ["[" :b :black-bright]
                        [(st/%* (or (get tstyles %1) (spinner/styled %1)))]
                        ["] " :b :black-bright]
                        [(st/%* (case %1
                                  :err [["q" :b :yellow]
                                        [" press: "]
                                        [name :b :blue]
                                        [" is not up "]]
                                  :done [[name :b :blue]
                                         [" now up - enjoy"]
                                         [" :^) " :b :yellow-bright]]
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

(defn -main [& cli-args]
  (let [{:keys [args opts]} (cli/parse-args cli-args {:alias {:n :name}
                                                      :require [:name]})]
   (wait-for {:name (:name opts) :shtest args}))
  (shutdown-agents))
