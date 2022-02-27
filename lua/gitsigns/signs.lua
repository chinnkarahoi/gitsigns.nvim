local fn = vim.fn

local Config = require('gitsigns.config').Config

local M = {Sign = {}, }

























M.sign_map = {
   add = "GitSignsAdd",
   delete = "GitSignsDelete",
   change = "GitSignsChange",
   topdelete = "GitSignsTopDelete",
   changedelete = "GitSignsChangeDelete",
}

local ns = 'gitsigns_ns'










local placed = {}

local sign_define_cache = {}

local function sign_get(name)
   if not sign_define_cache[name] then
      local s = fn.sign_getdefined(name)
      if not vim.tbl_isempty(s) then
         sign_define_cache[name] = s
      end
   end
   return sign_define_cache[name]
end

function M.define(name, opts, redefine)
   if redefine then
      sign_define_cache[name] = nil
      fn.sign_undefine(name)
      fn.sign_define(name, opts)
   elseif not sign_get(name) then
      fn.sign_define(name, opts)
   end
end

function M.remove(bufnr, lnum)
   if lnum then
      placed[bufnr][lnum] = nil
   else
      placed[bufnr] = nil
   end
   fn.sign_unplace(ns, { buffer = bufnr, id = lnum })
end

function M.add(cfg, bufnr, signs)
   if not cfg.signcolumn and not cfg.numhl and not cfg.linehl then

      return
   end
   placed[bufnr] = placed[bufnr] or {}

   local fsigns = {}
   for _, s in ipairs(signs) do
      if not placed[bufnr][s.lnum] or placed[bufnr][s.lnum].type ~= s.type then
         fsigns[#fsigns + 1] = s
      end
   end
   signs = fsigns

   local to_place = {}
   for _, s in ipairs(signs) do
      placed[bufnr][s.lnum] = s
      local stype = M.sign_map[s.type]
      local count = s.count

      local cs = cfg.signs[s.type]
      if cfg.signcolumn and cs.show_count and count then
         local cc = cfg.count_chars
         local count_suffix = cc[count] and tostring(count) or (cc['+'] and 'Plus') or ''
         local count_char = cc[count] or cc['+'] or ''
         stype = stype .. count_suffix
         M.define(stype, {
            texthl = cs.hl,
            text = cfg.signcolumn and cs.text .. count_char or '',
            numhl = cfg.numhl and cs.numhl,
            linehl = cfg.linehl and cs.linehl,
         })
      end

      to_place[#to_place + 1] = {
         id = s.lnum,
         group = ns,
         name = stype,
         buffer = bufnr,
         lnum = s.lnum,
         priority = cfg.sign_priority,
      }
   end
   fn.sign_placelist(to_place)
end



function M.get(bufnr, lnum)
   local s = (placed[bufnr] or {})[lnum]
   return s and s.type
end

return M
