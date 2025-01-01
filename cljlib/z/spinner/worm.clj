(ns z.spinner.worm (:require [z.unicode :as u]))

(defn dir-opp [d] (if (= d :clock) :counter :clock))
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

(defn styled [{:keys [dir pos size droplet]}]
   (let [vinit (get u/vec-by-block-sextant " ")
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
   [[(get u/block-sextant-by-vec (nth chars 0)) :b color-out]
    [(get u/block-sextant-by-vec (nth chars 1)) :b color-in]
    [(get u/block-sextant-by-vec (nth chars 2)) :b color-out]]))

(defn step
  [{:keys [dir pos size droplet initial-pos did-loop?]}]
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
        next-did-loop? (or did-loop? (= pos initial-pos))]
   {:dir next-dir
    :pos next-pos
    :size next-size
    :droplet next-droplet
    :initial-pos next-initial-pos
    :did-loop? next-did-loop?}))

(def initial-state {:dir :counter :pos [0 0] :size 0 :droplet nil})

(def spinner {:state initial-state :step step :styled styled})
