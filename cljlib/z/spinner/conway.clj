(ns z.spinner.conway (:require [z.unicode :as u]))

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

(defn board-shape [board] (-> board meta :dim))

(defn posision-shift
  [[w h] i [sx sy]]
  (let [x (mod i w)
        y (quot i w)
        x' (+ x sx)
        y' (+ y sy)
        x' (if (< x' 0)  (+ w x')   x')
        x' (if (>= x' w) (mod x' w) x')
        y' (if (< y' 0)  (+ h y')   y')
        y' (if (>= y' h) (mod y' h) y')]
    (+ x' (* w y'))))

(defn neighbours
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

(def gol-w 14)
(def gol-h 12)
(def gol-pad 4)
(def gol-board (atom (board gol-w gol-h 40)))
(def gol-pos #(+ (+ %1 gol-pad) (* (+ %2 gol-pad) gol-w)))

(defn gol-view [b]
  (let [gol? #(= :x (nth b (gol-pos %1 %2)))
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

(def empty-view
  [(get u/vec-by-block-sextant " ")
   (get u/vec-by-block-sextant " ")
   (get u/vec-by-block-sextant " ")])

(defn step [b]
  (let [rng-int #(int (* (rand) %1))
        rng-offsetter #(let [off (rng-int %1)] (fn [base] (+ base off)))
        gol-swap #(if (= :x %1) :_ :x)
        m (meta b)
        pre-view (gol-view b)
        post-trans (transition b)
        post-view (gol-view post-trans)]
    (cond
      (= post-view empty-view)
      (let [glide-x (rng-offsetter 4)
            ship-x (rng-offsetter 5)
            ship-y (rng-offsetter 2)]
        (-> (->> [[(glide-x -1) -2]
                  [(glide-x  0) -1]
                  [(glide-x  0) 0]
                  [(glide-x -1) 0]
                  [(glide-x -2) 0]
                  [(ship-x 5) (ship-y 3)]
                  [(ship-x 5) (ship-y 2)]
                  [(ship-x 5) (ship-y 1)]
                  [(ship-x 6) (ship-y 3)]
                  [(ship-x 6) (ship-y 0)]
                  [(ship-x 7) (ship-y 3)]
                  [(ship-x 8) (ship-y 2)]
                  [(ship-x 8) (ship-y 0)]]
                (map #(apply gol-pos %1))
                (reduce #(assoc %1 %2 :x) post-trans))
            (with-meta m)))

      (= pre-view post-view)
      (let [rng-pos (gol-pos (rng-int 6) (rng-int 3))]
        (with-meta (update post-trans rng-pos gol-swap) m))

      :else post-trans)))

(defn styled [b]
  (let [[f1 f2 f3] (gol-view b)]
    [[(get u/block-sextant-by-vec f1) :b :yellow]
     [(get u/block-sextant-by-vec f2) :b :yellow]
     [(get u/block-sextant-by-vec f3) :b :yellow]]))

(def spinner {:state (board gol-w gol-h 40) :step step :styled styled})
