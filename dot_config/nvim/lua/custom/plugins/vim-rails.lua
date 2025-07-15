return {
  {
    'tpope/vim-rails',
    name = 'vim-rails',
    opts = {},
    config = function()
      -- Add view component projections
      vim.g.rails_projections = {
        -- View Component class files
        ["app/components/*.rb"] = {
          command = "component",
          related = "app/components/{}.html.erb",
          alternate = "spec/components/{}_spec.rb",
          template = {
            "class {camelcase|capitalize|colons}Component < ApplicationComponent",
            "  def initialize",
            "    super",
            "  end",
            "end"
          }
        },

        -- View Component template files
        ["app/components/*.html.erb"] = {
          related = "app/components/{}.rb",
          alternate = "spec/components/{}_spec.rb"
        },

        -- View Component spec files
        ["spec/components/*_component_spec.rb"] = {
          command = "componentspec",
          related = "app/components/{}_component.rb",
          alternate = "app/components/{}_component.html.erb",
          template = {
            "require 'rails_helper'",
            "",
            "describe {camelcase|capitalize|colons}Component do",
            "  it 'renders' do",
            "    render_inline(described_class.new)",
            "    expect(page).to have_text('')",
            "  end",
            "end"
          }
        },

        -- Nested view components (admin/, shared/, etc.)
        ["app/components/*/*.rb"] = {
          command = "component",
          related = "app/components/{dirname}/{basename}.html.erb",
          alternate = "spec/components/{dirname}/{basename}_spec.rb"
        },

        ["app/components/*/*.html.erb"] = {
          related = "app/components/{dirname}/{basename}.rb",
          alternate = "spec/components/{dirname}/{basename}_spec.rb"
        },

        ["spec/components/*/*_component_spec.rb"] = {
          command = "componentspec",
          related = "app/components/{dirname}/{basename}_component.rb",
          alternate = "app/components/{dirname}/{basename}_component.html.erb"
        }
      }
    end,
  }
}
