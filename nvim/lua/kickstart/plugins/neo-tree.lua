return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  opts = {
    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true, -- refresh when agents create/delete files
      filtered_items = { hide_dotfiles = false, hide_gitignored = true },
      window = {
        position = 'right', -- keep the editor next to Claude in agentdev
        width = 32, -- default 40
        mappings = {
          ['\\'] = 'close_window',
        },
      },
    },
  },
}
