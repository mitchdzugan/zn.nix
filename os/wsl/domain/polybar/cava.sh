# "%{u#0022ff}%{+u}%{F#0022ff}▁%{F-}%{-u}" \
bars=( \
    "%{u#_C_A_}%{+u}%{F#_C_A_} %{F-}%{-u}" \
    "%{u#_C_A_}%{+u}%{F#_C_B_}▁%{F-}%{-u}" \
    "%{u#_C_B_}%{+u}%{F#_C_C_}▂%{F-}%{-u}" \
    "%{u#_C_C_}%{+u}%{F#_C_D_}▃%{F-}%{-u}" \
    "%{u#_C_D_}%{+u}%{F#_C_E_}▄%{F-}%{-u}" \
    "%{u#_C_E_}%{+u}%{F#_C_F_}▅%{F-}%{-u}" \
    "%{u#_C_F_}%{+u}%{F#_C_G_}▆%{F-}%{-u}" \
    "%{u#_C_G_}%{+u}%{F#_C_H_}▇%{F-}%{-u}" \
    "%{u#_C_H_}%{+u}%{F#_C_H_}█%{F-}%{-u}" \
)
dict="s/;//g;"
cdict="s/_C_A_/735cb8/g;s/_C_B_/8a5cb8/g;s/_C_C_/a15cb8/g;s/_C_D_/b85cb8/g;s/_C_E_/b85ca1/g;s/_C_F_/b85c8a/g;s/_C_G_/b85c73/g;s/_C_H_/b85c5c/g;"

# creating "dictionary" to replace char with bar
for i in "${!bars[@]}"; do
    dict="${dict}s/$i/${bars[$i]}/g;"
done

# write cava config
config_file="/tmp/polybar_cava_config"
echo "
[general]
bars = 25

[input]
method = pulse
source = auto

[output]
channels = mono
mono_option = average
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 8
" > $config_file

# read stdout from cava
cava -p $config_file | while read -r line; do
    echo "$line" | sed "$dict" | sed "$cdict"
done
