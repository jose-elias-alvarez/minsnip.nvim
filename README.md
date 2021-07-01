# minsnip.nvim

An aggressively minimalistic snippet plugin.

https://user-images.githubusercontent.com/54108223/124073016-82c9df80-da7c-11eb-8439-771e754caa92.mov

## Feature(s)

Minsnip does one thing: it lets you expand defined snippets and jump between
positions. What you see in the animation above is what you get.

Minsnip uses Neovim's `extmarks` API to offload the heavy lifting of tracking
positions and, as a result, does the job in 200-ish lines of code, an order of
magnitude fewer than other implementations.

Minsnip does its best to stay out of your way and avoid affecting editor
performance. When you're not jumping in a snippet, Minsnip does nothing. Once
you're done, it wipes itself out until you call it again.

Minsnip _may_ be for you if:

- You value simplicity and speed over features
- You are comfortable with Lua and the Neovim API
- You prefer to create your own snippets
- You want to build a custom solution on top of a simple base

Minsnip is **not** for you if:

- You want built-in features like linked snippets, recursive expansion,
  automatic expansion, LSP snippets, or integration with completion plugins
  (they're not implemented!)
- You want to use a pre-existing library of snippets (there isn't one!)
- You don't want to use Lua (you have to!)
- You use Vim (it's Neovim-only!)

Note that Minsnip requires the latest Neovim master and is not guaranteed to
work on older versions.

## Defining snippets

```lua
local snippets = {
    lua = {
        -- string
        print = "print($1)",

        -- bracket strings work, too
        func = [[
        function($1)
            $0
        end]],

        -- lists work, but bracket strings are better, right?
        lfunc = { "local $1 = ($2)", "\t$0", "end" },

        -- functions also work (more on that below)
        clip = function()
            return vim.fn.getreg("*")
        end
    },
}
require("minsnip").setup({ snippets = snippets })
```

Using functions as snippets is both simple and powerful. For example, the
following snippet will remove the hostname from a GitHub URL in your clipboard
and return a formatted plugin `use` statement for
[packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
local snippets = {
    lua = {
        use = function()
            return string.format('use "%s"', vim.fn.getreg("*"):gsub("https://github.com/", ""))
        end,
    }
}
```

## Positions

Snippets can have any number of positions, each consisting of a `$` followed by
a number. Like other implementations, `$0` is a special case denoting the final
jump, and Minsnip will insert a final position at the end of the snippet if you
don't specifically define one.

```lua
-- this is OK,
print($1, $2)

-- but it's better to explicitly define a final position
print($1, $0)

-- missing positions get skipped
print($1, $9)
```

Unlike other implementations, Minsnip does not "link" identical positions.
Minsnip treats each position in this snippet as an independent position:

```lua
-- expanding moves the cursor to the first $1,
-- and the next jump goes to the second
print($1, $1)
```

## Expanding and jumping

Minsnip exposes the following two methods, which you what you'd imagine:

```lua
require("minsnip").jump()
require("minsnip").jump_backwards()
```

You can map them directly to keys:

```lua
vim.api.nvim_set_keymap("i", "<C-j>", "<cmd> lua require'minsnip'.jump()<CR>", {})
vim.api.nvim_set_keymap("i", "<C-k>", "<cmd> lua require'minsnip'.jump_backwards()<CR>", {})
```

But the recommended approach is to use a conditional map:

```lua
_G.tab_complete = function()
    -- returns false if it can't expand or jump
    if not minsnip.jump() then
        -- whatever you want to do as a fallback
        vim.api.nvim_input("<C-x><C-o>")
    end
end

vim.api.nvim_set_keymap("i", "<Tab>", "<cmd> lua tab_complete()<CR>", {})
```

Why? Combining a conditional map with function snippets lets you create
_conditional snippets_, just like the big boys.

For example, the following snippet will trigger if the cursor is on the first
line of the buffer and fall back to whatever you've defined in your conditional
map otherwise:

```lua
local snippets = {
    lua = {
        flo = function()
            if vim.api.nvim_win_get_cursor(0)[1] == 1 then
                return "I am at the top of this file!"
            end
        end,
    }
}
```

And if this is a condition you plan on reusing, Lua makes it easy to write a wrapper:

```lua
local first_line_only = function(snippet)
    return function()
        return vim.api.nvim_win_get_cursor(0)[1] == 1 and snippet
    end
end

local snippets = {
    lua = {
        top = first_line_only("I am the first line of this file!"),
    },
}
```

Instead of filling the plugin with features you _might_ use, Minsnip's goal is
to make it simple to write the snippets you _want_ to use.

## Extending filetypes

You can extend one filetype's snippets with another's by passing a list of
filetypes to `setup` under the key `extends`, as in the example below:

```lua
local snippets = {
    typescript = {
        clg = "console.log($1);",
    },

    typescriptreact = {
        ifp = [[
        interface Props {
            $0
        }]]
    }
}

require("minsnip").setup({
    snippets = snippets,
    -- will enable typescript snippets when using typescriptreact
    extends = { typescriptreact = { "typescript" } },
})
```

## Contributions

Minsnip is in **alpha status**, and you may run into bugs in normal usage.
Bug reports and fixes are greatly appreciated.

Feature requests and contributions are also welcome, but please note that I will
continue to err towards the side of minimalism. If built-in features are what
you're after, I recommend trying one of the alternatives listed below.

## Testing

Run `make test` in the root directory.

## Alternatives

- [UltiSnips](https://github.com/SirVer/ultisnips): has a ton of features and a
  custom `snippets` format that's ergonomic and easy to use. It integrates with
  [vim-snippets](https://github.com/honza/vim-snippets), a repository with a
  large selection of snippets for most languages. Drawbacks are performance and
  a gigantic code base that makes it hard (at least for me) to understand what's
  going on.

- [vim-vsnip](https://github.com/hrsh7th/vim-vsnip): supports JSON snippets in
  the same format as VS Code, meaning you can use snippets from VS Code
  extensions. Also supports LSP snippets and integrates with popular completion
  engines. I used vim-vsnip for a long time and am a fan of everything except
  writing my own JSON snippets, which is awful.

- [snippets.nvim](https://github.com/norcalli/snippets.nvim): a powerful
  plugin written in Lua that I, personally, was never able to wrap my head
  around. Hasn't seen an update for some time as of this writing.
