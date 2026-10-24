-- Options for editing while Claude Code agents change files from another pane.

-- Reload buffers changed on disk. FocusGained never fires while the agent edits
-- from another tmux pane, so also poll once a second.
vim.o.autoread = true
local reload_timer = vim.uv.new_timer()
reload_timer:start(
  1000,
  1000,
  vim.schedule_wrap(function()
    if vim.fn.mode() ~= 'c' and vim.fn.getcmdwintype() == '' then vim.cmd 'silent! checktime' end
  end)
)

-- Open the neo-tree file tree on startup: focused when no file is given, beside
-- the file otherwise. Skipped when nvim is a throwaway editor (commit messages,
-- stdin, diff mode, temp files such as Claude's Ctrl+G prompt).
vim.api.nvim_create_autocmd('StdinReadPre', { callback = function() vim.g.started_with_stdin = true end })
vim.api.nvim_create_autocmd('VimEnter', {
  desc = 'Open neo-tree on startup',
  callback = function()
    if #vim.api.nvim_list_uis() == 0 or vim.o.diff or vim.g.started_with_stdin then return end
    local arg = vim.fn.argc() > 0 and vim.fn.fnamemodify(vim.fn.argv(0), ':p') or ''
    if vim.fn.isdirectory(arg) == 1 then return end -- neo-tree already replaces netrw for `nvim <dir>`
    local tmp = vim.fn.fnamemodify(vim.env.TMPDIR or '/tmp', ':p')
    if arg:sub(1, #tmp) == tmp then return end
    if vim.tbl_contains({ 'gitcommit', 'gitrebase', 'man', 'help' }, vim.bo.filetype) or vim.bo.buftype ~= '' then return end
    vim.cmd(arg == '' and 'Neotree' or 'Neotree show')
  end,
})

-- Ctrl+click: URL -> browser, markdown/file path -> open it, anything else -> LSP definition.
vim.keymap.set('n', '<C-LeftMouse>', function()
  local pos = vim.fn.getmousepos()
  if pos.winid == 0 then return end
  vim.api.nvim_set_current_win(pos.winid)
  vim.api.nvim_win_set_cursor(pos.winid, { pos.line, math.max(pos.column - 1, 0) })

  local target = vim.fn.expand '<cfile>'
  if target:match '^%a[%w+.-]*://' then
    vim.ui.open(target)
  elseif #vim.lsp.get_clients { bufnr = 0, method = 'textDocument/definition' } > 0 then
    vim.lsp.buf.definition()
  elseif target ~= '' and vim.fn.filereadable(vim.fn.expand '%:p:h' .. '/' .. target) == 1 then
    vim.cmd.edit(vim.fn.fnameescape(vim.fn.expand '%:p:h' .. '/' .. target))
  end
end, { desc = 'Open URL / go to definition under mouse' })

-- Listen on a per-project socket so external tools (kitty hints, xdg-open,
-- Claude's Ctrl+click on paths) can open files in this instance via `nvim-open`.
if vim.v.servername == '' or not vim.v.servername:match '/tmp/nvim%-' then
  local project = vim.fn.fnamemodify(vim.fn.getcwd(), ':t'):gsub('[^%w_.-]', '_')
  local sock = '/tmp/nvim-' .. project .. '.sock'
  if vim.uv.fs_stat(sock) then
    -- Another nvim already owns this project, unless the socket is stale.
    local ok, chan = pcall(vim.fn.sockconnect, 'pipe', sock, { rpc = true })
    if ok and chan > 0 then
      vim.fn.chanclose(chan)
      return
    end
    os.remove(sock)
  end
  pcall(vim.fn.serverstart, sock)
end
