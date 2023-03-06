M = {}

local ts = vim.treesitter.query

local make_default_opts = function()
  return {
    final_separator = ",",
    final_end_line = true,
    skip = {},
  }
end

local make_special_array_opts = function()
  return {
    final_separator = false,
    final_end_line = true,
    skip = {},
  }
end

local indent_lines = function(lines, indent)
  local new_lines = {}
  for _, line in ipairs(lines) do
    table.insert(new_lines, (" "):rep(indent) .. line)
  end
  return new_lines
end

local make_ruby_containers = function()
  local argument_list_handler = function(node)
    local srow, scol, erow, ecol = node:parent():range()
    local shiftwidth = vim.fn.shiftwidth()
    local new_lines = {}
    local identifiers = {}
    local anonymous_types = {
      ["("] = true,
      [")"] = true,
      [","] = true,
    }

    local method = ts.get_node_text(node:prev_sibling(), 0)
    local candidate_sibling = node

    while candidate_sibling:prev_sibling() do
      local prev_sibling = candidate_sibling:prev_sibling()
      local prev_sibling_type = prev_sibling:type()

      if prev_sibling_type == "method_call" then
        method = ts.get_node_text(prev_sibling, 0)
        break
      end

      candidate_sibling = prev_sibling
    end

    for candidate_identifier in node:iter_children() do
      local type = candidate_identifier:type()

      if not anonymous_types[type] then
        table.insert(identifiers, candidate_identifier)
      end
    end

    local sibling_text;

    if candidate_sibling then
      local candidate_sibling_text = ts.get_node_text(candidate_sibling, 0)

      if candidate_sibling_text == method then
        sibling_text = method
      else
        sibling_text = candidate_sibling_text .. "." .. method
      end
    else
      sibling_text = method
    end

    if node:child(0):type() == "(" then
      local additional_indent = scol + shiftwidth

      for i, identifier in ipairs(identifiers) do
        if i == 1 then
          vim.list_extend(new_lines, indent_lines({ sibling_text .. "(" }, 0))
          vim.list_extend(new_lines, indent_lines({ ts.get_node_text(identifier, 0) .. "," }, additional_indent))
          if #identifiers == 1 then
            vim.list_extend(new_lines, indent_lines({ ")" }, scol))
          end
        elseif i == #identifiers then
          vim.list_extend(new_lines, indent_lines({ ts.get_node_text(identifier, 0) .. "," }, additional_indent))
          vim.list_extend(new_lines, indent_lines({ ")" }, scol))
        else
          vim.list_extend(new_lines, indent_lines({ ts.get_node_text(identifier, 0) .. "," }, additional_indent))
        end
      end
    else
      local additional_indent = scol + #method + 1

      for i, identifier in ipairs(identifiers) do
        if i == 1 then
          vim.list_extend(new_lines, { sibling_text .. " " .. ts.get_node_text(identifier, 0) .. "," })
        elseif i == #identifiers then
          vim.list_extend(new_lines, indent_lines({ ts.get_node_text(identifier, 0) }, additional_indent))
        else
          vim.list_extend(new_lines, indent_lines({ ts.get_node_text(identifier, 0) .. "," }, additional_indent))
        end
      end
    end

    vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, new_lines)
  end
  local block_handler = function(node)
    local srow, scol, erow, ecol = node:range()
    local indent = vim.fn.indent(srow + 1)
    local shiftwidth = vim.fn.shiftwidth()
    local new_lines = {}
    local param_text;
    local body_text;

    if node:child(1):type() == "block_parameters" then
      local block_parameters_node = node:child(1)
      local block_body_node = node:child(2)

      param_text = " " .. ts.get_node_text(block_parameters_node, 0)
      body_text = ts.get_node_text(block_body_node, 0)
    else
      local block_body_node = node:child(1)

      param_text = ""
      body_text = ts.get_node_text(block_body_node, 0)
    end

    local starting_lines = { "do" .. param_text }
    local middle_lines = indent_lines({ body_text }, indent + shiftwidth)
    local finishing_lines = indent_lines({ "end" }, indent)

    local body_lines = vim.split(body_text, "\n")

    if #body_lines > 1 then
      local original_text = ts.get_node_text(node, 0)
      local original_lines = vim.split(original_text, "\n")

      vim.list_extend(new_lines, original_lines)
    else
      vim.list_extend(new_lines, starting_lines)
      vim.list_extend(new_lines, middle_lines)
      vim.list_extend(new_lines, finishing_lines)
    end

    vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, new_lines)
  end

  return {
    hash = make_default_opts(),
    array = make_default_opts(),
    symbol_array = make_special_array_opts(),
    string_array = make_special_array_opts(),
    method_parameters = make_default_opts(),
    argument_list = {
      custom_handler = argument_list_handler,
    },
    do_block = {
      custom_handler = block_handler,
    },
    block = {
      custom_handler = block_handler,
    },
  }
end

M.make_containers = make_ruby_containers

return M
