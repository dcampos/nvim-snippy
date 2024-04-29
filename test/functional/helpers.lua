local ok, helpers = pcall(require, 'test.functional.testnvim')
if not ok then
    ok, helpers = pcall(require, 'test.functional.helpers')
end
helpers = helpers()

local ok2, testutil = pcall(require, 'test.testutil')
if ok2 then
    helpers.eq = testutil.eq
    helpers.neq = testutil.neq
    helpers.ok = testutil.ok
end

return helpers
