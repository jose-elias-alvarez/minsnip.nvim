-- NOTE: this integration is deprecated (it theoretically works, but I'm not using cmp anymore and won't be maintaining this)
local cmp = require("cmp")

local source = {}
local cache

source.new = function()
    return setmetatable({}, { __index = source })
end

function source:is_available()
    local ok = pcall(require, "minsnip")
    return ok
end

function source:get_debug_name()
    return "minsnip"
end

function source:complete(_, callback)
    if not cache then
        cache = {}
        for name in pairs(require("minsnip").snippets) do
            table.insert(cache, { label = name, kind = cmp.lsp.CompletionItemKind.Snippet })
        end
    end
    callback(cache)
end

function source:execute(completion_item, callback)
    require("minsnip").expand_by_name(completion_item.label)
    callback(completion_item)
end

return source
