
local ResourceManager = {}

local CAP_INSETS = {
    ["c03_t01_s05_f01.png"] = {x = 9, y = 9, width = 1, height = 1},
}

function ResourceManager.getCapInsets(imageName)
    local capInsets = CAP_INSETS[imageName]
    assert(capInsets, "ResourceManager.getCapInsets() failed to find the cap insets for image: " .. (imageName or ""))
    return CAP_INSETS[imageName]
end

return ResourceManager
