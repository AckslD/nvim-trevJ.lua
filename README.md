# nvim-trevJ.lua

:warning: *This plugin is in an early stage and docs is a bit sparse. Feel free to try it out though and let me know if you have any problems/suggestions.*

Nvim-plugin for doing the opposite of join-line (J) of arguments, powered by treesitter.
The intention of the plugin is the same as [`revJ`](https://github.com/AckslD/nvim-revJ.lua).
However `trevJ` uses treesitter to figure out the formatting and in general does everything much more efficient and better, while not polluting registers, last visual selection etc.
My intention is that anyone using `revJ` should have a smooth transfer to `trevJ` but both configuration and usage will necessarily be somewhat different and instead of making a breaking change for `revJ` I decided to make a new plugin.
Also since it's anyway a complete re-write of the code.

## Installation
For example using [`packer`](https://github.com/wbthomason/packer.nvim):
```lua
use {
  'AckslD/nvim-trevJ.lua',
  config = 'require("trevj").setup()',  -- optional call for configurating non-default filetypes etc

  -- uncomment if you want to lazy load
  -- module = 'trevj',

  -- an example for configuring a keybind, can also be done by filetype
  -- setup = function()
  --   vim.keymap.set('n', '<leader>j', function()
  --     require('trevj').format_at_cursor()
  --   end)
  -- end,
}
```

## Configuration

When configuring a language you should specify the treesitter node types that contains the child nodes which should be put on separate lines.
For example for the default configuration for `lua` looks as follows:
```lua
require('trevj').setup({
  containers = {
    lua = {
      table_constructor = {final_separator = ',', final_end_line = true},
      arguments = {final_separator = false, final_end_line = true},
      parameters = {final_separator = false, final_end_line = true},,
    },
    ... -- other filetypes
  },
})
```
where:
* `final_separator`: if truthy adds this character after the final child node if not existing.
* `final_end_line`: if there should be a final line before the and character of the container node.
* `skip` (optional): a table where keys correspond to children types to not put on newlines and values are truthy.
  For example, the default config for `html` is:
  ```lua
  html = {
    start_tag = {
      final_separator = false,
      final_end_line = true,
      skip = {tag_name = true},
    },
  }
  ```
  in order to not put the `tag_name` on a new line.

For existing languages you can override anything and defaults will be used for anything unspecified.

## Supported Languages

Currently the following languages are supported by default:

- c
- cpp
- dart
- go
- html
- javascript
- javascriptreact
- lua
- php
- python
- ruby
- rust
- supercollider
- typescript
- typescriptreact

You can add your own, of even better submit a PR for your favorite language.

### Examples
#### default
```
{final_separator = ',', final_end_line = true}
```
becomes
```
{
  final_separator = ',',
  final_end_line = true,
}
```

#### no final separator
```
{final_separator = false, final_end_line = true}
```
becomes
```
{
  final_separator = false,
  final_end_line = true
}
```

#### no final separator, no final line
```
{final_separator = false, final_end_line = false}
```
becomes
```
{
  final_separator = false,
  final_end_line = false}
```

## Usage
Call `require('trevj').format_at_cursor()` or bind a key to it.
Note that you need to be inside the container treesitter node, otherwise a warning will be given.
