
local ModelWarCommandBar = class("ModelWarCommandBar")

ModelWarCommandBar.BUTTON_TYPE_NAMES = {
    UNIT_ACTION_ATTACK       = "c03_t02_s09_f01.png",
    UNIT_ACTION_BUILD_TILE   = "c03_t02_s12_f01.png",
    UNIT_ACTION_CAPTURE      = "c03_t02_s11_f01.png",
    UNIT_ACTION_DIVE         = "c03_t02_s16_f01.png",
    UNIT_ACTION_DROP         = "c03_t02_s14_f01.png",
    UNIT_ACTION_JOIN         = "c03_t02_s15_f01.png",
    UNIT_ACTION_FLARE        = "c03_t02_s18_f01.png",
    UNIT_ACTION_SILO         = "c03_t02_s10_f01.png",
    UNIT_ACTION_LOAD         = "c03_t02_s13_f01.png",
    UNIT_ACTION_PRODUCE_UNIT = "c03_t02_s12_f01.png",
    UNIT_ACTION_SUPPLY       = "c03_t02_s19_f01.png",
    UNIT_ACTION_SURFACE      = "c03_t02_s17_f01.png",
    UNIT_ACTION_WAIT         = "c03_t02_s08_f01.png",
}

function ModelWarCommandBar:ctor()
end

function ModelWarCommandBar:showButtons(buttonsInfo)
end

return ModelWarCommandBar
