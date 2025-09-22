from xonsh.built_ins import XSH
from .plugins import powerline

def load():
    powerline.plug()
