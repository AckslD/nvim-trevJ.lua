local M = {}

local ts = vim.treesitter

local make_default_opts = function()
  return {
    final_separator = ",",
    final_end_line = true,
    skip = {},
  }
end

local make_no_final_sep_opts = function()
  return {
    final_separator = false,
    final_end_line = true,
  }
end

local make_c_containers = function()
  return {
    argument_list = make_no_final_sep_opts(),
    parameter_list = make_no_final_sep_opts(),
    field_initializer_list = make_no_final_sep_opts(),
    field_declaration_list = make_no_final_sep_opts(),
    initializer_list = make_default_opts(),
    enumerator_list = make_default_opts(),
  }
end

local make_javascript_typescript_containers = function()
  local javascript = {
    array = make_default_opts(),
    object = make_default_opts(),
    arguments = make_default_opts(),
    namedimports = make_default_opts(),
    object_pattern = make_default_opts(),
    formal_parameters = make_default_opts(),
  }

  local jsx = {
    jsx_element = make_no_final_sep_opts(),
    jsx_opening_element = {
      final_separator = false,
      final_end_line = true,
      skip = { identifier = true },
    },
  }
  local typescript_only = {
    type_parameters = make_default_opts(),
    type_arguments = make_no_final_sep_opts(),
    object_type = vim.tbl_extend("force", make_default_opts(), { final_separator = ";" }),
  }

  local typescript = vim.tbl_extend("error", javascript, typescript_only)

  return {
    javascript = javascript,
    javascriptreact = vim.tbl_extend("error", javascript, jsx),
    typescript = typescript,
    typescriptreact = vim.tbl_extend("error", typescript, jsx),
  }
end

local settings = {
  containers = vim.tbl_extend("error", {
    c = make_c_containers(),
    cpp = make_c_containers(),
    dart = {
      table_constructor = make_default_opts(),
      arguments = make_no_final_sep_opts(),
      parameters = make_no_final_sep_opts(),
    },
    go = {
      literal_value = make_default_opts(),
      argument_list = make_default_opts(),
      parameter_list = make_default_opts(),
    },
    html = {
      start_tag = {
        final_separator = false,
        final_end_line = true,
        skip = { tag_name = true },
      },
    },
    lua = {
      table_constructor = make_default_opts(),
      arguments = make_no_final_sep_opts(),
      parameters = make_no_final_sep_opts(),
    },
    php = {
      array_creation_expression = make_default_opts(),
      list_literal = make_no_final_sep_opts(),
      formal_parameters = make_no_final_sep_opts(),
      arguments = make_no_final_sep_opts(),
    },
    python = {
      parameters = make_default_opts(),
      argument_list = make_default_opts(),
      list = make_default_opts(),
      tuple = make_default_opts(),
      dictionary = make_default_opts(),
      set = make_default_opts(),
      list_comprehension = make_no_final_sep_opts(),
      generator_expression = make_no_final_sep_opts(),
      dictionary_comprehension = make_no_final_sep_opts(),
      import_from_statement = require("trevj.python").import_from_statement,
    },
    ruby = {
      hash = make_default_opts(),
      array = make_default_opts(),
      method_parameters = make_no_final_sep_opts(),
      argument_list = make_no_final_sep_opts(),
    },
    rust = {
      parameters = make_default_opts(),
      arguments = make_default_opts(),
      field_declaration_list = make_default_opts(),
      array_expression = make_default_opts(),
    },
    supercollider = {
      switch = make_default_opts(),
      case = make_default_opts(),
      variable_definition_sequence = make_default_opts(),
      collection = make_default_opts(),
      parameter_list = make_default_opts(),
      parameter_call_list = make_default_opts(),
    },
    r = {
      arguments = {
        final_separator = false,
        final_end_line = true,
        skip = { comma = true },
      },
    },
  }, make_javascript_typescript_containers()),
}

local warn = function(msg, ...)
  msg = string.format(msg, ...)
  msg = vim.fn.escape(msg, '"')
  vim.cmd(string.format('echohl WarningMsg | echomsg "[trevJ] Warning: %s" | echohl None', msg))
