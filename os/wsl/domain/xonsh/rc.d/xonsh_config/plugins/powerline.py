from xonsh.built_ins import XSH
from ..lib.powerline import processor as xpp
from ..lib.powerline import fields as xpf

def plug():
    xpf.set__pl_defaults()
    XSH.env["PROMPT_TOKENS_FORMATTER"] = xpp.process_prompt_tokens
