import os
import re
from typing import Optional
from pathlib import Path
from xdg_base_dirs import xdg_data_home, xdg_config_home


#! Soo will be deprecated in favor of hyprquery
def get_var(theme_var: str, file: Optional[str] = None) -> Optional[str]:
    """Get theme variable value from configuration files.

    Args:
        theme_var: The theme variable to look for
        file: Optional path to configuration file

    Returns:
        The value of the theme variable or None if not found
    """
    file = file or os.path.join(xdg_config_home(), "hypr/themes/theme.conf")

    GS_MAP = {
        "GTK_THEME": "gtk-theme",
        "ICON_THEME": "icon-theme",
        "COLOR_SCHEME": "color-scheme",
        "CURSOR_THEME": "cursor-theme",
        "CURSOR_SIZE": "cursor-size",
        "FONT": "font-name",
        "DOCUMENT_FONT": "document-font-name",
        "MONOSPACE_FONT": "monospace-font-name",
        "FONT_SIZE": "font-size",
        "DOCUMENT_FONT_SIZE": "document-font-size",
        "MONOSPACE_FONT_SIZE": "monospace-font-size",
    }

    def extract_value_from_file(pattern: str, filepath: str) -> Optional[str]:
        try:
            with open(filepath) as f:
                for line in f:
                    if re.match(pattern, line):
                        value = line.split("=", 1)[1].strip()
                        return re.sub(r"^[\s]*|[\s]*$", "", value)
        except FileNotFoundError:
            return None
        return None

    if value := extract_value_from_file(rf"^[\s]*\${theme_var}\s*=", file):
        if not value.startswith("$"):
            return value

    if theme_var in GS_MAP:
        try:
            with open(file) as f:
                pattern = rf"^[\s]*exec[\s]*=[\s]*gsettings[\s]*set[\s]*org.gnome.desktop.interface[\s]*{GS_MAP[theme_var]}[\s]*"
                for line in f:
                    if re.search(pattern, line):
                        return line.split('"')[-2]
        except FileNotFoundError:
            pass

    if theme_var == "CODE_THEME":
        return "Wallbash"
    if theme_var == "SDDM_THEME":
        return ""

    default_configs = [
        Path(xdg_data_home) / "denv/denv.conf",
        Path(xdg_data_home) / "denv/hyprland.conf",
        Path("/usr/local/share/denv/denv.conf"),
        Path("/usr/local/share/denv/hyprland.conf"),
        Path("/usr/share/denv/denv.conf"),
        Path("/usr/share/hyprland.conf"),
    ]

    for config in default_configs:
        if config.exists():
            if value := extract_value_from_file(
                rf"^[\s]*\$default.{theme_var}\s*=", str(config)
            ):
                return value

    return None
