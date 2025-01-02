(ns z.style
  (:require [clojure.string :as str]
            [jansi-clj.core :as jansi]))

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

(defn %*
  [sections]
  (->>
    sections
    (map (fn [[s & styles]] (reduce #((get jansi-map %2) %1) s styles)))
    (str/join "")))

(defn %** [& args] (%* args))

(defn re-println
  [& args]
  (print (jansi/erase-line))
  (print (jansi/cursor-up 1))
  (print (jansi/erase-line))
  (apply println args))
