(ns z.util)

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
