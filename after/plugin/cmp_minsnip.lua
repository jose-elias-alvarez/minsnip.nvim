local ok, cmp = pcall(require, "cmp")
if not ok then
    return
end

cmp.register_source("minsnip", require("minsnip.cmp").new())
