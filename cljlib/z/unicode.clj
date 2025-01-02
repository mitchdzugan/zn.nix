(ns z.unicode)

(def t true)
(def f false)
(def block-sextant-pairs
  [[[f f f f f f] " "] [[t f f f f f] "🬀"] [[f t f f f f] "🬁"]
   [[t t f f f f] "🬂"] [[f f t f f f] "🬃"] [[t f t f f f] "🬄"]
   [[f t t f f f] "🬅"] [[t t t f f f] "🬆"] [[f f f t f f] "🬇"]
   [[t f f t f f] "🬈"] [[f t f t f f] "🬉"] [[t t f t f f] "🬊"]
   [[f f t t f f] "🬋"] [[t f t t f f] "🬌"] [[f t t t f f] "🬍"]
   [[t t t t f f] "🬎"] [[f f f f t f] "🬏"] [[t f f f t f] "🬐"]
   [[f t f f t f] "🬑"] [[t t f f t f] "🬒"] [[f f t f t f] "🬓"]
   [[t f t f t f] "▌"] [[f t t f t f] "🬔"] [[t t t f t f] "🬕"]
   [[f f f t t f] "🬖"] [[t f f t t f] "🬗"] [[f t f t t f] "🬘"]
   [[t t f t t f] "🬙"] [[f f t t t f] "🬚"] [[t f t t t f] "🬛"]
   [[f t t t t f] "🬜"] [[t t t t t f] "🬝"] [[f f f f f t] "🬞"]
   [[t f f f f t] "🬟"] [[f t f f f t] "🬠"] [[t t f f f t] "🬡"]
   [[f f t f f t] "🬢"] [[t f t f f t] "🬣"] [[f t t f f t] "🬤"]
   [[t t t f f t] "🬥"] [[f f f t f t] "🬦"] [[t f f t f t] "🬧"]
   [[f t f t f t] "▐"] [[t t f t f t] "🬨"] [[f f t t f t] "🬩"]
   [[t f t t f t] "🬪"] [[f t t t f t] "🬫"] [[t t t t f t] "🬬"]
   [[f f f f t t] "🬭"] [[t f f f t t] "🬮"] [[f t f f t t] "🬯"]
   [[t t f f t t] "🬰"] [[f f t f t t] "🬱"] [[t f t f t t] "🬲"]
   [[f t t f t t] "🬳"] [[t t t f t t] "🬴"] [[f f f t t t] "🬵"]
   [[t f f t t t] "🬶"] [[f t f t t t] "🬷"] [[t t f t t t] "🬸"]
   [[f f t t t t] "🬹"] [[t f t t t t] "🬺"] [[f t t t t t] "🬻"]
   [[t t t t t t] "█"]])

(def block-sextant-by-vec (into {} block-sextant-pairs))
(def vec-by-block-sextant
  (into {} (map #(into [] (reverse %1)) block-sextant-pairs)))

(def block-diaganol-specs
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
   {:c "🭧" :l 1 :r 3 :inv? true}])
