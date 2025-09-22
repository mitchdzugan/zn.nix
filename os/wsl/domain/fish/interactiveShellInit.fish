#!/usr/bin/env fish

function ls
  set -l ls_bin (which ls)
  set -l cmd $ls_bin
  for arg in $argv
    if string match -r -- "^-([^-].*l|l).*" $arg >/dev/null 2>&1
      set cmd grc $ls_bin
    end
  end
  $cmd --color=always --group-directories-first -p $argv
end

function fish_greeting
  #### config
  set -l tw 38
  set -l th 20
  set -l pr 1
  set -l pt 1
  ####
  set -l pix_dims (kitten icat --print-window-size | string split x)
  set -l cw (tput cols)
  set -l ch (tput lines)
  set -l pw $pix_dims[1]
  set -l ph $pix_dims[2]
  set -l w (math "floor(38 * $pw / $cw)")
  set -l h (math "floor(20 * $ph / $ch)")
  set -l lw (math "$pr + $tw")
  set -l lh (math "$pt + $th")

  begin
    kitten icat \
      --align=left \
      --use-window-size $tw,$th,$w,$h \
      ~/.config/fastfetch/logo.nix.3.png
  end | fastfetch \
    --raw - \
    --logo-width $lw \
    --logo-height $lh \
    --separator-output-color black
end

function firsty
  set -lx tot (count $argv)
  set -lx curr $argv[1]
  set -lx rest $argv[2..]
  function on_none
    if [ $tot -lt 2 ]
      echo $curr
      return 1
    else
      firsty $rest
    end
  end
  if [ -z $curr ]
    on_none $rest
  else if [ "$curr" = "0" ]
    on_none $rest
  else
    echo $curr
  end
end

function nixroot
  set -l base (path resolve (firsty $argv[1] (pwd)))
  set -l curr (path resolve (firsty $argv[2] $base))
  set -l next (path resolve "$curr/..")
  if [ -f "$curr/flake.nix" ]
    echo flake $curr
  else if [ -f "$curr/shell.nix" ]
    echo pkg $curr
  else if [ -f "$curr/default.nix" ]
    echo pkg $curr
  else if [ $curr != $next ]
    nixroot $base $next
  else
    echo "err@{$base is not in nix dir}" >&2
    return 1
  end
end

function zdev
  set -l wd (pwd)
  set -l nixroot_data (string split " " (nixroot))
  set -lx nixtype $nixroot_data[1]
  if [ "$status" = "0" ]
    set -l curr_depth (firsty $ZDEV_DEPTH 0)
    set -lx ZDEV_ACTIVE 1
    set -lx ZDEV_DEPTH (math 1 + $curr_depth)
    set -lx ZDEV_NIXROOT $nixroot_data[2]
    set -lx ZDEV_LABEL (basename $ZDEV_NIXROOT)
    set -lx ZDEV_ID "_"$ZDEV_DEPTH"_$(date +%s_%N)_"$fish_pid"_$(random)"
    set -l pidvar "ZDEV_PID_$ZDEV_ID"
    set -lx "$pidvar" ""
    set -lx fish_init "begin; set $pidvar (get_fish_pid); cd $wd; end"
    cd $ZDEV_NIXROOT
    clear
    function sc
      set -l txt $argv
      set -l format set_color cyan
      if string match -r -- "^-.*" $argv[1] >/dev/null 2>&1
        set txt $argv[2..]
        set format set_color $argv[1] cyan
      end
      set_color normal && set_color -b brblack && $format && echo $txt
    end
    echo (\
      sc -o " --- Entering Nix Development Shell --- " \
    )
    echo -e (\
      sc -d "   $(dirname (pwd))/" \
    )(\
      sc -o (basename (pwd)) \
    )(\
      sc " ⇽❰nixroot❱ " \
    )
    set_color normal
    function nix_fish
      if [ $nixtype = "flake" ]
        nix develop --command -- fish -C "$fish_init"
      else
        nix-shell --command "fish -C \"$fish_init\""
      end
    end
    if nix_fish
      clear
    end
    cd $wd
  else
    return 1
  end
end

function zslurp
  set -l varname $argv[1]
  read -z lines
  set $varname (string split \n -- $lines)
end

function _wrap_zssh_arg
  function wrap_host
    echo "mitch-$argv[1].local"
  end
  set -l regex "^(([a-zA-Z][a-zA-Z0-9]+)(@))?(hp|gazelle|desktop)(.*)"
  set -g matches
  string match -r $regex $argv[1] | zslurp matches
  switch (count $matches)
    case 7
      echo "$matches[3]@$(wrap_host $matches[5])$matches[6]"
    case 4
      echo "dz@$(wrap_host $matches[2])$matches[3]"
    case '*'
      return 1
  end
end

function _zssh_cmd
  set -l cmd $argv[1]
  set -l final
  for arg in $argv[2..]
    set final $final (firsty (_wrap_zssh_arg $arg) $arg)
  end
  if [ $cmd = "ssh" ]
    set final $final -t fish
  end
  echo $cmd $final
  $cmd $final
