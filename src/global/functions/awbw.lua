local AWBW={}

--据点码表
local capturable={
	City={34,38,43,48,53,81,86,91,96,119,124,151,158,165,172},
	Factory={35,39,44,49,54,82,87,92,97,118,123,150,157,164,171},
	AirFactory={36,40,45,50,55,83,88,93,98,117,122,149,156,163,170},
	ShipFactory={37,41,46,51,56,84,89,94,99,121,126,155,162,169,176},
	HQ={42,47,52,57,85,90,95,100,120,125,153,160,167,174},
	ComTower={127,128,129,130,131,132,133,134,135,136,137,152,159,166,173},
	Lab={138,139,140,141,142,143,144,145,146,147,148,154,161,168,175}
}

--势力码表
local troops={
	OrangeStar={38,39,40,41,42,134,146},
	BlueMoon={43,44,45,46,47,129,140},
	GreenEarth={48,49,50,51,52,131,142},
	YellowComet={53,54,55,56,57,136,148},
	BlackHole={91,92,93,94,95,128,139},
	RedFire={81,82,83,84,85,135,147},
	GreySky={86,87,88,89,90,137,143},
	BrownDesert={96,97,98,99,100,130,141},
	AmberBlaze={117,118,119,120,121,127,138},
	JadeSun={122,123,124,125,126,132,144},
	CobaltIce={149,150,151,152,153,154,155},
	PinkCosmos={153,157,158,159,160,161,162},
	TealGalaxy={163,164,165,166,167,168,169},
	PurpleLightning={170,171,172,173,174,175,176}
}

--获取id对应的名称
local function strName(tab,id)
	for k1,v1 in pairs(tab) do
		for k2,v2 in ipairs(v1) do
			if id == v2 then
				return k1
			end
		end
	end
end

--获取id对应的据点名称
local function strCaptureName(id)
	return strName(capturable,id)
end

--获取id对应的部队名称
local function strTroopName(id)
	return strName(troops,id)
end

--势力名称映射表
local troopNames={
	{"os","OrangeStar"},
	{"bm","BlueMoon"},
	{"ge","GreenEarth"},
	{"yc","YellowComet"},
	{"bh","BlackHole"},
	{"rf","RedFire"},
	{"gk","GreySky"},
	{"bd","BrownDesert"},
	{"ab","AmberBlaze"},
	{"js","JadeSun"},
	{"ci","CobaltIce"},
	{"pc","PinkCosmos"},
	{"tg","TealGalaxy"},
	{"pl","PurpleLightning"},
}

--兵种名称映射表
local corpNames={
	{"infantry","Infantry"},
	{"mech","Mech"},
	{"apc","APC"},
	{"recon","Recon"},
	{"rocket","Rockets"},
	{"missile","Missiles"},
	{"artillery","Artillery"},
	{"anti-air","AntiAir"},
	{"tank","Tank"},
	{"mdtank","MiddleTank"},
	{"neotank","NeoTank"},
	{"megatank","MegaTank"},
	{"piperunner","PipeRunner"},
	{"t-copter","TransportCopter"},
	{"b-copter","BattleCopter"},
	{"fighter","Fighter"},
	{"bomber","Bomber"},
	{"stealth","Stealth"},
	{"blackbomb","BlackBomb"},
	{"lander","Lander"},
	{"battleship","BattleShip"},
	{"cruiser","Cruiser"},
	{"sub","SubMarine"},
	{"carrier","Carrier"},
	{"blackboat","BlackBoat"}
};

--根据id查询图块名字
local function strTerrainName(id)
	if id==1 then return "Plain";
	elseif id==2 then return "Mountain";
	elseif id==3 then return "Wood";
	elseif id>=4 and id<=14 then return "River";
	elseif id>=15 and id<=25 then return "Road";
	elseif id>=26 and id<=27 then return "Bridge";
	elseif id==28 then return "Sea";
	elseif id>=29 and id<=32 then return "Shoal";
	elseif id==33 then return "Reef";
	elseif id>=101 and id<=110 then return "Pipe";
	elseif id==111 then return "Silo";
	elseif id==112 then return "SiloEmpty";
	elseif id>=113 and id<=114 then return "PipeSeam";
	elseif id>=115 and id<=116 then return "PipeRubble";
	else
		return strCaptureName(id)
	end
end

--分离字符串(被分离的字符串,分隔符号)
local function splitString(str,symbol)
	local tab={}
	local startPos,endPos=1,string.find(str,symbol)
	while endPos do
		table.insert(tab,string.sub(str,startPos,endPos-1))
		--下一个
		startPos=endPos+1
		endPos=string.find(str,symbol,startPos)
	end
	table.insert(tab,string.sub(str,startPos))--最后一个
	return tab
end

--地图尺寸和对应的地形
local mapW,mapH=0,0
local terrainsTable={}

--分析地形码
function AWBW.analyseMapTxt(txtFile)
	txtFile:seek('set')
	--准备读取
	local line,x,y=nil,0,0--缓存
	local info={}
	local startStr='<td>'
	--开始读取
	repeat--逐行处理
		line=txtFile:read()
		if line then
			local pos=string.find(line,startStr)--寻找行开始
			if pos then
				pos = pos + string.len(startStr)
				local endPos=string.find(line,'</td>',pos)--寻找行末
				if type(endPos)=='number' and endPos > pos then
					local lineData=string.sub(line,pos,endPos-1)
					local tab=splitString(lineData,",")
					--开始解析数据
					x=0
					for k,v in pairs(tab) do
						local num=tonumber(v)
						if type(num)=="number" then
							info.name=strTerrainName(num)
							info.troop=strTroopName(num)
						else
							info.name=nil
							info.troop=nil
						end
						info.x=x
						info.y=y
						table.insert(terrainsTable,info)
						--下一个
						x=x+1
					end
					y=y+1
				end
			end
		end
	until not line--直到文件结束
	mapW,mapH=x,y
	txtFile:close()
end

local mapName,author
--分析单位码
function AWBW.analyseMapHtml(htmlFile)
	htmlFile:seek("set")
	--准备缓冲,开始分析
	local line,pos,endPos
	repeat--逐行处理
		line=htmlFile:read()
		if line then
			if not mapName then--地图名先出现
				pos=string.find(line,"valign=top>")--过滤出可能有地图名的行
				if pos then
					line=htmlFile:read()--下一行有地图名
					pos=string.find(line,"<b>")
					pos=pos+3--指向地图名
					endPos=string.find(line,"</b>",pos)
					if endPos then
						while string.byte(line,pos)==32 do--去掉所有首空格
							pos=pos+1
						end
					end
					mapName=string.sub(line,pos,endPos-1)--得到了地图名
				end
			elseif not author then--作者名在地图名之后
			--[[char *start=strstr(buffer," by");
			if(!start)continue;
			start=strstr(start,">");
			if(!start)continue;
			++start;//指向作者名
			char *fin=strstr(start,"</a>");
			if(fin){
				*fin='\0';//把start变成字符串
				author=start;//得到了作者名
			}]]
			else
			--[[char *start,*fin;
			start=strstr(buffer,"<span style=");
			if(!start)continue;
			fin=strstr(start,"</span>");
			if(!fin)continue;
			//得到行数据,开始分析
			analyseMapHtml_line(start);]]
			end
		end
	until not line
	--fclose(file);
	--addQuotes(mapName);
	--addQuotes(author);
	return true;
end

return AWBW
