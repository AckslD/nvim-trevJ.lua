local M = {}

local get_node_text = vim.treesitter.get_node_text or vim.treesitter.query.get_node_text

local has_child = function(node, typ)
  for child in node:iter_children() do
    if child:type() == typ then
      return true
    end
  end
  return false
end

M.import_from_statement = {
  final_separator = ",",
  final_end_line = true,
  skip = function(child)
    if child.name == "module_name" then
      return true
    end
    local prev_sib = child.node:prev_sibling()
    if prev_sib and get_node_text(prev_sib, 0) == "import" then
      return true
    end
    return not has_child(child.node:parent(), "(")
  end,
  make_seperator = function(child)
    if get_node_text(child.node, 0) == "," then
      return ""
    else
      return " "
    end
  end,
}

return M
