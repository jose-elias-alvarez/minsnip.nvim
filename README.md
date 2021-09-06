<!-- markdownlint-configure-file
{
  "line-length": false,
  "no-bare-urls": false
}
-->

# minsnip.nvim

An aggressively minimalistic snippet plugin.

https://user-images.githubusercontent.com/54108223/124073016-82c9df80-da7c-11eb-8439-771e754caa92.mov

## Feature(s)

Minsnip does one thing: it lets you expand defined snippets and jump between
positions. What you see in the animation above is what you get.

Minsnip uses Neovim's `extmarks` API to offload the heavy lifting of tracking
positions and, as a result, does the job in 200-ish lines of code, an order of
magnitude fewer than other implementations.

Minsnip _may_ be for you if:

- You value simplicity and speed over features
- You are comfortable with Lua and the Neovim API
- You don't mind creating your own snippets
- You want to build a custom solution on top of a simple base

Minsnip is **not** for you if:

- You want built-in features like linked snippets, recursive expansion, or
  automatic expansion (they're not implemented, but you could do it yourself!)
- You want to use a pre-existing library of snippets (there isn't one!)
- You don't want to use Lua (you have to!)
- You use Vim (it's Neovim-only!)

## Defining snippets

All Minsnip snippets are functions that return strings or `nil`.

```lua
local snippets = {
    -- global snippet
    clip = function()
        return vim.fn.getreg("*")
    end,
    -- filetype-specific snippet
    print = function()
        return vim.bo.ft == "lua" and "print($1)"
    end,
    -- use the same trigger for more than one filetype
    func = function()
        return vim.bo.ft == "lua" and [[
        function($1)
            $0
        end]] or vim.bo.ft == "javascript" and [[
        const $1 = ($2) => {
            $0
        };]]
    end,
}

require("minsnip").setup(snippets)
```

Using functions as snippets is both simple and powerful. For example, the
following snippet will remove the hostname from a GitHub URL in your clipboard
and return a formatted plugin `use` statement for
[packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
local snippets = {
    use = function()
        return vim.bo.ft == "lua" and string.format('use "%s"', vim.fn.getreg("*"):gsub("https://github.com/", ""))
    end,
}
```

## Positions

Snippets can have any number of positions, defined by a `$` followed by a
number. Like other implementations, `$0` is a special case denoting the final
jump, and Minsnip will insert a final position at the end of the snippet if you
don't specifically define one.

This is OK:

```txt
print($1, $2)
```

But it's better to explicitly define a final position when possible:

```txt
print($1, $0)
```

Missing positions get skipped, so the following snippet will jump from `$1` to `$9`:

```txt
print($1, $9)
```

Unlike other implementations, Minsnip does not "link" identical positions.
The following snippet will jump from the first `$1` to the second:

```txt
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
_conditional snippets_. Any snippet that returns `nil` will cause Neovim to fall
back to whatever you've defined in your conditional map.

For example, the following snippet will trigger if the cursor is on the first
line of the buffer:

```lua
local snippets = {
    flo = function()
        if vim.api.nvim_win_get_cursor(0)[1] == 1 then
            return "I am at the top of this file!"
        end
    end,
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
    top = first_line_only("I am the first line of this file!"),
}
```

Instead of filling the plugin with features you _might_ use, Minsnip's goal is
to let you focus on writing the snippets you _want_ to use.

## nvim-cmp integration

Minsnip provides a minimal integration with
[nvim-cmp](https://github.com/hrsh7th/nvim-cmp). The following code block shows
how to set it up, with example mappings for `<Tab>` and `<S-Tab>`:

```lua
local cmp = require("cmp")
local minsnip = require("minsnip")

cmp.setup({
    -- required
    snippet = {
        expand = function(args)
            minsnip.expand_anonymous(args.body)
        end,
    },
    -- add to the other sources you're using
    sources = {
        { name = "minsnip" },
    },
    -- optional
    mapping = {
        ["<Tab>"] = function(fallback)
            if vim.fn.pumvisible() == 1 then
                vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, true, true), "n")
            elseif not minsnip.jump() then
                fallback()
            end
        end,
        ["<S-Tab>"] = function(fallback)
            if vim.fn.pumvisible() == 1 then
                vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-p>", true, true, true), "n")
            elseif not minsnip.jump_backwards() then
                fallback()
            end
        end,
    },
})
```

Note the following limitations:

- The popup menu always shows all registered snippets, since Minsnip can't
  determine whether a snippet is valid for the current filetype without
  expanding it (which could cause side effects).
- Minsnip ignores placeholders in LSP snippets and can't handle nested
  placeholders.

## Examples

See [this file](doc/examples.lua) for examples.

## Testing

Run `make test` in the root directory.
