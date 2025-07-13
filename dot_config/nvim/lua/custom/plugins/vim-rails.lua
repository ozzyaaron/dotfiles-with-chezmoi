return {
  {
    'tpope/vim-rails',
    name = 'vim-rails',
    opts = {},
    config = function()
      -- Add view component projections
      vim.g.rails_projections = {
        -- View Component class files
        ["app/components/*_component.rb"] = {
          command = "component",
          related = "app/components/{}.html.erb",
          alternate = "spec/components/{}_spec.rb",
          template = {
            "# frozen_string_literal: true",
            "",
            "class {camelcase|capitalize|colons}Component < ViewComponent::Base",
            "  def initialize",
            "    super",
            "  end",
            "end"
          }
        },

        -- View Component template files
        ["app/components/*.html.erb"] = {
          related = "app/components/{}_component.rb",
          alternate = "spec/components/{}_component_spec.rb"
        },

        -- View Component spec files
        ["spec/components/*_component_spec.rb"] = {
          command = "componentspec",
          related = "app/components/{}_component.rb",
          alternate = "app/components/{}.html.erb",
          template = {
            "# frozen_string_literal: true",
            "",
            "require 'rails_helper'",
            "",
            "RSpec.describe {camelcase|capitalize|colons}Component, type: :component do",
            "  it 'renders' do",
            "    render_inline(described_class.new)",
            "    expect(page).to have_text('')",
            "  end",
            "end"
          }
        },

        -- Nested view components (admin/, shared/, etc.)
        ["app/components/*/*_component.rb"] = {
          command = "component",
          related = "app/components/{dirname}/{basename}.html.erb",
          alternate = "spec/components/{dirname}/{basename}_spec.rb"
        },

        ["app/components/*/*.html.erb"] = {
          related = "app/components/{dirname}/{basename}_component.rb",
          alternate = "spec/components/{dirname}/{basename}_component_spec.rb"
        },

        ["spec/components/*/*_component_spec.rb"] = {
          command = "componentspec",
          related = "app/components/{dirname}/{basename}_component.rb",
          alternate = "app/components/{dirname}/{basename}.html.erb"
        }
      }
    end,
  }
}
