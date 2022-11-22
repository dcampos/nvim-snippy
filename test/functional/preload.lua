-- Modules loaded here will not be cleared and reloaded by Busted.
-- Busted started doing this to help provide more isolation.
local global_helpers = require('test.helpers')

-- Bypass CI behaviour logic
global_helpers.is_ci = function(_)
    return false
end

global_helpers.isCI = global_helpers.is_ci

local helpers = require('test.functional.helpers')(nil)
