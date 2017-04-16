return {
  warFieldName = "保 持 微 笑",
  authorName   = "mori420/3Au",
  playersCount = 2,

  width = 16,
  height = 20,

  advancedSettings = {
    targetTurnsCount = 20,
  },

  layers = {
    {
      type = "tilelayer",
      name = "tileBase",
      x = 0,
      y = 0,
      width = 16,
      height = 20,
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      properties = {},
      encoding = "lua",
      data = {
        1, 12, 1, 1, 1, 1, 1, 1, 1, 1, 1, 99, 54, 52, 52, 27,
        1, 10, 9, 1, 1, 1, 1, 1, 1, 1, 1, 1, 84, 22, 18, 34,
        1, 1, 12, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 84, 22, 34,
        1, 8, 11, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 84, 35,
        1, 12, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 98,
        1, 6, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 99, 100, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        7, 7, 11, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 8, 7, 7,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 6, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 99, 100, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 5, 1,
        97, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 12, 1,
        40, 82, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 8, 11, 1,
        38, 20, 82, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 12, 1, 1,
        38, 18, 20, 82, 1, 1, 1, 1, 1, 1, 1, 1, 1, 10, 9, 1,
        27, 43, 43, 44, 100, 1, 1, 1, 1, 1, 1, 1, 1, 1, 12, 1
      }
    },
    {
      type = "tilelayer",
      name = "tileObject",
      x = 0,
      y = 0,
      width = 16,
      height = 20,
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      properties = {},
      encoding = "lua",
      data = {
        101, 112, 154, 101, 101, 101, 123, 0, 0, 105, 106, 0, 129, 129, 129, 129,
        0, 0, 0, 149, 0, 0, 0, 0, 154, 0, 123, 0, 0, 129, 128, 129,
        0, 154, 112, 101, 107, 154, 149, 154, 123, 124, 0, 154, 0, 0, 129, 129,
        170, 0, 0, 0, 105, 101, 101, 108, 104, 0, 124, 0, 0, 154, 0, 129,
        0, 0, 164, 0, 124, 124, 125, 0, 102, 124, 171, 0, 0, 0, 0, 0,
        0, 0, 0, 174, 124, 124, 0, 151, 110, 124, 123, 0, 171, 0, 154, 123,
        154, 0, 0, 0, 126, 0, 0, 0, 102, 0, 0, 0, 125, 124, 0, 0,
        0, 154, 0, 0, 0, 154, 123, 0, 105, 154, 104, 0, 124, 0, 0, 0,
        0, 113, 0, 125, 149, 101, 104, 126, 0, 0, 102, 0, 123, 124, 103, 154,
        149, 109, 101, 101, 101, 107, 108, 154, 125, 124, 102, 149, 159, 124, 102, 125,
        125, 102, 124, 159, 149, 102, 124, 125, 154, 107, 108, 101, 101, 101, 110, 149,
        154, 106, 124, 123, 0, 102, 0, 0, 126, 105, 101, 149, 125, 0, 113, 0,
        0, 0, 0, 124, 0, 105, 154, 104, 0, 123, 154, 0, 0, 0, 154, 0,
        0, 0, 124, 125, 0, 0, 0, 102, 0, 0, 0, 126, 0, 0, 0, 154,
        123, 154, 0, 170, 0, 123, 124, 109, 150, 0, 124, 124, 176, 0, 0, 0,
        0, 0, 0, 0, 0, 169, 124, 102, 0, 125, 124, 124, 0, 164, 0, 0,
        129, 0, 154, 0, 0, 124, 0, 105, 107, 101, 101, 104, 0, 0, 0, 171,
        129, 129, 0, 0, 154, 0, 124, 123, 154, 149, 154, 108, 101, 112, 154, 0,
        129, 128, 129, 0, 0, 123, 0, 154, 0, 0, 0, 0, 149, 0, 0, 0,
        129, 129, 129, 129, 0, 103, 104, 0, 0, 123, 101, 101, 101, 154, 112, 101
      }
    },
    {
      type = "tilelayer",
      name = "unit",
      x = 0,
      y = 0,
      width = 16,
      height = 20,
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      properties = {},
      encoding = "lua",
      data = {
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 211, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
      }
    }
  }
}
