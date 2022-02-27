local fn = vim.fn

local Config = require('gitsigns.config').Config

local record M
  enum SignName
    "GitSignsAdd"
    "GitSignsDelete"
    "GitSignsChange"
    "GitSignsTopDelete"
    "GitSignsChangeDelete"
  end

  enum SignType
    "add"
    "delete"
    "change"
    "topdelete"
    "changedelete"
  end

  record Sign
    type: SignType
    count: integer
    lnum: integer
  end

  sign_map: {SignType:SignName}
end

M.sign_map = {
  add          = "GitSignsAdd",
  delete       = "GitSignsDelete",
  change       = "GitSignsChange",
  topdelete    = "GitSignsTopDelete",
  changedelete = "GitSignsChangeDelete",
}

local ns = 'gitsigns_ns'

-- The internal representation of signs in Neovim is a linked list which is
-- slow to index. Also when a sign is added/removed, it causes the sign column
-- width to re-calculated which requires a full scan of the signs list.
--
-- To workaround these shortcomings, we add an abstraction layer to the signs
-- API which keeps track of which signs have already been placed in the buffer.
-- This allows us to:
--   - efficiently query placed signs.
--   - skip adding a sign if it has already been placed.
local placed: {integer:{integer:M.Sign}} = {}

local sign_define_cache = {}

local function sign_get(name: string): table
  if not sign_define_cache[name] then
    local s = fn.sign_getdefined(name)
    if not vim.tbl_isempty(s) then
      sign_define_cache[name] = s
    end
  end
  return sign_define_cache[name]
end

function M.define(name: string, opts: {string:any}, redefine: boolean)
  if redefine then
    sign_define_cache[name] = nil
    fn.sign_undefine(name)
    fn.sign_define(name, opts)
  elseif not sign_get(name) then
    fn.sign_define(name, opts)
  end
end

function M.remove(bufnr: integer, lnum: integer)
  if lnum then
    placed[bufnr][lnum] = nil
  else
    placed[bufnr] = nil
  end
  fn.sign_unplace(ns, {buffer = bufnr, id = lnum})
end

function M.add(cfg: Config, bufnr: integer, signs: {M.Sign})
  if not cfg.signcolumn and not cfg.numhl and not cfg.linehl then
    -- Don't place signs if it won't show anything
    return
  end
  placed[bufnr] = placed[bufnr] or {}

  local fsigns = {}
  for _, s in ipairs(signs) do
    if not placed[bufnr][s.lnum] or placed[bufnr][s.lnum].type ~= s.type then
      fsigns[#fsigns+1] = s
    end
  end
  signs = fsigns

  local to_place: {fn.SignPlaceItem} = {}
  for _, s in ipairs(signs) do
    placed[bufnr][s.lnum] = s
    local stype: string = M.sign_map[s.type]
    local count = s.count

    local cs = cfg.signs[s.type]
    if cfg.signcolumn and cs.show_count and count then
      local cc = cfg.count_chars
      local count_suffix = cc[count] and tostring(count) or (cc['+'] and 'Plus') or ''
      local count_char   = cc[count]                     or  cc['+']             or ''
      stype = stype..count_suffix
      M.define(stype, {
        texthl = cs.hl,
        text   = cfg.signcolumn and cs.text..count_char or '',
        numhl  = cfg.numhl      and cs.numhl,
        linehl = cfg.linehl     and cs.linehl
      })
    end

    to_place[#to_place+1] = {
      id       = s.lnum,
      group    = ns,
      name     = stype,
      buffer   = bufnr,
      lnum     = s.lnum,
      priority = cfg.sign_priority
    }
  end
  fn.sign_placelist(to_place)
end

-- Return map of line number to sign name. Can't use SignName as signs with
-- counts have a suffix on their name.
function M.get(bufnr: integer, lnum: integer): string
  local s = (placed[bufnr] or {})[lnum]
  return s and s.type
end

return M
