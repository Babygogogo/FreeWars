
local SkillData = {}

SkillData.minBasePoints                   = 0
SkillData.maxBasePoints                   = 200
SkillData.basePointsPerStep               = 25
SkillData.minEnergyRequirement            = 1
SkillData.maxEnergyRequirement            = 15
SkillData.skillPointsPerEnergyRequirement = 100
SkillData.skillDeclarationCost            = 2500
SkillData.damageCostPerEnergyRequirement  = 18000
SkillData.damageCostGrowthRates           = 20
SkillData.skillConfigurationsCount        = 10
SkillData.passiveSkillSlotsCount          = 4
SkillData.activeSkillSlotsCount           = 4

SkillData.categories = {
    ["SkillsActive"] = {
        1, 2, 3, 4, 5, 6, 7, 9, 10,
    },

    ["SkillsPassive"] = {
        1, 2, 5, 6, 8,
    },

    ["SkillCategoriesForPassive"] = {
        "SkillCategoryPassiveAttack",
        "SkillCategoryPassiveDefense",
        "SkillCategoryPassiveMoney",
        "SkillCategoryPassiveMovement",
        "SkillCategoryPassiveAttackRange",
        "SkillCategoryPassiveCapture",
        "SkillCategoryPassiveRepair",
        "SkillCategoryPassivePromotion",
        "SkillCategoryPassiveEnergy",
        "SkillCategoryPassiveVision",
    },

    ["SkillCategoriesForActive"] = {
        "SkillCategoryActiveAttack",
        "SkillCategoryActiveDefense",
        "SkillCategoryActiveMoney",
        "SkillCategoryActiveMovement",
        "SkillCategoryActiveAttackRange",
        "SkillCategoryActiveCapture",
        "SkillCategoryActiveHP",
        "SkillCategoryActivePromotion",
        "SkillCategoryActiveEnergy",
        "SkillCategoryActiveLogistics",
        "SkillCategoryActiveVision",
    },

    ["SkillCategoryPassiveAttack"] = {
        1,
        20,
        23,
        14,
        25,
        29,
        30,
        31,
        32,
        33,
        34,
        35,
        36,
    },

    ["SkillCategoryActiveAttack"] = {
        1,
        20,
        23,
        14,
        25,
        29,
        30,
        31,
        32,
        33,
        34,
        35,
        36,
    },

    ["SkillCategoryPassiveDefense"] = {
        2,
        21,
        24,
        37,
        38,
        39,
        40,
        41,
        42,
        43,
        44,
        45,
    },

    ["SkillCategoryActiveDefense"] = {
        2,
        21,
        24,
        37,
        38,
        39,
        40,
        41,
        42,
        43,
        44,
        45,
    },

    ["SkillCategoryPassiveMoney"] = {
        3,
        17,
        20,
        21,
        22,
    },

    ["SkillCategoryActiveMoney"] = {
        3,
        12,
        20,
        21,
        22,
    },

    ["SkillCategoryPassiveMovement"] = {
        28,
        54,
    },

    ["SkillCategoryActiveMovement"] = {
        6,
        8,
        28,
        46,
        47,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
    },

    ["SkillCategoryPassiveAttackRange"] = {
        7,
    },

    ["SkillCategoryActiveAttackRange"] = {
        7,
    },

    ["SkillCategoryPassiveCapture"] = {
        15,
    },

    ["SkillCategoryActiveCapture"] = {
        15,
    },

    ["SkillCategoryPassiveRepair"] = {
        10,
        11,
    },

    ["SkillCategoryPassiveEnergy"] = {
        18,
        19,
    },

    ["SkillCategoryActiveEnergy"] = {
        13,
        61,
    },

    ["SkillCategoryActiveHP"] = {
        4,
        5,
    },

    ["SkillCategoryPassivePromotion"] = {
        27,
    },

    ["SkillCategoryActivePromotion"] = {
        26,
    },

    ["SkillCategoryActiveLogistics"] = {
        9,
        16,
    },

    ["SkillCategoryPassiveVision"] = {
        55,
        56,
        57,
        58,
        59,
        60,
    },

    ["SkillCategoryActiveVision"] = {
        55,
        56,
        57,
        58,
        59,
        60,
    },
}

