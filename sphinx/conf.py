# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'libsystem'
copyright = '2021-2026 JackMacWindows'
author = 'JackMacWindows'
release = '0.2.7'
master_doc = 'system/index'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    "sphinx_lua_ls",
    "myst_parser",
    "sphinx.ext.githubpages"
]

# Path to the folder containing the `.emmyrc.json`/`.luarc.json` file,
# relative to the directory with `conf.py`.
lua_ls_project_root = "../"
lua_ls_backend = "luals"

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

lua_ls_apidoc_roots = {
    "system": {
        "path": "system",
        "options": {
            "title": "API Reference"
        }
    }
}
lua_ls_apidoc_format = "md"
lua_ls_apidoc_max_depth = 1
lua_ls_apidoc_default_options = {
   # Document members without description.
   "undoc-members": "",
   # Document protected members.
   "protected-members": "",
   # Document module's global variables.
   "globals": "",
   # Add table with inherited members for classes.
   "inherited-members-table": "",
}

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'furo'
html_static_path = ['_static']
html_logo = 'logo.png'
html_favicon = 'favicon.ico'
html_title = "libsystem"
html_theme_options = {
    "light_css_variables": {
        "color-brand-primary": "#944f00",
        "color-brand-content": "#944f00",
    },
    "dark_css_variables": {
        "color-brand-primary": "#ff8800",
        "color-brand-content": "#ff8800",
    },
}

pygments_style = "sphinx"
pygments_dark_style = "monokai"
