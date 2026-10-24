---@module 'lazy'
---@type LazySpec
return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      heading = {
        icons = { '# ', '## ', '### ', '#### ', '##### ', '###### ' },
      },
      bullet = {
        icons = { '●', '○', '◆', '◇' },
      },
      checkbox = {
        unchecked = { icon = '☐ ' },
        checked = { icon = '☑ ' },
      },
    },
    keys = {
      { '<leader>tm', '<cmd>RenderMarkdown toggle<CR>', desc = '[T]oggle [M]arkdown rendering' },
    },
  },
}