SkillData.skills = {
    -- Modify the attack power for all units of a player.
    [1] = {
        minLevelPassive     = 1,
        maxLevelPassive     = 5,
        minLevelActive      = 1,
        maxLevelActive      = 5,
        modifierUnit = "%",
        levels = {
            [1] = {modifierPassive = 5, pointsPassive = 10000, modifierActive = 10, pointsActive = 5000},
            [2] = {modifierPassive = 10, pointsPassive = 20000, modifierActive = 20, pointsActive = 10000},
            [3] = {modifierPassive = 15, pointsPassive = 30000, modifierActive = 30, pointsActive = 15000},
            [4] = {modifierPassive = 20, pointsPassive = 40000, modifierActive = 40, pointsActive = 20000},
            [5] = {modifierPassive = 25, pointsPassive = 50000, modifierActive = 50, pointsActive = 25000},
        },
    },

    -- Modify the defense power for all units of a player.
    [2] = {
        minLevelPassive     = 1,
        maxLevelPassive     = 5,
        minLevelActive      = 1,
        maxLevelActive      = 5,
        modifierUnit = "%",
        levels = {
            [1] = {modifierPassive = 6, pointsPassive = 10000, modifierActive = 20, pointsActive = 5000},
            [2] = {modifierPassive = 12, pointsPassive = 20000, modifierActive = 40, pointsActive = 10000},
            [3] = {modifierPassive = 18, pointsPassive = 30000, modifierActive = 60, pointsActive = 15000},
            [4] = {modifierPassive = 24, pointsPassive = 40000, modifierActive = 80, pointsActive = 20000},
            [5] = {modifierPassive = 30, pointsPassive = 50000, modifierActive = 100, pointsActive = 25000},
        },
    },

    -- Instant: Modify HPs of all units of the currently-in-turn player.
    [3] = {
        minLevelPassive     = nil,
        maxLevelPassive     = nil,
        minLevelActive      = 1,
        maxLevelActive      = 5,
        modifierUnit = "",
        levels = {
            [1] = {modifierPassive = nil, pointsPassive = nil, modifierActive = 1, pointsActive = 7500},
            [2] = {modifierPassive = nil, pointsPassive = nil, modifierActive = 2, pointsActive = 15000},
            [3] = {modifierPassive = nil, pointsPassive = nil, modifierActive = 3, pointsActive = 22500},
            [4] = {modifierPassive = nil, pointsPassive = nil, modifierActive = 4, pointsActive = 30000},
            [5] = {modifierPassive = nil, pointsPassive = nil, modifierActive = 5, pointsActive = 37500},
        },
    },

    -- Instant: Modify HPs of all units of the opponents.
    [4] = {
        minLevelPassive     = nil,
        maxLevelPassive     = nil,
        minLevelActive      = 1,
        maxLevelActive      = 5,
        modifierUnit = "",
        levels = {
            [1] = {modifierPassive = nil, pointsPassive = nil, modifierActive = -1, pointsActive = 17500},
            [2] = {modifierPassive = nil, pointsPassive = nil, modifierActive = -2, pointsActive = 35000},
            [3] = {modifierPassive = nil, pointsPassive = nil, modifierActive = -3, pointsActive = 52500},
            [4] = {modifierPassive = nil, pointsPassive = nil, modifierActive = -4, pointsActive = 70000},
            [5] = {modifierPassive = nil, pointsPassive = nil, modifierActive = -5, pointsActive = 87500},
        },
    },

    -- Modify movements of all units of the owner player.
    [5] = {
        minLevelPassive    = 1,
        maxLevelPassive    = 5,
        minLevelActive     = 1,
        maxLevelActive     = 5,
        modifierUnit = "",
        levels = {
            [1] = {modifierPassive = 1, pointsPassive = 50000, modifierActive = 1, pointsActive = 12500},
            [2] = {modifierPassive = 2, pointsPassive = 100000, modifierActive = 2, pointsActive = 25000},
            [3] = {modifierPassive = 3, pointsPassive = 150000, modifierActive = 3, pointsActive = 37500},
            [4] = {modifierPassive = 4, pointsPassive = 200000, modifierActive = 4, pointsActive = 50000},
            [5] = {modifierPassive = 5, pointsPassive = 250000, modifierActive = 5, pointsActive = 62500},
        },
    },

    -- Modify max attack range of all indirect units of the owner player.
    [6] = {
        minLevelPassive    = 1,
        maxLevelPassive    = 5,
        minLevelActive     = 1,
        maxLevelActive     = 5,
        modifierUnit = "",
        levels = {
            [1] = {modifierPassive = 1, pointsPassive = 30000, modifierActive = 1, pointsActive = 7500},
            [2] = {modifierPassive = 2, pointsPassive = 60000, modifierActive = 2, pointsActive = 15000},
            [3] = {modifierPassive = 3, pointsPassive = 90000, modifierActive = 3, pointsActive = 22500},
            [4] = {modifierPassive = 4, pointsPassive = 120000, modifierActive = 4, pointsActive = 30000},
            [5] = {modifierPassive = 5, pointsPassive = 150000, modifierActive = 5, pointsActive = 37500},
        },
    },

    -- Instant: Lightning strike (move again).
    [7] = {
        minLevelPassive    = nil,
        maxLevelPassive    = nil,
        minLevelActive     = 1,
        maxLevelActive     = 1,
        modifierUnit = "",
        levels       = {
            [1] = {modifierPassive = nil, pointsPassive = nil, modifierActive = nil, pointsActive = 40000},
        },
    },

    -- Modify the income of the owner player.
    [8] = {
        minLevelPassive     = 1,
        maxLevelPassive     = 5,
        minLevelActive      = nil,
        maxLevelActive      = nil,
        modifierUnit = "%",
        levels       = {
            [1] = {modifierPassive = 5, pointsPassive = 15000, modifierActive = nil, pointsActive = nil},
            [2] = {modifierPassive = 10, pointsPassive = 30000, modifierActive = nil, pointsActive = nil},
            [3] = {modifierPassive = 15, pointsPassive = 45000, modifierActive = nil, pointsActive = nil},
            [4] = {modifierPassive = 20, pointsPassive = 60000, modifierActive = nil, pointsActive = nil},
            [5] = {modifierPassive = 15, pointsPassive = 75000, modifierActive = nil, pointsActive = nil},
        },
    },

    -- Instant: Modify the fund of the owner player.
    [9] = {
        minLevelPassive    = nil,
        maxLevelPassive    = nil,
        minLevelActive     = 1,
        maxLevelActive     = 5,
        modifierUnit = "%",
        levels       = {
            [1] = {modifierPassive = nil, pointsPassive = nil, modifierActive = 20, pointsActive = 5000},
            [2] = {modifierPassive = nil, pointsPassive = nil, modifierActive = 40, pointsActive = 10000},
            [3] = {modifierPassive = nil, pointsPassive = nil, modifierActive = 60, pointsActive = 15000},
            [4] = {modifierPassive = nil, pointsPassive = nil, modifierActive = 80, pointsActive = 20000},
            [5] = {modifierPassive = nil, pointsPassive = nil, modifierActive = 100, pointsActive = 25000},
        },
    },

    -- Instant: Modify the energy of the opponent player.
    [10] = {
        minLevelPassive    = nil,
        maxLevelPassive    = nil,
        minLevelActive     = 1,
        maxLevelActive     = 5,
        modifierUnit = "",
        levels       = {
            [1] = {modifierPassive = nil, pointsPassive = nil, modifierActive = -4000, pointsActive = 5000},
            [2] = {modifierPassive = nil, pointsPassive = nil, modifierActive = -8000, pointsActive = 10000},
            [3] = {modifierPassive = nil, pointsPassive = nil, modifierActive = -12000, pointsActive = 15000},
            [4] = {modifierPassive = nil, pointsPassive = nil, modifierActive = -16000, pointsActive = 20000},
            [5] = {modifierPassive = nil, pointsPassive = nil, modifierActive = -20000, pointsActive = 25000},
        },
    },
}

return SkillData