end

alias zssh="_zssh_cmd ssh"
alias zscp="_zssh_cmd scp"

function mk_vi_mode_icon
  echo "$(\
    set_color 100912 && echo "")$(\
    set_color $argv[2] && echo $argv[1])$(\
    set_color 2F1A33 && echo "")"
end

function configure_my_tide
  set -gx tide_left_prompt_items \
    zvi_mode zpb zpwd zpp
  set -gx tide_right_prompt_items \
    rich_status cmd_duration jobs git direnv node python znix rich_context zpe
  set -gx tide_aws_bg_color 1C1C1C
  set -gx tide_aws_color FF9900
  set -gx tide_aws_icon \uf270
  set -gx tide_rich_character_bg0 A85CB8
  set -gx tide_rich_character_bgX DD4444
  set -gx tide_rich_character_color0 2F1A33
  set -gx tide_rich_character_colorX 2F1A33
  set -gx tide_rich_character_char ""
  set -gx tide_character_color 5FD700
  set -gx tide_character_color_failure FF0000
  set -gx tide_character_icon \u276f
  set -gx tide_character_vi_icon_default \u276e
  set -gx tide_character_vi_icon_replace \u25b6
  set -gx tide_character_vi_icon_visual V
  set -gx tide_cmd_duration_bg_color 1C1C1C
  set -gx tide_cmd_duration_color 87875F
  set -gx tide_cmd_duration_decimals 0
  set -gx tide_cmd_duration_icon \uf252
  set -gx tide_cmd_duration_threshold 3000
  set -gx tide_rich_context_always_display true
  set -gx tide_rich_context_bg_color 2F1A33
  set -gx tide_rich_context_color_user bryellow
  set -gx tide_rich_context_color_host brwhite
  set -gx tide_rich_context_color_default brmagenta
  set -gx tide_rich_context_color_root brmagenta
  set -gx tide_rich_context_color_ssh brmagenta
  set -gx tide_rich_context_hostname_parts 1
  set -gx tide_crystal_bg_color 1C1C1C
  set -gx tide_crystal_color FFFFFF
  set -gx tide_crystal_icon \ue62f
  set -gx tide_direnv_bg_color 1C1C1C
  set -gx tide_direnv_bg_color_denied 1C1C1C
  set -gx tide_direnv_color D7AF00
  set -gx tide_direnv_color_denied FF0000
  set -gx tide_direnv_icon \u25bc
  set -gx tide_distrobox_bg_color 1C1C1C
  set -gx tide_distrobox_color FF00FF
  set -gx tide_distrobox_icon \U000f01a7
  set -gx tide_docker_bg_color 1C1C1C
  set -gx tide_docker_color 2496ED
  set -gx tide_docker_default_contexts default\x1ecolima
  set -gx tide_docker_icon \uf308
  set -gx tide_elixir_bg_color 1C1C1C
  set -gx tide_elixir_color 4E2A8E
  set -gx tide_elixir_icon \ue62d
  set -gx tide_gcloud_bg_color 1C1C1C
  set -gx tide_gcloud_color 4285F4
  set -gx tide_gcloud_icon \U000f02ad
  set -gx tide_git_bg_color 100912
  set -gx tide_git_bg_color 2B331A
  set -gx tide_git_bg_color_unstable $tide_git_bg_color
  set -gx tide_git_bg_color_urgent $tide_git_bg_color
  set -gx tide_git_color_branch 5FD700
  set -gx tide_git_color_conflicted FF0000
  set -gx tide_git_color_dirty D7AF00
  set -gx tide_git_color_operation FF0000
  set -gx tide_git_color_staged D7AF00
  set -gx tide_git_color_stash 5FD700
  set -gx tide_git_color_untracked 00AFFF
  set -gx tide_git_color_upstream 5FD700
  set -gx tide_git_icon 
  set -gx tide_git_truncation_length 24
  set -gx tide_git_truncation_strategy ""
  set -gx tide_go_bg_color 1C1C1C
  set -gx tide_go_color 00ACD7
  set -gx tide_go_icon \ue627
  set -gx tide_java_bg_color 1C1C1C
  set -gx tide_java_color ED8B00
  set -gx tide_java_icon \ue256
  set -gx tide_jobs_bg_color 1C1C1C
  set -gx tide_jobs_color 5FAF00
  set -gx tide_jobs_icon \uf013
  set -gx tide_jobs_number_threshold 1000
  set -gx tide_kubectl_bg_color 1C1C1C
  set -gx tide_kubectl_color 326CE5
  set -gx tide_kubectl_icon \U000f10fe
  set -gx tide_left_prompt_frame_enabled false
  set -gx tide_left_prompt_prefix ""
  set -gx tide_left_prompt_separator_diff_color ""
  set -gx tide_left_prompt_separator_same_color ""
  set -gx tide_left_prompt_suffix ""
  set -gx tide_znix_bg_color 1A2A32
  set -gx tide_znix_color 466880
  set -gx tide_znix_color_bright 7EBAE4
  set -gx tide_znix_icon ""
  set -gx tide_node_bg_color 1C1C1C
  set -gx tide_node_color 44883E
  set -gx tide_node_icon \ue24f
  set -gx tide_os_bg_color 1C1C1C
  set -gx tide_os_color EEEEEE
  set -gx tide_os_icon \uf313
  set -gx tide_php_bg_color 1C1C1C
  set -gx tide_php_color 617CBE
  set -gx tide_php_icon \ue608
  set -gx tide_private_mode_bg_color 1C1C1C
  set -gx tide_private_mode_color FFFFFF
  set -gx tide_private_mode_icon \U000f05f9
  set -gx tide_prompt_add_newline_before false
  set -gx tide_prompt_color_frame_and_connection 6C6C6C
  set -gx tide_prompt_color_separator_same_color 949494
  set -gx tide_prompt_icon_connection \x20
  set -gx tide_prompt_min_cols 34
  set -gx tide_prompt_pad_items false
  set -gx tide_prompt_transient_enabled false
  set -gx tide_pulumi_bg_color 1C1C1C
  set -gx tide_pulumi_color F7BF2A
  set -gx tide_pulumi_icon \uf1b2
  set -gx tide_pwd_bg_color 2F1A33
  set -gx tide_pwd_color_anchors 00AFFF
  set -gx tide_pwd_color_dirs 0087AF
  set -gx tide_pwd_color_truncated_dirs 8787AF
  set -gx tide_pwd_icon ""
  set -gx tide_pwd_icon_home ""
  set -gx tide_pwd_icon_unwritable ""
  set -gx tide_pwd_markers \
    .bzr \
    .citc \
    .git \
    .hg \
    .svn \
    .terraform \
    package.json \
    build.zig \
    duneproject \
    project.clj \
    flake.nix \
    shell.nix
  set -gx tide_python_bg_color 1C1C1C
  set -gx tide_python_color 00AFAF
  set -gx tide_python_icon \U000f0320
  set -gx tide_right_prompt_frame_enabled false
  set -gx tide_right_prompt_prefix "🭨"
  set -gx tide_right_prompt_prefix "🮔"
  set -gx tide_right_prompt_separator_diff_color "🮍🮔"
  set -gx tide_right_prompt_separator_same_color "🭦🬾"
  set -gx tide_right_prompt_suffix
  set -gx tide_ruby_bg_color 1C1C1C
  set -gx tide_ruby_color B31209
  set -gx tide_ruby_icon \ue23e
  set -gx tide_rustc_bg_color 1C1C1C
  set -gx tide_rustc_color F74C00
  set -gx tide_rustc_icon \ue7a8
  set -gx tide_shlvl_bg_color 1C1C1C
  set -gx tide_shlvl_color d78700
  set -gx tide_shlvl_icon \uf120
  set -gx tide_shlvl_threshold 1
  set -gx tide_status_bg_color 1C1C1C
  set -gx tide_rich_status_bg_color_failure 321C1C
  set -gx tide_rich_status_color 5FAF00
  set -gx tide_rich_status_color_failure D70000
  set -gx tide_rich_status_icon \u2714
  set -gx tide_rich_status_icon_failure \u2718
  set -gx tide_terraform_bg_color 1C1C1C
  set -gx tide_terraform_color 844FBA
  set -gx tide_terraform_icon \U000f1062
  set -gx tide_time_bg_color 1C1C1C
  set -gx tide_time_color 5F8787
  set -gx tide_time_format \x25T
  set -gx tide_toolbox_bg_color 1C1C1C
  set -gx tide_toolbox_color 613583
  set -gx tide_toolbox_icon \ue24f
  set -gx tide_vi_mode_bg_color_default 1A332F
  set -gx tide_vi_mode_bg_color_insert 332F1A
  set -gx tide_vi_mode_bg_color_replace 331A1E
  set -gx tide_vi_mode_bg_color_visual 444444
  set -gx tide_vi_mode_color_default B0B0B0
  set -gx tide_vi_mode_color_insert B0B0B0
  set -gx tide_vi_mode_color_replace B0B0B0
  set -gx tide_vi_mode_color_visual B0B0B0
  set -gx tide_vi_mode_icon_default (mk_vi_mode_icon N $tide_vi_mode_color_default)
  set -gx tide_vi_mode_icon_insert  (mk_vi_mode_icon I $tide_vi_mode_color_insert)
  set -gx tide_vi_mode_icon_replace (mk_vi_mode_icon R $tide_vi_mode_color_replace)
  set -gx tide_vi_mode_icon_visual  (mk_vi_mode_icon V $tide_vi_mode_color_visual)
  set -gx tide_zig_bg_color 1C1C1C
  set -gx tide_zig_color F7A41D
  set -gx tide_zig_icon \ue6a9
  set_color $tide_git_color_branch | read -gx _tide_location_color
end

configure_my_tide
if [ $TERM = "xterm-kitty" ]
  set -gx COLORTERM truecolor
end
fish_vi_key_bindings
set -x fish_pid_interactive $fish_pid
