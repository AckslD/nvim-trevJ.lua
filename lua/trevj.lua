local ts_utils = require "nvim-treesitter.ts_utils"

local containers = {
  table_constructor = true,
  arguments = {
    final_separator = false,
  },
  parameters = {
    final_separator = false,
    final_end_line = false,
  },
}

local default_opts = {
    final_separator = ',',
    final_end_line = true,
}

local warn = function(msg)
    msg = vim.fn.escape(msg, '"')
    vim.cmd(string.format('echohl WarningMsg | echomsg "[trevJ] Warning: %s" | echohl None', msg))
end

local get_opts = function(node)
  local opts = containers[node:type()]
  if type(opts) ~= 'table' then
    opts = {}
  end
  for key, _ in pairs(opts) do
    if default_opts[key] == nil then
      warn(string.format('unsupported option `%s`', key))
    end
  end
  for key, value in pairs(default_opts) do
    if opts[key] == nil then
      opts[key] = value
    end
  end
  return opts
end

local is_container = function(node)
  return containers[node:type()] ~= nil
end

local get_container_at_cursor = function()
  local node = ts_utils.get_node_at_cursor()
  while not is_container(node) do
    node = node:parent()
    if node == nil then
      return
    end
  end
  return node
end

local indent_lines = function(lines, indent)
  local new_lines = {}
  for _, line in ipairs(lines) do
    table.insert(new_lines, (' '):rep(indent) .. line)
  end
  return new_lines
end

local lines_end_with = function(lines, char)
  local text = table.concat(lines, [[\n]])
  return text:match(char .. '%s*$') ~= nil
end

local format_at_cursor = function()
  local node = get_container_at_cursor()
  if node then
    local opts = get_opts(node)
    local srow, scol, erow, ecol = node:range()
    local indent = vim.fn.indent(srow)
    local new_lines = {}
    local children = {}
    for child in node:iter_children() do
      table.insert(children, child)
    end
    for i, child in ipairs(children) do
      local lines = ts_utils.get_node_text(child)
      if opts.final_separator and i == #children - 1 then
        if not lines_end_with(lines, opts.final_separator) then
          lines[#lines] = lines[#lines] .. opts.final_separator
        end
      end
      if child:named() then
        vim.list_extend(new_lines, indent_lines(lines, indent + vim.fn.shiftwidth()))
      else
        if opts.final_end_line and i == #children then
          vim.list_extend(new_lines, indent_lines(lines, indent))
        elseif #new_lines == 0 then
          vim.list_extend(new_lines, lines)
        else
          -- TODO assert single?
          new_lines[#new_lines] = new_lines[#new_lines] .. lines[1]
        end
      end
    end
    vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, new_lines)
  else
    warn('no container at cursor')
  end
end

format_at_cursor()

local test = {foo = {
  x = 0,
  y = 1,
}, bar = true,
  other = false
}
