-- module represents a lua module for the plugin
local M = {}

local curl = require("plenary.curl")
local notify = require("notify")
local vim_json = vim.json
local key = "TOKEN"

local function get_visual_selection()
  -- Get the start and end positions of the visual selection
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  -- Get the lines of text within the selection
  local lines = vim.fn.getline(start_pos[2], end_pos[2])

  -- Concatenate the lines into a single string
  local selection = table.concat(lines, "\n")

  return selection
end

local function tprint(tbl, indent)
  if not indent then indent = 0 end
  local toprint = string.rep(" ", indent) .. "{\r\n"
  indent = indent + 2
  for k, v in pairs(tbl) do
    toprint = toprint .. string.rep(" ", indent)
    if (type(k) == "number") then
      toprint = toprint .. "[" .. k .. "] = "
    elseif (type(k) == "string") then
      toprint = toprint .. k .. "= "
    end
    if (type(v) == "number") then
      toprint = toprint .. v .. ",\r\n"
    elseif (type(v) == "string") then
      toprint = toprint .. "\"" .. v .. "\",\r\n"
    elseif (type(v) == "table") then
      toprint = toprint .. tprint(v, indent + 2) .. ",\r\n"
    else
      toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
    end
  end
  toprint = toprint .. string.rep(" ", indent - 2) .. "}"
  return toprint
end

local function codex_request(prompt, callback)
  local url = "https://api.openai.com/v1/completions"
  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. key
  }
  local data = {
    model = "text-davinci-003",
    prompt = prompt,
    temperature = 0.7,
    max_tokens = 4097 - #prompt,
    top_p = 1,
    frequency_penalty = 0,
    presence_penalty = 0
  }
  local local_callback = function(response)
    if response.status == 200 then
      local response_json = vim_json.decode(response.body)
      callback(response_json.choices[1].text)
    else
      notify("error " .. tprint(response))
    end
  end
  curl.post(url, {
    callback = local_callback,
    headers = headers,
    body = vim_json.encode(data),
    timeout = 60000,
  })
end

M.my_first_function = function()
  local selection = get_visual_selection()

  local callback = function(result)
    if result then
      vim.schedule(function()
        local end_pos = vim.fn.getpos("'>")
        local end_line = end_pos[2]
        local lines = {}

        for line in result:gmatch("[^\r\n]+") do
          table.insert(lines, line)
        end

        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(bufnr, end_line, end_line, false, lines)
        notify("Chat result: " .. result)
      end)
    else
      notify("ChatGPT request failed")
    end
  end
  codex_request(selection, callback)
end

return M
