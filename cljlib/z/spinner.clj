(ns z.spinner)

(defn step [l] (update l :state (:step l)))
(defn styled [l] ((:styled l) (:state l)))
(defn pre-style [l]
  {:state {:loader l :styled (styled l)}
   :step #(let [next-loader (step (:loader %))]
            {:loader next-loader :styled (styled next-loader)})
   :styled :styled})
