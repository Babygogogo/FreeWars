return {
  warFieldName = "囚 笼 拘 束",
  authorName   = "3Au",
  playersCount = 2,

  width = 30,
  height = 20,
  layers = {
	{
	  type = "tilelayer",
	  name = "tileBase",
	  x = 0,
	  y = 0,
	  width = 30,
	  height = 20,
	  visible = true,
	  opacity = 1,
	  offsetx = 0,
	  offsety = 0,
	  properties = {},
	  encoding = "lua",
	  data = {
18,18,18,18,18,19,43,23,43,43,22,18,1,18,18,18,43,43,43,43,43,43,18,18,18,18,18,18,18,18,
18,19,43,43,43,47,1,51,1,1,49,22,18,19,43,47,1,1,1,1,1,1,38,19,66,22,18,18,18,18,
18,34,1,1,1,1,1,1,1,1,1,38,19,47,1,1,1,1,1,1,1,1,38,68,1,67,18,18,19,22,
18,34,1,1,1,1,1,1,1,1,59,45,35,1,1,1,1,1,1,1,1,1,38,20,65,26,18,18,20,26,
18,34,1,1,63,61,62,1,1,1,42,1,40,52,52,56,1,1,1,1,1,1,49,23,66,66,66,66,22,18,
18,34,1,1,1,1,1,1,1,59,48,1,38,18,18,20,56,1,1,1,1,60,1,51,1,1,1,1,49,22,
18,34,1,1,1,1,1,1,63,48,1,1,39,43,18,19,44,62,1,1,1,51,1,1,1,1,1,1,1,38,
18,18,52,53,62,1,1,1,1,1,1,59,48,1,38,34,1,1,1,1,1,1,1,1,1,1,1,1,1,38,
18,18,18,47,1,1,1,1,1,63,61,48,1,1,38,34,1,1,1,1,1,59,62,1,1,1,1,1,1,38,
19,43,47,1,1,1,1,1,60,1,1,1,1,1,38,34,1,1,1,1,1,42,1,1,1,1,1,1,1,38,
34,1,1,1,1,1,1,1,42,1,1,1,1,1,38,34,1,1,1,1,1,51,1,1,1,1,1,58,52,26,
34,1,1,1,1,1,1,63,48,1,1,1,1,1,38,34,1,1,59,61,62,1,1,1,1,1,58,26,18,18,
34,1,1,1,1,1,1,1,1,1,1,1,1,1,38,34,1,59,48,1,1,1,1,1,1,63,45,43,22,18,
34,1,1,1,1,1,1,1,60,1,1,1,63,54,26,20,52,36,1,1,59,62,1,1,1,1,1,1,38,18,
20,56,1,1,1,1,60,1,51,1,1,1,1,49,22,18,18,34,1,59,48,1,1,1,1,1,1,1,38,22,
18,20,65,65,65,65,28,56,1,1,1,1,1,1,49,43,43,35,1,42,1,1,1,63,61,62,1,1,38,18,
19,22,18,18,19,66,22,34,1,1,1,1,1,1,1,1,1,40,53,48,1,1,1,1,1,1,1,1,38,18,
20,26,18,18,68,1,67,34,1,1,1,1,1,1,1,1,58,26,34,1,1,1,1,1,1,1,1,1,38,18,
18,18,18,18,20,65,26,34,1,1,1,1,1,1,58,52,26,18,20,56,1,1,60,1,58,52,52,52,26,18,
18,18,18,18,18,18,18,18,52,52,52,52,52,52,26,18,18,1,18,20,52,52,28,52,26,18,18,18,18,18
	  }
	},
	{
	  type = "tilelayer",
	  name = "tileObject",
	  x = 0,
	  y = 0,
	  width = 30,
	  height = 20,
	  visible = true,
	  opacity = 1,
	  offsetx = 0,
	  offsety = 0,
	  properties = {},
	  encoding = "lua",
	  data = {
0,0,0,0,0,0,179,0,0,0,0,0,130,0,0,0,0,0,0,0,0,0,0,0,130,0,0,0,0,0,
130,0,0,0,0,0,0,0,123,0,0,0,0,0,0,0,203,208,208,208,208,206,0,0,0,0,0,0,130,0,
0,0,154,155,103,170,0,170,104,149,174,0,0,0,203,208,205,154,154,169,104,209,0,0,159,0,130,0,0,0,
0,0,103,101,108,150,155,123,102,0,0,0,0,198,205,123,149,174,124,124,102,209,0,0,0,0,0,0,0,0,
0,0,102,124,0,0,0,124,102,123,0,197,0,0,0,0,124,124,124,123,102,195,0,0,0,0,0,0,0,0,
0,0,102,123,124,124,124,103,106,0,0,209,0,0,0,0,0,135,143,101,101,0,123,0,197,123,154,123,179,0,
0,0,105,101,101,101,101,106,0,0,203,205,0,0,0,0,0,0,141,147,194,0,149,198,205,103,101,101,104,0,
0,0,0,0,0,102,124,124,134,154,195,0,0,103,112,112,107,101,101,101,107,101,101,147,101,106,124,123,102,0,
130,0,0,0,124,102,124,140,142,0,0,0,123,102,0,0,102,124,123,154,102,0,0,146,169,124,124,154,102,0,
0,0,0,123,103,154,124,146,0,103,101,101,101,108,112,112,106,124,124,154,102,0,140,142,124,103,101,101,106,0,
0,103,101,101,106,124,140,142,0,102,154,124,124,103,112,112,107,101,101,101,106,0,146,124,154,102,123,0,0,0,
0,102,154,124,124,169,146,0,0,102,154,123,124,102,0,0,102,123,0,0,0,140,142,124,103,106,0,0,0,130,
0,102,123,124,103,101,147,101,101,108,101,101,101,108,112,112,106,0,0,197,154,132,124,124,102,0,0,0,0,0,
0,105,101,101,106,203,196,149,0,194,147,143,0,0,0,0,0,0,203,205,0,0,103,101,108,101,101,104,0,0,
0,179,123,154,123,195,0,123,0,103,101,141,133,0,0,0,0,0,209,0,0,103,106,124,124,124,123,102,0,0,
0,0,0,0,0,0,0,0,197,102,123,124,124,124,0,0,0,0,195,0,123,102,124,0,0,0,124,102,0,0,
0,0,0,0,0,0,0,0,209,102,124,124,174,149,123,203,196,0,0,0,0,102,123,156,151,107,101,106,0,0,
0,0,0,130,0,159,0,0,209,105,169,154,154,203,208,205,0,0,0,174,149,105,171,0,171,106,156,154,0,0,
0,130,0,0,0,0,0,0,204,208,208,208,208,205,0,0,0,0,0,0,0,123,0,0,0,0,0,0,0,130,
0,0,0,0,0,130,0,0,0,0,0,0,0,0,0,0,0,130,0,0,0,0,0,179,0,0,0,0,0,0
	  }
	},
	{
	  type = "tilelayer",
	  name = "unit",
	  x = 0,
	  y = 0,
	  width = 30,
	  height = 20,
	  visible = true,
	  opacity = 1,
	  offsetx = 0,
	  offsety = 0,
	  properties = {},
	  encoding = "lua",
	  data = {
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,219,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	  }
	}
  }
}
