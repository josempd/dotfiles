-- Plugins for working alongside Claude Code agents running in another tmux pane.

---@module 'lazy'
---@type LazySpec
return {
  {
    -- Claude Code IDE protocol: proposed edits open as nvim diffs, selections are shared.
    -- Claude runs in its own tmux pane; connect it with `/ide` there.
    'coder/claudecode.nvim',
    dependencies = { 'folke/snacks.nvim' },
    lazy = false,
    opts = {
      terminal = { provider = 'none' },
      diff_opts = { layout = 'vertical', open_in_new_tab = false },
    },
    keys = {
      { '<leader>as', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = '[A]I [S]end selection to Claude' },
      { '<leader>ab', '<cmd>ClaudeCodeAdd %<cr>', desc = '[A]I add current [B]uffer to Claude' },
      { '<leader>aa', '<cmd>ClaudeCodeDiffAccept<cr>', desc = '[A]I [A]ccept diff' },
      { '<leader>ad', '<cmd>ClaudeCodeDiffDeny<cr>', desc = '[A]I [D]eny diff' },
    },
  },
  {
    -- VSCode-style diff review of everything the agents changed.
    'esmuellert/codediff.nvim',
    dependencies = { 'MunifTanjim/nui.nvim' },
    cmd = 'CodeDiff',
    keys = {
      { '<leader>gd', '<cmd>CodeDiff<cr>', desc = '[G]it [D]iff review (working tree)' },
    },
  },
  {
    -- Inline peek of definitions/references/implementations, editable in place.
    'DNLHC/glance.nvim',
    cmd = 'Glance',
    keys = {
      { 'gp', '<cmd>Glance definitions<cr>', desc = '[P]eek definition' },
      { 'gP', '<cmd>Glance references<cr>', desc = '[P]eek references' },
      { 'gI', '<cmd>Glance implementations<cr>', desc = 'Peek [I]mplementations' },
      { '<A-LeftMouse>', '<LeftMouse><cmd>Glance definitions<cr>', desc = 'Peek definition (Alt+click)' },
    },
    opts = {},
  },
}
