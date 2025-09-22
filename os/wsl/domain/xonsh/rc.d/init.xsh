# XONSH WEBCONFIG START
# $XONSH_COLOR_STYLE = 'paraiso-dark'
# XONSH WEBCONFIG END

if $XONSH_INTERACTIVE:
  xontrib load coconut

  # $PROMPT_FIELDS["cwd__pl_colors"] = ("WHITE", "CYAN")

  # choose the powerline glyph used
  $POWERLINE_MODE = "lego" # if not set then it will choose random
  # available modes: round/down/up/flame/squares/ruiny/lego

  # define the prompts using the format style and you are good to go
  $PROMPT = "".join(
    [
      "{vte_new_tab_cwd}",
      "{cwd:{}}",
      "{gitstatus:{}}",
      # "{ret_code}",
      "{background_jobs}",
      os.linesep,
      "{full_env_name: 🐍{}}",
      "$",
    ]
  )
  $RIGHT_PROMPT = "".join(
    (
      "{long_cmd_duration: ⌛{}}",
      "{user: 🤖{}}",
      "{hostname: 🖥{}}",
      "{localtime: 🕰{}}",
    )
  )

  fastfetch \
    --shell-format $(xonsh -V) \
    --separator-output-color black \
    --logo-width 37 \
    --logo-height 17 \
    --logo-padding-left 1 \
    --logo-padding-top 3 \
    --logo-padding-right 3 \
    --logo-type kitty-direct \
    --logo ~/.config/fastfetch/logo.nix.2.png
  # execx($(starship init xonsh))
