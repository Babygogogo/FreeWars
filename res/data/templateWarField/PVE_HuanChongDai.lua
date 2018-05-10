return {
  warFieldName = "缓 冲 带",
  authorName   = "RushFTK",
  playersCount = 2,

  width = 12,
  height = 9,

  layers = {
	{
	  type = "tilelayer",
	  name = "tileBase",
	  x = 0,
	  y = 0,
	  width = 12,
	  height = 9,
	  visible = true,
	  opacity = 1,
	  offsetx = 0,
	  offsety = 0,
	  properties = {},
	  encoding = "lua",
	  data = {
		1, 1, 58, 65, 27, 95, 89, 77, 66, 47, 1, 1,
		1, 1, 84, 22, 76, 93, 26, 47, 1, 5, 1, 1,
		1, 1, 1, 67, 72, 71, 34, 1, 3, 11, 1, 1,
		1, 1, 81, 26, 80, 92, 24, 56, 1, 1, 1, 1,
		1, 1, 49, 18, 20, 90, 79, 21, 61, 62, 1, 1,
		1, 1, 1, 38, 18, 80, 92, 35, 1, 1, 1, 1,
		1, 1, 63, 45, 22, 20, 90, 40, 56, 1, 1, 1,
		1, 1, 1, 1, 38, 18, 95, 67, 83, 1, 1, 1,
		1, 1, 1, 93, 45, 83, 93, 36, 1, 1, 1, 1
	  }
	},
	{
	  type = "tilelayer",
	  name = "tileObject",
	  x = 0,
	  y = 0,
	  width = 12,
	  height = 9,
	  visible = true,
	  opacity = 1,
	  offsetx = 0,
	  offsety = 0,
	  properties = {},
	  encoding = "lua",
	  data = {
		124, 154, 0, 0, 129, 0, 0, 0, 0, 0, 156, 156,
		154, 125, 0, 129, 0, 0, 0, 129, 171, 112, 123, 0,
		0, 154, 0, 0, 0, 0, 129, 103, 154, 0, 0, 151,
		123, 123, 0, 129, 0, 0, 191, 117, 124, 156, 103, 106,
		0, 175, 129, 114, 190, 0, 0, 129, 0, 100, 171, 154,
		170, 0, 124, 117, 128, 0, 0, 118, 125, 123, 124, 0,
		0, 0, 180, 0, 0, 0, 0, 191, 129, 124, 0, 0,
		150, 155, 0, 155, 0, 129, 0, 0, 0, 154, 123, 125,
		124, 170, 155, 0, 190, 0, 0, 129, 154, 108, 154, 124
	  }
	},
	{
	  type = "tilelayer",
	  name = "unit",
	  x = 0,
	  y = 0,
	  width = 12,
	  height = 9,
	  visible = true,
	  opacity = 0.75,
	  offsetx = 0,
	  offsety = 0,
	  properties = {},
	  encoding = "lua",
	  data = {
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	  }
	}
  }
}