end

local set_default_opts = function(filetype, container_type)
  if settings.containers[filetype] == nil then
    settings.containers[filetype] = {}
  end
  if settings.containers[filetype][container_type] == nil then
    settings.containers[filetype][container_type] = make_default_opts()
  end
end

local update_settings = function(opts)
  local default_opts = make_default_opts()
  for filetype, containers in pairs(opts.containers or {}) do
    for container_type, container_opts in pairs(containers) do
      if type(container_opts) ~= "table" then
        container_opts = {}
      end
      set_default_opts(filetype, container_type)
      for key, value in pairs(container_opts) do
        if default_opts[key] == nil then
          warn("unsupported option `%s`", key)
        else
          settings.containers[filetype][container_type][key] = value
        end
      end
    end
  end
end

local get_opts = function(filetype, node)
  return settings.containers[filetype][node:type()]
end

local is_container = function(filetype, node)
  return get_opts(filetype, node) ~= nil
end

local get_container_at_cursor = function(filetype)
  ts.get_parser():parse()
  local node = ts.get_node()
  if node == nil then
    return
  end
  while not is_container(filetype, node) do
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
    table.insert(new_lines, (" "):rep(indent) .. line)
  end
  return new_lines
end

local lines_end_with = function(lines, char)
  local text = table.concat(lines, [[\n]])
  return text:match(char .. "%s*$") ~= nil
end

local should_skip = function(opts, child)
  local skip = opts.skip
  if skip == nil then
    return false
  elseif type(skip) == "table" then
    return skip[child.node:type()]
  elseif type(skip) == "function" then
    return skip(child)
  else
    warn("unsupported type for skip: `%s`", type(skip))
  end
end

local join_without_newline = function(opts, child, new_lines, lines)
  if #new_lines == 0 then
    vim.list_extend(new_lines, lines)
    return
  end
  local sep
  if opts.make_seperator then
    sep = opts.make_seperator(child)
  else
    sep = ""
  end
  new_lines[#new_lines] = new_lines[#new_lines] .. sep .. table.remove(lines, 1)
  vim.list_extend(new_lines, lines)
end

M.format_at_cursor = function()
  local filetype = vim.bo.filetype
  if settings.containers[filetype] == nil then
    warn("filetype %s is not configured", filetype)
    return
  end
  local node = get_container_at_cursor(filetype)
  if node then
    local opts = get_opts(filetype, node)
    local srow, scol, erow, ecol = node:range()
    local indent = vim.fn.indent(srow + 1)
    local shiftwidth = vim.fn.shiftwidth()
    local new_lines = {}
    local children = {}
    local added_newlines = false
    for child, name in node:iter_children() do
      table.insert(children, { node = child, name = name })
    end
    for i, child in ipairs(children) do
      local lines = vim.split(ts.get_node_text(child.node, 0), "\n")
      if
        opts.final_separator
        and i > 1
        and i == #children - 1
        and child.node:named()
        and not should_skip(opts, child)
      then
        if not lines_end_with(lines, opts.final_separator) then
          lines[#lines] = lines[#lines] .. opts.final_separator
        end
      end
      if should_skip(opts, child) then
        join_without_newline(opts, child, new_lines, lines)
      elseif child.node:named() then
        added_newlines = true
        if #new_lines == 0 then
          new_lines = { "" }
        end
        vim.list_extend(new_lines, indent_lines(lines, indent + shiftwidth))
        if opts.final_end_line and i == #children then
          vim.list_extend(new_lines, { "" })
        end
      else
        if opts.final_end_line and i == #children then
          vim.list_extend(new_lines, indent_lines(lines, indent))
        else
          join_without_newline(opts, child, new_lines, lines)
        end
      end
    end
    vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, new_lines)
    if not added_newlines then
      warn("nothing to format at cursor")
    end
  else
    warn("no container at cursor")
  end
end

M.setup = function(opts)
  opts = opts or {}
  update_settings(opts)
end

return M
