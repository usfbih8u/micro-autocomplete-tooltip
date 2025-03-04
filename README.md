# Micro Autocomplete Tooltip

Show **suggestions in a tooltip** at the cursor location. **Works for buffers and the Command bar**. Hit TAB and enjoy!

> To cycle through the suggestions using `CursorUp` and `CursorDown`, you need to add the option `"autocomplete_tooltip.EnableCursorUpDown"` with any value other than `false` or `nil` to your `settings.json` file.

> To add a prefix to the current suggestion, use the option `autocomplete_tooltip.Prefix` in `settings.json`.

## 🎨 Syntax and Colorscheme

To improve readability, a custom syntax and colorscheme are provided until Micro allows customization of colorschemes per buffer.

You can add the following line at the end of your current colorscheme: `include autocomplete-tooltip`. **I recommend using a custom colorscheme** that includes both your main colorscheme and this one.

```
# custom-colorscheme.micro
include "YOUR_MAIN_COLORSCHEME"
include "autocomplete-tooltip"
include "gutter-message" # 👀
```

You can **change the colors** inside `colorschemes/autocomplete-tooltip.micro`.

## 📦 Installation

⚠️ **Do NOT change the name of the plugin directory `micro-autocomplete-tooltip`**.  It is used as a prefix to avoid path collisions in `package.path` when requiring modules.

In Linux, you can clone the repo anywhere and create a symlink inside `.config/micro/plug` using the `ENABLE_FOR_MICRO.sh` script.
