--[[新CO
这是下载模块,可以利用相关协议从网络上下载需要的数据或文件

设计此模块的主要目的是能进行类似热更新的机制
比如,本项目地图文件是由Tiled这个地图编辑器生成的,如果要能玩上新地图的话,按照以前的做法,要打包到apk文件中(电脑系统的玩家更新版本库就能用了)
这样的话,相当于每次更新地图的话都要打个包给爪机党,又要下载覆盖安装....
那么,我们为何不进行热更新呢?
此项目开源,那么我们可以考虑在游戏启动的时候,检查版本库上的地图文件进行热更新,那么只要版本库有更新,我们就能拿到新地图了
这样可以减少打包的次数
]]
local writablePath=cc.FileUtils:getInstance():getWritablePath()
local Downloader={}
--显示消息(消息内容),这个函数需要依赖Babygogogo少年写的东西
local function showMessage(message)
	if Downloader.indicator then Downloader.indicator:showMessage(message) end
end

--从url中获取文件名,返回文件名和是否是文件(即非目录)
local function getFilenameFromUrl(url)
	local filename,isFile=nil,true--这俩是返回值
	local len,pos,endPos=string.len(url),1,1
	repeat
		endPos=string.find(url,'/',pos)--寻找'/'
		if type(endPos)=='number' then
			if endPos<len then--'/'不是最后一个字符,继续寻找
				pos = pos + 1
			else--'/'是最后一个字符,那么应该判定为目录
				filename=string.sub(url,pos,endPos-1)
				isFile=false
				pos=nil
			end
		else--找不到'/',那么应该判定为文件名
			filename=string.sub(url,pos)
			pos=nil
		end
	until not pos
	return filename,isFile
end
--写文件(文件名,内容),返回是否成功
local function writeFile(filename,data)
	local file=io.open(filename,'wb')
	if file then
		file:write(data)
		file:flush()
		file:close()
		return true
	else
		return false
	end
end
local toDownloadFileList={}--待下载的文件的缓冲列表
--获取文件名列表(url目录名,本地对应url的目录名,url返回的临时内容文件)
local function getFilenameList(url,filename,tempFile)
	tempFile:seek('set')
	local line--缓存
	local startStr='<a href="'
	repeat--逐行读取
		line=tempFile:read()
		if line then--处理行数据
			local pos=string.find(line,startStr)
			if pos==1 then--可以确定子文件名在line中的位置
				pos = pos + string.len(startStr)
				local endPos=string.find(line,'"',pos)
				if type(endPos)=='number' and endPos > pos then
					local subFilename=string.sub(line,pos,endPos-1)--得到了子文件名
					table.insert(toDownloadFileList,
						{url..subFilename,filename..subFilename})--缓存起来,等待下载
				end
			end
		end
	until not line--直到文件结束
	tempFile:close()
end
--下载下一个文件,相关信息从toDownloadFileList获取
local function downloadNext()
	if table.maxn(toDownloadFileList)>0 then
		local url,filename=toDownloadFileList[1][1],toDownloadFileList[1][2]
		Downloader.httpDownload(url,filename)--开始下载
		table.remove(toDownloadFileList,1)--执行下载代码后就可以移除了
	end
end
--http下载(网络url,本地文件名),把url上的数据保存到对应本地文件名的文件中
function Downloader.httpDownload(url,filename)
	local xhr = cc.XMLHttpRequest:new()--创建请求
	local function onReadyStateChange()--回调函数,用于处理异步请求
		if xhr.readyState == 0 then
			print('http:请求未初始化')
		elseif xhr.readyState == 1 then
			print('http:服务器连接已建立')
		elseif xhr.readyState == 2 then
			print('http:请求已发送')
		elseif xhr.readyState == 3 then
			print('http:正在接收响应')
		elseif xhr.readyState == 4 then
			print('http:请求完成,响应就绪')
			print('状态码'..xhr.status)
			print('状态文本:'..xhr.statusText)
			if xhr.status == 200 then
				local filename0,isFile=getFilenameFromUrl(url)
				if isFile then
					if writeFile(writablePath..filename,xhr.responseText) then
						showMessage(filename..'下载完成')
					else
						showMessage('写文件'..filename..'失败')
					end
				else
					local file=io.tmpfile()--把目录内容存成临时文件再分析
					if file then
						file:write(xhr.responseText)
						file:flush()
						--保存完成,开始分析
						getFilenameList(url,filename,file)
						os.execute('mkdir '..writablePath..filename)--创建目录
					else
						showMessage('临时文件打开失败')
					end
				end
			else
				showMessage('访问'..url..'服务器响应'..xhr.status..'文本'..xhr.statusText)
			end
			--不管是文件还是目录,不管下载是成功失败,我们应该继续下载下一个
			downloadNext()
		end
	end
	xhr:registerScriptHandler(onReadyStateChange)
	--返回的数据类型,从以下5个中选择1个
	--xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_STRING--字符串
	--xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_ARRAY_BUFFER--数组缓存
	xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_BLOB--二进制大对象
	--xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_DOCUMENT--文档对象
	--xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_JSON--json数据
	xhr:open("GET",url)--设定要请求的资源和方法
	xhr:send()--发送数据
end

return Downloader
