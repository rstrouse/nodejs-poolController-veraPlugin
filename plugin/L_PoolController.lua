--
-- NodeJS Pool Controller Plugin
-- Copyright (C) 2020 Robert Strouse
-- 
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
--
-- Version 1.0 2020-05-16 by Robert Strouse
-- * Initial Version
--

module("L_PoolController", package.seeall)
local pnl
local vars
local util
local logger
local comms
local const
local css
local json

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------
local function constAPI()
	local instance = {}
	instance.pluginVersion = "1.0"
	instance.serviceIds = { panel = "urn:rstrouse-com:serviceId:PoolController1",
		circuit = "urn:rstrouse-com:serviceId:PoolControllerCircuit1",
		feature = "urn:rstrouse-com:serviceId:PoolControllerFeature1",
		body = "urn:rstrouse-com:serviceId:PoolControllerBody1",
		heater = "urn:rstrouse-com:serviceId:PoolControllerHeater1",
		chlorinator = "urn:rstrouse-com:serviceId:PoolChlorinator1",
		intellichem = "urn:rstrouse-com:serviceId:PoolControllerIntellichem1",
		binary = "urn:upnp-org:serviceId:SwitchPower1",
		dimmer = "urn:upnp-org:serviceId:Dimming1",
		haDevice = "urn:micasaverde-com:serviceId:HaDevice1",
		energyMetering = "urn:micasaverde-com:serviceId:EnergyMetering1"}
	instance.formatTypes = {["PanelMessage"] = {["width"] = "90%",["color"] = "red",["fontSize"] = "1em",["bold"] = true,["italic"] = true,["position"] = "absolute",["top"] = "0px",["left"] = "0px"},
		["status"] = {["color"] = "red",["fontSize"] = ".7em",["bold"] = true,["italic"] = true,["width"] = "150px",["textAlign"] = "left"},
		["mode"] = {["color"] = "red",["fontSize"] = ".7em",["bold"] = true,["italic"] = true,["width"] = "150px",["textAlign"] = "left"},
		["temperature"] = {["color"] = "blue",["fontSize"] = ".8em",["bold"] = true,["textAlign"] = "right",["width"] = "37px",["format"] = "{0}&deg;"},
		["pumpSpeed"] = {["color"] = "blue",["fontSize"] = ".8em",["bold"] = true,["textAlign"] = "right",["width"] = "32px"},
		["pumpFlow"] = {["color"] = "blue",["fontSize"] = ".8em",["bold"] = true,["textAlign"] = "right",["width"] = "32px"},
		["energyUse"] = {["color"] = "blue",["fontSize"] = ".8em",["bold"] = true,["textAlign"] = "right",["width"] = "32px"},
		["filterPercent"] = {["color"] = "blue",["fontSize"] = ".8em",["bold"] = true,["textAlign"] = "right",["width"] = "32px"},
		["saltLevel"] = {["color"] = "blue",["fontSize"] = ".8em",["bold"] = true,["textAlign"] = "right",["width"] = "32px"},
		["orpLevel"] = {["color"] = "blue",["fontSize"] = ".8em",["bold"] = true,["textAlign"] = "right",["width"] = "32px"},
		["pHLevel"] = {["color"] = "green",["fontSize"] = ".8em",["bold"] = true,["textAlign"] = "right",["width"] = "32px"},  
		["saturationIndex"] = {["color"] = "red",["fontSize"] = ".8em",["bold"] = true,["textAlign"] = "right",["width"] = "32px"} 
		}

	return instance
end
----------------------------------------------------------------------
-- Utility Functions
----------------------------------------------------------------------
local function utilAPI() 
	local instance = {}
	function instance:isNil(val, default)
		if(val == nil) then
			return default
		end
		return val
	end
	function instance:nilIf(val1, val2)
		if(val1 == val2) then return nil end
		return val1
	end
	function instance:makeBool(val)
		if(val == nil) then return false
		elseif(type(val) == "boolean") then return val
		elseif(type(val) == "string") then
			local low = string.lower(val)
			if(val == "0" or val == "f" or val == "false") then return false end
		elseif(type(val) == "number") then
			if(tonumber(val) <= 0) then return false end
		end
		return true
	end
	function instance:roundNumber(val, decPlaces)
		if(decPlaces ~= nil and decPlaces > 0) then
			return math.floor(((val * 10^decPlaces) + 0.5) /(10^decPlaces))
		else
			return math.floor(val + 0.5)
		end
	end
	function instance:bitShift(val, shift)
		local newVal = 0
		if(shift or 0 >= 0) then
			newVal = val * 2 ^ shift
		else
			newVal = math.floor(val / 2 ^ math.abs(shift or 0))
		end
		return newVal
	end
	function instance:bitAnd(a, b)
		local result = 0
		local bitval = 1
		while a > 0 and b > 0 do
			if a % 2 == 1 and b % 2 == 1 then -- test the rightmost bits
				result = result + bitval      -- set the current bit
			end
			bitval = bitval * 2 -- shift left
			a = math.floor(a / 2) -- shift right
			b = math.floor(b / 2)
		end
		return result
	end
	function instance:bitTest(val, pos)
		local bit = bitShift(1, pos-1)
		return bitAnd(bit or 0, val or 0) == bit
	end
	function instance:splitString(input, sep)
		if sep == nil then
			sep = "%s"
		end
		local t = {} ; i = 1
		for str in string.gmatch(input, "([^"..sep.."]+)") do
			t[i] = str
			i = i + 1
		end
		return t
	end
	function instance:reloadLuup()
		if(luup.reload ~= nil) then
			luup.reload()
		else
			logger:debug("A luup reload was triggered for UI5")
			luup.call_action("urn:micasaverde-com:serviceId:HomeAutomationGateway1", "Reload", {}, 0)
		end
	end
	return instance
end
----------------------------------------------------------------------
-- Logger Functions
----------------------------------------------------------------------
local function loggerAPI(id) 
	local instance = {}
	-- Logger levels
	-- 0 or nil = Info
	-- 1 = verbose
	-- 2 = debug
	instance.deviceId = tonumber(id)
	local val, tstamp = luup.variable_get(const.serviceIds.panel, "logLevel", instance.deviceId)
	instance.level = tonumber(val) or 0
	function instance:setLogLevel(lvl)
		local l = tonumber(lvl)
		if(l == nil) then
			if(lvl == "error") then l = 0
			elseif(lvl == "info") then l = 20
			elseif(lvl == "verbose") then l = 50
			elseif(lvl == "debug") then l = 70
			else l = 0 end
		end
		vars:maybeSetVariable(const.serviceIds.panel, "logLevel", l, self.deviceId)
		self.level = l
		return self:getLogLevel()
	end
	function instance:getLogLevel()
		local lLevel = self.level
		local logLevel
		if(lLevel < 20) then logLevel = "error"
		elseif(lLevel < 50) then logLevel = "info"
		elseif(lLevel < 70) then logLevel = "verbose"
		else logLevel = "debug" end
		
		return lLevel, logLevel
	end
	function instance:debug(s)
		if(self.level >= 70) then luup.log(s) end
	end
	function instance.info(s)
		if(self == nil or self.level >= 20) then luup.log(s) end
	end
	function instance:verbose(s)
		if(self == nil or self.level >= 50) then luup.log(s) end
	end
	function instance:error(s)
		luup.log(s)
	end
	return instance
end
----------------------------------------------------------------------
-- Comms Functions
----------------------------------------------------------------------
local function commsAPI(id)
	local instance = {}
	instance.deviceId = tonumber(id)
	instance.ipAddress = luup.devices[instance.deviceId].ip
	instance.userName = vars:getVariable(const.serviceIds.panel, "userName", instance.deviceId, "")
	instance.password = vars:getVariable(const.serviceIds.panel, "password", instance.deviceId, "")
	instance.http = require("socket.http")
	instance.ltn12 = require("ltn12")
	function instance:clearCommFailures()
		if(luup.version_major < 6) then
			luup.set_failure(false)
		else
			luup.set_failure(0, self.deviceId)
		end
		vars:maybeSetVariable("urn:micasaverde-com:serviceId:HaDevice1", "CommFailure", 0, comms.deviceId)
		vars:maybeSetVariable("urn:micasaverde-com:serviceId:HaDevice1", "CommFailureTime", 0, comms.deviceId)
	end
	function instance:setCommFailure(sFailure)
		luup.log("Setting communication failure for nodejs-poolController: [" ..(sFailure or "nil") .. "]")
		if(luup.version_major < 6) then
			luup.set_failure(true)
		else
			luup.set_failure(1, self.deviceId)
		end
	end
	function instance:getJson(apiPath)
		logger:verbose("Performing GET " ..(self.ipAddress or "") .. (apiPath or ""))
		local statusCode, data, httpCode = luup.inet.wget("http://" ..(self.ipAddress or "") ..(apiPath or ""), 5, util:nilIf(self.userName, ""), util:nilIf(self.password, ""))
		logger:verbose("Status Code: " ..(statusCode or "null"))
		logger:verbose("httpCode: " ..(httpCode or "null"))
		logger:verbose("data: " ..(data or "null"))
		local obj = json:decode(data or "{}")
		return statusCode, obj, tonumber(httpCode or 500)
	end
	function instance:putJson(apiPath, data)
		local url = "http://" .. (self.ipAddress or "") .. (apiPath or "")
		logger:verbose("Performing PUT " .. url)
		local result = {}
		local body = json:encode(data)
		local headers = {["ACCEPT"] = "application/json", ["CONTENT-TYPE"] = "application/json;charset=utf-8", ["CONTENT-LENGTH"] = #body}
		local statusCode, httpCode = self.http.request{ url=url, headers=headers, source=self.ltn12.source.string(body), sink=self.ltn12.sink.table(result), method="PUT" }
		--logger:verbose("headers: " .. json:encode(headers))
		logger:verbose("Status Code: " .. (statusCode or "null"))
		logger:verbose("httpCode: " .. (httpCode or "null"))
		logger:verbose("body: " .. (body or "null"))
		logger:verbose("result: " .. json:encode(result))
		return statusCode, httpCode
	end
	function instance:deleteJson(path, data)
		local url = "http://" .. (self.ipAddress or "") .. (apiPath or "")
		logger:verbose("Performing DELETE " .. url)
		local body = json:encode(data)
		local headers = {["ACCEPT"] = "application/json", ["CONTENT-TYPE"] = "application/x-www-form-urlencoded", ["CONTENT-LENGTH"] = #body}
		local statusCode, httpCode = self.http.request{ url=url, headers=headers, source=self.ltn12.source.string(body), method="DELETE" }
		logger:verbose("Status Code: " .. (statusCode or "null"))
		logger:verbose("httpCode: " .. (httpCode or "null"))
		logger:verbose("body: " .. (body or "null"))
		return statusCode, httpCode
	end
	function instance:postJson(path, data)
		local url = "http://" .. (self.ipAddress or "") .. (apiPath or "")
		logger:verbose("Performing POST" .. url)
		local body = json:encode(data)
		local headers = {["ACCEPT"] = "application/json", ["CONTENT-TYPE"] = "application/x-www-form-urlencoded", ["CONTENT-LENGTH"] = #body}
		local statusCode, httpCode = self.http.request{ url=url, headers=headers, source=self.ltn12.source.string(body), method="POST" }
		logger:verbose("Status Code: " ..(statusCode or "null"))
		logger:verbose("httpCode: " ..(httpCode or "null"))
		logger:verbose("body: " ..(body or "null"))
		return statusCode, httpCode
	end
	return instance
end
----------------------------------------------------------------------
-- Variable Management Functions
----------------------------------------------------------------------
local function varsAPI(id)
	local instance = {}
	instance.deviceId = tonumber(id)
	function instance:delaySetVariable(lul_data)
		local v = deserializeJson(lul_data or "")
		local deviceId = v["deviceId"]
		local serviceId = v["serviceId"]
		local variable = v["variable"]
		local value = v["value"]
		debug("Setting delayed variable: " ..(v["serviceId"] or "nil") .. ", " ..(v["variable"] or "nil") .. " = " ..(v["value"] or "nil"))
		luup.variable_set(serviceId, variable, value, deviceId)
	end
	function instance:maybeSetVariableHtml(serviceId, varName, value, deviceId, style, margins)
		local s = style or {}
		local val = tostring(value)

		local ret
		local sStyle = css:transformFontStyle(s) .. css:transformMargins(margins or {})
		if(s.format ~= nil and string.len(s.format) > 0) then
			ret, val = pcall(function() return self:formatVariable(s.format, value) end)
			if(ret == false) then
				logger:debug("Error formatting variable: " .. serviceId .. "," .. varName .. "=" .. value)
				val = "Format Error!"
			end
		end
		local sFormatted = "<div style='display:inline-block;vertical-align:top;text-align:left;" .. sStyle .. "'><span style='white-space:pre;'>" .. val .. "</span></div>"
	  --debug("Setting Formatted Value:" .. serviceId .. "," .. varName .. "," .. val)
		self:maybeSetVariable(serviceId, varName, sFormatted, deviceId)
	end
	function instance:maybeSetVariable(serviceId, varName, value, deviceId)
		local v, ts = luup.variable_get(serviceId, varName, deviceId)
		if(type(value) == "boolean") then
			if(value) then value = 1 else value = 0 end
		end
		if(v ~= tostring(value)) then
			luup.variable_set(serviceId, varName, value, deviceId)
		end
	end
	function instance:formatVariable(sFormat, value)
	  -- Formats can be in the form
	  -- 1 Date - {0:Date,MM/dd/yyyy}
	  -- 2 Time - {0:Time,HH:mm} or {0:Time,hh:mmtt}
	  -- 3 DateTime - {0:DateTime,MM/dd/yyyy hh:mmtt}
	  -- 4 Number - {0:Number,0,000.0000} or {0:#,##0.00##} or {0:#,##0.####}
		local sFmt = string.match(sFormat, "{0.-}") or ""
		local sDataType = ""
		local sModifier = ""
		local sFormatted = ""
		if(string.match(sFmt, "{0:.-,") ~= nil) then
			sDataType = string.gsub(string.gsub(string.match(sFmt, ":.-,") or "", ",", "") or "", ":", "")
		end
		if(string.len(sDataType) > 0) then
			sModifier = string.gsub(string.gsub(string.gsub(sFmt, "{0:.-,", "") or "", sDataType, ""), "}", "")
		end
		if(value == nil or value == "") then
			return string.gsub(sFormat, string.gsub(sFmt, "%%", "%%%%"), "")
		end
		if(sDataType == "DateTime") then
			local s = os.date(sModifier, value)
			sFormatted = string.gsub(sFormat, string.gsub(sFmt, "%%", "%%%%"), s or "")
		elseif(sDataType == "Number") then
			local s = string.format(sModifier, value)
			sFormatted = string.gsub(sFormat, string.gsub(sFmt, "%%", "%%%%"), s or "")
		--debug("Formatting number using: [" .. sModifier .. "]" .. " [" .. sFormatted .. "] " .. "[" .. s .. "]")
		else
			sFormatted = string.gsub(sFormat, string.gsub(sFmt, "%%", "%%%%"), value or "")
		end
		return sFormatted
	end
	function instance:setChildVariable(serviceId, variable, value, altId, formatType)
		local deviceId, dev = pnl:findChildDevice(altId)
		if(deviceId ~= nil) then
			if(formatType ~= nil) then
				self:setPanelMeasurement(serviceId, variable, value, deviceId, formatType)
			else
				self:maybeSetVariable(serviceId, variable, value, deviceId)
			end
		else
			debug("Could not find child " .. altId .. " to set " .. serviceId .. "/" .. variable .. "[" .. value .. "]")
		end
	end
	function instance:getChildVariable(serviceId, variable, altId)
		local deviceId, dev = pnl.findChildDevice(altId)
		if(deviceId ~= nil) then
		--debug("getChildVariable(" .. serviceId .. ", " .. variable ..  ", " .. altId .. ")")
			return luup.variable_get(serviceId, variable, tonumber(deviceId))
		end
	end
	function instance:getVariable(serviceId, variable, deviceId, default)
		logger:debug("Getting Value from [" .. (deviceId or 0) .. "] " .. (serviceId or "null") .. "," .. variable)
		local val, ts = luup.variable_get(serviceId, variable, tonumber(deviceId))
		if(val == nil and default ~= nil) then
			logger:debug("Setting Default value for " .. serviceId .. "," .. variable .. "=" .. default)
			luup.variable_set(serviceId, variable, default, tonumber(deviceId))
			return luup.variable_get(serviceId, variable, tonumber(deviceId))
		end
		return val, ts
	end
	function instance:maybeSetEnumVariable(serviceId, variable, value, deviceId)
		-- Enum variables from the state are always in the form {val:0, name:"a name", desc:"Extended text"}
		local style = const.formatTypes[variable]
		if(style ~= nil) then 
			if(variable == "status") then
				if(value.name == "ready" or value.name == "ok") then style["color"] = "green"
				elseif(value.name == "loading") then style["color"] = "orange"
				else style["color"] = "red" end
				if(value.percent ~= nil and value.percent ~= 100) then
					self:maybeSetVariableHtml(serviceId, variable .. "_desc_Formatted", value.desc .. ": " .. string.format("%d %%", value.percent), deviceId, style)
				else
					self:maybeSetVariableHtml(serviceId, variable .. "_desc_Formatted", value.desc, deviceId, style)
				end
			elseif(variable == "mode") then
				if(value.name == "auto") then style["color"] = "green"
				else style["color"] = "red" end
				self:maybeSetVariableHtml(serviceId, variable .. "_desc_Formatted", value.desc, deviceId, style)
			end
			self:maybeSetVariable(serviceId, variable, value.name, deviceId)
			self:maybeSetVariable(serviceId, variable .. "_desc", value.desc, deviceId)
		end
	end
	function instance:maybeSetScaleVariable(serviceId, variable, value, deviceId, formatType)
		local style = const.formatTypes[formatType]
		if(style ~= nil) then
			if(formatType == "temperature") then
				local t = tonumber(value or 100)
				if(t >= 90) then style["color"] = "crimson"
				elseif(t >= 80) then style["color"] = "orangered"
				elseif(t >= 70) then style["color"] = "#FF8000"
				elseif(t >= 60) then style["color"] = "orange"
				elseif(t >= 50) then style["color"] = "#00BFFF"
				elseif(t >= 40) then style["color"] = "#0080FF"
				elseif(t >= 32) then style["color"] = "#013ADF"
				elseif(t >= 20) then style["color"] = "#0101DF"
				elseif(t >= 10) then style["color"] = "#3104B4"
				elseif(t >= 0) then	style["color"] = "#29088A"
				elseif(t >= -10) then style["color"] = "#5F04B4"
				else style["color"] = "#B40486"	end
				self:maybeSetVariable(serviceId, variable, value or "--", deviceId, style)
				self:maybeSetVariableHtml(serviceId, variable .. "_Formatted", value or "--", deviceId, style)
			elseif(formatType == "saturationIndex") then
				local si = tonumber(value)
				if(si >= 0.3) then style["color"] = "crimson"
				elseif(si >= 0.25) then style["color"] = "orange"
				elseif(si >= -0.25) then style["color"] = "green"
				elseif(si >= -0.29) then style["color"] = "orange"
				else style["color"] = "crimson"	end
				self:maybeSetVariable(serviceId, variable, si, deviceId, style)
				self:maybeSetVariableHtml(serviceId, variable .. "_Formatted", si, deviceId, style)
			elseif(formatType == "pHLevel") then
				local ph = tonumber(value)
				if(ph >= 7.8) then style["color"] = "crimson"
				elseif(ph >= 7.7) then style["color"] = "orange"
				elseif(ph >= 7.6) then style["color"] = "green"
				elseif(ph >= 7.1) then style["color"] = "orange"
				else style["color"] = "crimson"	end
				self:maybeSetVariable(serviceId, variable, ph, deviceId, style)
				self:maybeSetVariableHtml(serviceId, variable .. "_Formatted", ph, deviceId, style)
			elseif(formatType == "orpLevel") then
				local orp = tonumber(value)
				if(orp >= 755) then	style["color"] = "crimson"
				elseif(orp >= 750) then	style["color"] = "orange"
				elseif(orp >= 650) then	style["color"] = "green"
				elseif(orp >= 645) then	style["color"] = "orange"
				else style["color"] = "crimson"	end
				self:maybeSetVariable(serviceId, variable, orp, deviceId, style)
				self:maybeSetVariableHtml(serviceId, variable .. "_Formatted", orp, deviceId, style)
			elseif(formatType == "saltLevel") then
				local salt = tonumber(value)
				if(salt > 4700) then style["color"] = "crimson"
				elseif(salt > 4500) then style["color"] = "orange"
				elseif(salt > 3000) then style["color"] = "green"
				elseif(salt > 2800) then style["color"] = "orange"
				else style["color"] = "crimson"	end
				self:maybeSetVariable(serviceId, variable, salt, deviceId, style)
				self:maybeSetVariableHtml(serviceId, variable .. "_Formatted", salt, deviceId, style)
		    
			else
				self:maybeSetVariable(serviceId, variable, value, deviceId, style)
				self:maybeSetVariableHtml(serviceId, variable .. "_Formatted", value, deviceId, style)
			end
		else
			self:maybeSetVariable(serviceId, variable, value, deviceId, style)
		end
	end
	return instance
end
----------------------------------------------------------------------
-- CSS Stylesheet Management Functions
----------------------------------------------------------------------
local function cssAPI(deviceId)
	local instance = {}
	instance.deviceId = tonumber(deviceId)
	function instance:transformMargins(style)
		local sStyle = ""
		for i, s in pairs(style or {}) do
			if(i == "top" and tonumber(s) ~= 0) then
				sStyle = sStyle .. "margin-top:" .. s .. "px;"
			elseif(i == "left" and tonumber(s) ~= 0) then
				sStyle = sStyle .. "margin-left:" .. s .. "px;"
			elseif(i == "right" and tonumber(s) ~= 0) then
				sStyle = sStyle .. "margin-right:" .. s .. "px;"
			elseif(i == "bottom" and tonumber(s) ~= 0) then
				sStyle = sStyle .. "margin-bottom:" .. s .. "px;"
			end
		end
		return sStyle
	end
	function instance:transformFontStyle(style)
		local sStyle = ""
		for i, s in pairs(style or {}) do
			if(i == "fontFamily" and s ~= nil and string.len(s) > 0) then
				sStyle = sStyle .. "font-family:" .. s .. ";"
			elseif(i == "italic" and s ~= nil) then
				if(s) then
					sStyle = sStyle .. "font-style:italic;"
				end
			elseif(i == "bold" and s ~= nil) then
				if(s) then
					sStyle = sStyle .. "font-weight:bold;"
				end
			elseif(i == "underline" and s ~= nil) then
				if(s) then
					sStyle = sStyle .. "text-decoration:underline;"
				end
			elseif(i == "width" and s ~= nil and s ~= "") then
				if(tonumber(0) ~= nil and tonumber(0) > 0) then
					sStyle = sStyle .. "width:" .. s .. "px;"
				else
					sStyle = sStyle .. "width:" .. s;
				end
			elseif((i == "fontSize" or i == "font-size") and string.len(s) > 0) then
				sStyle = sStyle .. "font-size:" .. s .. ";"
			elseif(i == "color" and s ~= nil and string.len(s) > 0) then
				sStyle = sStyle .. "color:" .. s .. ";"
			elseif((i == "textAlign" or i == "text-align") and s ~= nil and string.len(s) > 0) then
				sStyle = sStyle .. "text-align:" .. s .. ";"
			elseif(i ~= nil and s ~= nil) then
				sStyle = sStyle .. i .. ":" .. s .. ";"
			end
		end
		return sStyle
	end
	return instance
end
----------------------------------------------------------------------
-- JSON Functions
----------------------------------------------------------------------
local function jsonAPI(id)
	local instance = {}
	instance.dkjson = require("dkjson")
	instance.deviceId = tonumber(id)
	function instance:encode(obj)
		if(obj == nil or type(obj) == "string") then 
			logger:verbose("Encode json incorrect type: " .. type(obj))
			return nil 
		end
		local data = self.dkjson.encode(obj)
		logger:verbose("Encoding json data:" .. (type(obj) or "null") .. data)
		return data
	end
	function instance:decode(data)
		if(type(data) == "string") then
			if(data == nil) then return nil end
			logger:verbose('Decoding json data:' ..(data or ""))
			return self.dkjson.decode(data)
		end
		logger:verbose("Decode json incorrect data type: " .. (type(data) or "null"))
		return data
	end
	return instance
end
----------------------------------------------------------------------
-- Pool Controller Functions
----------------------------------------------------------------------
local function poolControllerAPI(deviceId)
	local instance = {}
	instance.deviceId = tonumber(deviceId)
	instance.serviceId = const.serviceIds.panel
	instance.uiVersion = luup.version_major .. "." .. luup.version_minor .. " " ..(luup.version_branch or 0)
	instance.pluginId = luup.attr_get("plugin", instance.deviceId) or -1
	instance.state = {}
	instance.children = {}
	function instance:setPanelMessage(text)
		vars.maybeSetVariableHtml(pnl.serviceId, "PanelMessage", text, pnl.deviceId, const.formatTypes["PanelMessage"])
	end
	function instance:setControllerStatus(stat, desc)
		local data = {["mode"] = {["val"] = -1, ["name"] = "unknown", ["desc"] = "----"},
				["status"] = {["val"] = -1, ["name"] = stat, ["desc"] = desc}}
		self:setControllerState(data)
	end
	function instance:checkVersion()
		local oldPluginVer = luup.variable_get(self.serviceId, "Version", self.deviceId)
		local oldVer = tonumber(luup.variable_get(self.serviceId, "UIVersion", self.deviceId) or 0) or 0
		local sJson = string.lower(luup.attr_get("device_json", self.deviceId))
		if(oldPluginVer ~= const.pluginVersion) then
			logger:info("New Plugin Version Installed: " ..(const.pluginVersion or "null") .. " from " ..(oldPluginVer or "New Install")) 
		end
		vars:maybeSetVariable(self.serviceId, "Version", const.pluginVersion, self.deviceId)
		vars:maybeSetVariableHtml(self.serviceId, "Version_Formatted", const.pluginVersion, self.deviceId, {["color"] = "green",["fontSize"] = ".7em"})
		vars:maybeSetVariable(self.serviceId, "UIVersion", luup.version_major, self.deviceId)
		if(luup.version_major ~= oldVer) then
			logger:info("New UI Version Installed: UI" .. luup.version_major .. " from UI" .. oldVer)
		end
	end
	function instance:loadPoolState()
	    -- Call the http webservice to get the data from the pool controller.
		local statusCode, obj, httpCode = comms:getJson("/state/all")
		return statusCode, obj, httpCode
	end
	function instance:persistChildDevices(data) 
		-- Get the heat modes from each of the bodies.
		local bodyCircuits = {}
		-- Normalize our data.  Lua is stupid with all its enumeration exceptions related to nil
		if(data.temps == nil) then data.temps = {} end
		if(data.temps.bodies == nil) then data.temps.bodies = {} end
		if(data.circuits == nil) then data.circuits = {} end
		if(data.features == nil) then data.features = {} end
		if(data.circuitGroups == nil) then data.circuitGroups = {} end
		if(data.lightGroups == nil) then data.lightGroups = {} end
		if(data.pumps == nil) then data.pumps = {} end
		if(data.chlorinators == nil) then data.chlorinators = {} end

		for k, body in pairs(data.temps.bodies) do
			bodyCircuits["pcpCircuit-" .. (body.circuit or 0)] = true
			local statusCode, obj, httpCode = comms:getJson("/config/body/" .. body.id .. "/heatModes")
			if(statusCode == 0 and httpCode == 200) then
				body.heatSources = obj
				-- Figure out which device file we want for each body
				body.hasHeater = false
				body.hasSolar = false
				body.hasHPump = false
				for _, heater in ipairs(body.heatSources) do
					if(heater.name == "solar") then body.hasSolar = true end
					if(heater.name == "heater") then body.hasHeater = true end
					if(heater.name == "heatPump") then body.hasHPump = true end
				end
				if(not body.hasHeater and not body.hasSolar and not body.hasHPump) then body.deviceFile = "D_PoolBody.xml"
				elseif(body.hasHeater and body.hasSolar) then body.deviceFile = "D_PoolBodyHeaterSolar.xml"
				elseif(body.hasHeater and body.hasHPump) then body.deviceFile = "D_PoolBodyHeaterHPump.xml"
				elseif(body.hasSolar) then body.deviceFile = "D_PoolBodySolar.xml"
				else body.deviceFile = "D_PoolBodyHeater.xml" end
			end
		end
		local childDevices = luup.chdev.start(self.deviceId)
		-- Add in the bodies
		for k, body in pairs(data.temps.bodies) do
			local deviceFile = body.deviceFile
			local altId = "pcpBody-" .. body.id
			local name = body.name or ("Body-" .. body.id)
			if(body.hasHeater or body.hasHPump or body.hasSolar) then name = name .. " Heat"
			else name = name .. " Body" end
			local variables = self.serviceId .. ",equipmentType=body\n" .. self.serviceId .. ",equipmentId=" .. body.id
			logger:verbose("Setting [" .. self.deviceId .. "]Pool Controller Body [" .. name .. "][" .. altId .. "] with device file " .. deviceFile)
			luup.chdev.append(self.deviceId, childDevices, altId, name, "", deviceFile,
			"I_PoolController.xml", variables, false)
		end
		for k, circuit in pairs(data.circuits) do
			local deviceFile = "D_BinaryLight1.xml"
			local altId = "pcpCircuit-" .. circuit.id
			if(circuit.type.name == "dimmer") then deviceFile = "D_DimmableLight1.xml" end
			if(circuit.showInFeatures or circuit.type.isLight or bodyCircuits[altId] == true) then
				local name = circuit.name or ("Circuit-" .. circuit.id)
				local variables = self.serviceId .. ",equipmentType=circuit\n" .. self.serviceId .. ",equipmentId=" .. circuit.id 
				logger:verbose("Setting [" .. self.deviceId .. "]Pool Controller child circuit [" .. name .. "][" .. altId .. "][" .. circuit.type.name .. "] with device file " .. deviceFile)
				luup.chdev.append(self.deviceId, childDevices, altId, name, "", deviceFile,
				"I_PoolController.xml", variables, false)
			end
		end
		for k, feature in pairs(data.features) do
			local deviceFile = "D_BinaryLight1.xml"
			local variables = self.serviceId .. ",equipmentType=feature\n" .. self.serviceId .. ",equipmentId=" .. feature.id 
			if(feature.showInFeatures) then
				local altId = "pcpFeature-" .. feature.id
				local name = feature.name or ("Feature-" .. feature.id)
				logger:verbose("Setting [" .. self.deviceId .. "]Pool Controller child feature [" .. name .. "][" .. altId .. "][" .. feature.type.name .. "] with device file " .. deviceFile)
				luup.chdev.append(self.deviceId, childDevices, altId, name, "", deviceFile,
				"I_PoolController.xml", variables, false)
			end
		end
		for k, cgroup in pairs(data.circuitGroups) do
			local deviceFile = "D_BinaryLight1.xml"
			local variables = self.serviceId .. ",equipmentType=circuitGroup\n" .. self.serviceId .. ",equipmentId=" .. cgroup.id
			local altId = "pcpCGroup-" .. cgroup.id
			local name = cgroup.name or ("Group-" .. cgroup.id)
			logger:verbose("Setting [" .. self.deviceId .. "]Pool Controller child circuit group [" .. name .. "][" .. altId .. "][" .. cgroup.type.name .. "] with device file " .. deviceFile)
			luup.chdev.append(self.deviceId, childDevices, altId, name, "", deviceFile,
			"I_PoolController.xml", variables, false)
		end
		for k, lgroup in pairs(data.lightGroups) do
			local deviceFile = "D_BinaryLight1.xml"
			local altId = "pcpLGroup-" .. lgroup.id
			local name = lgroup.name or ("Lights-" .. lgroup.id)
			local variables = self.serviceId .. ",equipmentType=lightGroup\n" .. self.serviceId .. ",equipmentId=" .. lgroup.id
			logger:verbose("Setting [" .. self.deviceId .. "]Pool Controller child light group [" .. name .. "][" .. altId .. "][" .. lgroup.type.name .. "] with device file " .. deviceFile)
			luup.chdev.append(self.deviceId, childDevices, altId, name, "", deviceFile,
			"I_PoolController.xml", variables, false)
		end
		-- Add in all the pumps
		for k, pump in pairs(data.pumps) do
			local type = pump.type.name or ""
			if(type == "vs+svrs") then type = "vs" 
			elseif(type == "ds") then type = "ss"
			end
			-- Only create the pump types we know about
			if(type == "vs" or type == "ss" or type == "vsf" or type == "vf") then
				local deviceFile = "D_Pool" .. string.upper(pump.type.name) .. "Pump.xml"
				local altId = "pcpPump-" .. pump.id
				local name = pump.name or ("Pump-" .. pump.id)
				logger:verbose("Setting [" .. self.deviceId .. "]Pool Controller Pump [" .. name .. "][" .. altId .. "][" .. type .. "] with device file " .. deviceFile)
				local variables = self.serviceId .. ",equipmentType=pump\n" .. self.serviceId .. ",equipmentId=" .. pump.id .. "\n" .. self.serviceId .. ",pumpType=" .. type
				luup.chdev.append(self.deviceId, childDevices, altId, name, "", deviceFile,
				"I_PoolController.xml", variables, false)
			end
		end
		-- Add in all the chlorinators
		for k, chlor in pairs(data.chlorinators) do
			local deviceFile = "D_PoolChlorinator.xml"
			local altId = "pcpChlorinator-" .. chlor.id
			local name = chlor.name or ("Chlorinator-" .. chlor.id)
			local type = chlor.type.name or "unknown"
			logger:verbose("Setting [" .. self.deviceId .. "]Pool Controller Chlorinator [" .. name .. "][" .. altId .. "] with device file " .. deviceFile)
			local variables = self.serviceId .. ",equipmentType=chlorinator\n" .. self.serviceId .. ",equipmentId=" .. chlor.id .. "\n" .. self.serviceId .. ",chlorinatorType=" .. type
			luup.chdev.append(self.deviceId, childDevices, altId, name, "", deviceFile,
			"I_PoolController.xml", variables, false)
		end

		luup.chdev.sync(self.deviceId, childDevices)
		self.children = {}
		for k, v in pairs(luup.devices) do
		  if (v.device_num_parent == luup.device) then
			self.children[v.id] = k
		  end
		end
		local sameRoom, ts = vars:getVariable(const.serviceIds.haDevice, "ChildrenSameRoom", self.deviceId, "1")
		if(util:makeBool(sameRoom)) then
			self:setChildrenToParentRoom()
		else
			logger:verbose("Skipping room assignments " .. sameRoom)
		end
		self:setChildStates(data)
		return true
		-- Load up our list of child devices.
	end
	function instance:findChildDevice(altId)
	  if(self.children[altId] == nil) then
		for k, v in pairs(luup.devices) do
		  if (v.device_num_parent == luup.device and v.id == altId) then
			self.children[altId] = k
			return k, v
		  end
		end
	  else
		local deviceId = self.children[altId];
		return deviceId, luup.devices[deviceId]
	  end
	end
	function instance:setControllerState(data)
		local mode = nil
		local status = nil
		if(data ~= nil) then
			mode = data.mode
			status = data.status
		else
			mode = {["val"] = -1, ["name"] = "unknown", ["desc"] = "----"}
			status = {["val"] = -1, ["name"] = "unknown", ["desc"] = "Unkown"}
		end
		if(status ~= nil) then 
			vars:maybeSetEnumVariable(self.serviceId, "status", status, self.deviceId) 
		end
		if(data.mode ~= nil) then vars:maybeSetEnumVariable(self.serviceId, "mode", mode, self.deviceId) end
	end
	function instance:setTempState(temps)
		for k, body in ipairs(temps.bodies) do
			local bodyId, b = self:findChildDevice("pcpBody-".. body.id)
			if(b ~= nil) then
				const.formatTypes.temperature.format = "{0}&deg;" .. (temps.units.name or "F")
				vars:maybeSetScaleVariable(self.serviceId, "airTemp", temps.air, bodyId, "temperature")
				vars:maybeSetScaleVariable(self.serviceId, "solarTemp", temps.solar, bodyId, "temperature")
				self:setBodyState(body)
			end
		end
	end
	function instance:setBodyState(body)
		local bodyId, b = self:findChildDevice("pcpBody-".. body.id)
		vars:maybeSetScaleVariable(self.serviceId, "waterTemp", body.temp, bodyId, "temperature")
		vars:maybeSetVariable(self.serviceId, "heatMode", body.heatMode.name, bodyId)
		vars:maybeSetVariable(self.serviceId, "heatStatus", body.heatStatus.name, bodyId)
		vars:maybeSetVariable("urn:upnp-org:serviceId:TemperatureSetpoint1_Heat", "CurrentSetpoint", body.setPoint, bodyId)
		vars:maybeSetVariable("urn:upnp-org:serviceId:HVAC_UserOperatingMode1", "ModeStatus", body.heatMode.name, bodyId)
		vars:maybeSetVariable("urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", body.temp, bodyId)
	end
	function instance:setCircuitState(circuit)
		local circuitId, c = self:findChildDevice("pcpCircuit-" .. circuit.id)
		if(circuitId ~= nil) then
			local val = 0
			local level = circuit.level or 0
			if(circuit.isOn) then val = 1
			else level = 0
			end
			if(circuit.type.name == "dimmer") then
				vars:maybeSetVariable(const.serviceIds.dimmer, "LoadLevelTarget", level or 0, circuitId)
				vars:maybeSetVariable(const.serviceIds.dimmer, "LoadLevelStatus", level or 0, circuitId)
				vars:maybeSetVariable(self.serviceId, "dimmerLevel", level or 0, cicuitId)
			end
			vars:maybeSetVariable(self.serviceId, "function", circuit.type.name, circuitId)
			vars:maybeSetVariable(const.serviceIds.binary, "Status", val, circuitId)
			vars:maybeSetVariable(const.serviceIds.binary, "Target", val, circuitId)
		end
	end
	function instance:setChlorinatorState(chlor)
		local chlorId, p = self:findChildDevice("pcpChlorinator-" .. chlor.id)
		if(chlorId ~= nil) then
			local isOn = 0
			if(util:makeBool(chlor.isOn) or chlor.currentOutput > 0) then isOn = 1 end
			vars:maybeSetVariable(const.serviceIds.binary, "Status", isOn, chlorId)
			vars:maybeSetVariable(const.serviceIds.binary, "Target", isOn, chlorId)
			vars:maybeSetScaleVariable(const.serviceIds.chlorinator, "saltLevel", chlor.saltLevel, chlorId, "saltLevel")
			vars:maybeSetVariable(const.serviceIds.chlorinator, "poolSetpoint", chlor.poolSetpoint or 0, chlorId)
			vars:maybeSetVariable(const.serviceIds.chlorinator, "spaSetpoint", chlor.spaSetpoint or 0, chlorId)
			vars:maybeSetVariable(const.serviceIds.chlorinator, "superChlorHours", chlor.superChlorHours or 0, chlorId)
			vars:maybeSetVariable(const.serviceIds.chlorinator, "saltRequired", chlor.saltRequired or 0, chlorId)
			vars:maybeSetVariable(const.serviceIds.chlorinator, "currentOutput", chlor.currentOutput or 0, chlorId)
			local status = "Cell Off"
			local fmt = {["color"] = "gray",["fontSize"] = ".7em", ["bold"] = true}
			if(util:makeBool(chlor.superChlor)) then
				local totalMins = math.floor(chlor.superChlorRemaining / 60)
				local hours = math.floor(totalMins/60)
				local mins = totalMins - (hours * 60)
				status = "Shock: " .. hours .. "hrs  " .. mins .. "mins left"
				fmt["color"] = "orange"
			elseif(isOn > 0) then
				status = "Chlorinating..." .. chlor.currentOutput .. "%"
				fmt["bold"] = true
				fmt["color"] = "green"
			end
			vars:maybeSetVariable(const.serviceIds.chlorinator, "superChlor", chlor.superChlor, chlorId)
			vars:maybeSetVariable(const.serviceIds.chlorinator, "chlorStatus", status, chlorId)
			vars:maybeSetVariableHtml(const.serviceIds.chlorinator, "chlorStatus_Formatted", status, chlorId, fmt)
			-- Deal with the cell status
			fmt = {["color"] = "green",["fontSize"] = ".7em", ["bold"] = true}
			if(chlor.status.val > 0 and chlor.status.val < 2) then fmt["color"] = "orange"
			elseif(chlor.status.val == 3 or chlor.status.val == 7) then fmt["color"] = "orangered"
			elseif(chlor.status.val > 3 and chlor.status.val < 7) then fmt["color"] = "crimson"
			end
			vars:maybeSetVariable(const.serviceIds.chlorinator, "cellStatus", chlor.status.desc, chlorId)
			vars:maybeSetVariableHtml(const.serviceIds.chlorinator, "cellStatus_Formatted", chlor.status.desc, chlorId, fmt)

		end
	end

	function instance:setPumpState(pump)
		local pumpId, p = self:findChildDevice("pcpPump-" .. pump.id)
		if(pumpId ~= nil) then
			vars:maybeSetVariable(const.serviceIds.energyMetering, "Watts", util:nilIf(pump.watts, 0) or "", pumpId)
			vars:maybeSetVariable(self.serviceId, "pumpStatus", pump.status.name, pumpId)
			vars:maybeSetVariable(self.serviceId, "ppc", pump.ppc, pumpId)
			vars:maybeSetVariable(self.serviceId, "mode", pump.mode, pumpId)
			vars:maybeSetVariable(self.serviceId, "runTime", pump.time, pumpId)
			vars:maybeSetVariable(self.serviceId, "command", pump.command, pumpId)
			vars:maybeSetVariable(self.serviceId, "driveState", pump.driveState, pumpId)
			local isOn = 0
			if(util:makeBool(pump.isOn) or (pump.command == 10) or util:isNil(pump.watts, 0) > 0) then isOn = 1 end
			vars:maybeSetVariable(const.serviceIds.binary, "Status", isOn, pumpId)
			vars:maybeSetVariable(const.serviceIds.binary, "Target", isOn, pumpId)
			vars:maybeSetScaleVariable(self.serviceId, "pumpSpeed", pump.rpm, pumpId, "pumpSpeed")
			vars:maybeSetScaleVariable(self.serviceId, "pumpFlow", pump.flow, pumpId, "pumpFlow")
			vars:maybeSetScaleVariable(self.serviceId, "pumpWatts", pump.watts, pumpId, "energyUse")
		end
	end
	function instance:setFeatureState(feature)
		local featureId, c = self:findChildDevice("pcpFeature-" .. feature.id)
		if(featureId ~= nil) then
			local val = 0
			if(feature.isOn) then val = 1 end
			vars:maybeSetVariable(const.serviceIds.binary, "Status", val, featureId)
			vars:maybeSetVariable(const.serviceIds.binary, "Target", val, featureId)
			vars:maybeSetVariable(self.deviceId, "function", feature.type.name, featureId)
		end
	end
	function instance:setCircuitGroupState(group)
		local groupId, c = self:findChildDevice("pcpCGroup-" .. group.id)
		if(groupId ~= nil) then
			local val = 0
			if(group.isOn) then val = 1 end
			vars:maybeSetVariable(const.serviceIds.binary, "Status", val, groupId)
			vars:maybeSetVariable(const.serviceIds.binary, "Target", val, groupId)
			vars:maybeSetVariable(self.deviceId, "function", group.type.name, groupId)
		end
	end
	function instance:setLightGroupState(group)
		local groupId, c = self:findChildDevice("pcpLGroup-" .. group.id)
		if(groupId ~= nil) then
			local val = 0
			if(group.isOn) then val = 1 end
			vars:maybeSetVariable(const.serviceIds.binary, "Status", val, groupId)
			vars:maybeSetVariable(const.serviceIds.binary, "Target", val, groupId)
			vars:maybeSetVariable(self.deviceId, "function", group.type.name, groupId)
		end
	end
	function instance:setChildStates(obj)
		-- Set the controller state
		self:setControllerState({["mode"] = obj.mode, ["status"] = obj.status})
		-- Start the Temps
		self:setTempState(obj.temps)
		-- Set all the circuits
		if(obj.circuits ~= nil) then
			for k, circuit in ipairs(obj.circuits) do
				self:setCircuitState(circuit)
			end
		end
		-- Set all the features
		if(obj.features ~= nil) then
			for k, feature in ipairs(obj.features) do
				self:setFeatureState(feature)
			end
		end
		-- Set all the Circuit Groups
		if(obj.circuitGroups ~= nil) then
			for k, group in ipairs(obj.circuitGroups) do
				self:setCircuitGroupState(group)
			end
		end
		-- Set all the Light Groups
		if(obj.lightGroups ~= nil) then
			for k, group in ipairs(obj.lightGroups) do
				self:setLightGroupState(group)
			end
		end
		if(obj.pumps ~= nil) then
			for k, pump in ipairs(obj.pumps) do
				self:setPumpState(pump)
			end
		end
		if(obj.chlorinators ~= nil) then
			for k, chlor in ipairs(obj.chlorinators) do
				self:setChlorinatorState(chlor)
			end
		end
	end
	function instance:init()
		self:checkVersion()
		luup.attr_set("category_num", 1, self.deviceId)
		luup.attr_set("subcategory_num", 2, self.deviceId)
		self:setControllerStatus("init", "Initializing Plugin...")
		vars:getVariable(self.serviceId, "userName", self.deviceId, "")
		vars:getVariable(self.serviceId, "password", self.deviceId, "")
		vars:getVariable(self.serviceId, "logLevel", self.deviceId, 0)
		--self.clearCommFailures();
		-- Load up the current state configuration from nodejs-poolController
		local statusCode, obj, httpCode = self:loadPoolState();
		if(statusCode == 0 and httpCode == 200) then
			self.state = obj
		    -- Set the version to nodejs-poolController version and the firmware for the OCP to the panel.
			vars:maybeSetVariable(self.serviceId, "OCPModel", obj.equipment.model, self.deviceId)
			vars:maybeSetVariable(self.serviceId, "maxBodies", obj.equipment.maxBodies, self.deviceId)
			vars:maybeSetVariable(self.serviceId, "maxValves", obj.equipment.maxValves, self.deviceId)
			vars:maybeSetVariable(self.serviceId, "OCPType", obj.equipment.controllerType, self.deviceId)
			vars:maybeSetVariable(self.serviceId, "NodeVersion", obj.appVersion, self.deviceId)
			vars:maybeSetVariableHtml(self.serviceId, "NodeVersion_Formatted", obj.appVersion, self.deviceId, {["color"] = "green",["fontSize"] = ".7em"})
			vars:maybeSetVariable(self.serviceId, "firmwareVersion", obj.equipment.softwareVersion, self.deviceId)
			vars:maybeSetVariableHtml(self.serviceId, "firmwareVersion", obj.equipment.softwareVersion, self.deviceId, {["color"] = "green",["fontSize"] = ".7em"})
			self:persistChildDevices(obj)
		else
			self:setControllerStatus("error", "Error Getting State " .. httpCode)
		end
		luup.register_handler("pcpCallbackHandler", "pcpGetConfiguration")
		luup.register_handler("pcpCallbackHandler", "pcpSetConfiguration")
	end
	function instance:setChildrenToParentRoom()
		logger:verbose("poolController: Setting Children to same room")
		local roomId = tonumber(luup.attr_get("room", self.deviceId) or 0) or 0
		for k, v in pairs(luup.devices) do
			if (v.device_num_parent == self.deviceId) then
				if(roomId ~= tonumber(luup.attr_get("room", k))) then
					logger:verbose("poolController: Assigning " .. (v.description or "") .. " to Room " .. roomId)
				end
				luup.attr_set("room", roomId, k)
			end
		end
	end
	function instance:getConfiguration()
		logLevel, logLevelName = logger:getLogLevel()
		return {["ipAddress"] = luup.devices[instance.deviceId].ip, ["userName"] = vars:getVariable(self.serviceId, "userName", self.deviceId), ["logLevelName"] = logLevelName, ["logLevel"] = logLevel};
	end
	function instance:setConfiguration(data)
	    local changed = false
		if(data.ipAddress ~= nil) then 
			if(luup.devices[self.deviceId].ip ~= data.ipAddress) then changed = true end
			logger:info("poolController: Setting ip to " .. data.ipAddress)
			-- luup.ip_set(data.ipAddress, self.deviceId)
			luup.attr_set("ip", data.ipAddress, self.deviceId)
			comms.ipAddress = data.ipAddress
		end
		if(data.userName ~= nil) then 
			if(data.userName ~= comms.userName) then changed = true end
			vars:maybeSetVariable(self.serviceId, "userName", data.userName, self.deviceId) 
			comms.userName = data.userName
		end
		if(data.password ~= nil) then 
			if(data.password ~= comms.password) then changed = true end
			vars:maybeSetVariable(self.serviceId, "password", data.password, self.deviceId) 
			comms.password = data.password
		end
		if(data.childrenSameRoom ~= nil) then
			local v ts = luup.variable_get(const.serviceIds.haDevice, "ChildrenSameRoom", self.deviceId)
			if(util:makeBool(v) ~= data.childrenSameRoom and data.childrenSameRoom and not changed) then
				self:setChildrenToParentRoom()
			end
			if(data.childrenSameRoom) then 
				vars:maybeSetVariable(const.serviceIds.haDevice, "ChildrenSameRoom", 1, self.deviceId)
			else
				vars:maybeSetVariable(const.serviceIds.haDevice, "ChildrenSameRoom", 0, self.deviceId)
			end
		end
		if(data.logLevel ~= nil) then logger:setLogLevel(data.logLevel) end
		if(changed) then util:reloadLuup() end
		return self:getConfiguration()
	end
	
	return instance
end
----------------------------------------------------------------------
-- Initialization Functions
----------------------------------------------------------------------
function pcpInitialize(deviceId)
	const = constAPI()
	css = cssAPI(deviceId)
	json = jsonAPI(deviceId)
	logger = loggerAPI(deviceId)
	vars = varsAPI(deviceId)
	util = utilAPI(deviceId)
	comms = commsAPI(deviceId)
	pnl = poolControllerAPI(deviceId)
	pnl:init()
	return true
end
----------------------------------------------------------------------
-- Callback Handler
----------------------------------------------------------------------
function pcpCallbackHandler(lul_request, lul_parameters, lul_outputformat)
	-- Handles the callbacks when the xml data is returned.
	logger:verbose("Called pcpCallbackHandler with request " .. (lul_request or "nil") .. " " .. json:encode(lul_parameters or {}))
	-- Forwarder makes output format empty.
	if (lul_outputformat ~= "xml") then
		if(lul_request == "pcpGetConfiguration") then return json:encode(pnl:getConfiguration())
		elseif(lul_request == "pcpSetConfiguration") then return json:encode(pnl:setConfiguration(json:decode(lul_parameters.data))) end
	end
end
----------------------------------------------------------------------
-- UPnP Job Functions
----------------------------------------------------------------------
function jobSetData(lul_device, lul_settings, lul_job)
	-- The information should always be sent to the main panel for this.  We will be dispatching
	-- based upon the action in the settings.
	-- The data is a bit odd coming from the interface file.  This is because vera stuffs the body
	-- of the request into the table structure where the body is the key on the table.
	local data = nil
	local pat = "{"
	for x, v in pairs(lul_settings) do
		-- Look for json in the key.  This will be the json data that is being sent
		if(x:sub(1, #pat) == pat) then
			data = json:decode(x)
		end
	end
	if(data ~= nil) then
		-- Process the incoming data
		if(lul_settings.targetData == "controller") then
			pnl:setControllerState(data)
		elseif(lul_settings.targetData == "circuit") then
			pnl:setCircuitState(data)
		elseif(lul_settings.targetData == "feature") then
			pnl:setFeatureState(data)
		elseif(lul_settings.targetData == "circuitGroup") then
			pnl:setCircuitGroupState(data)
		elseif(lul_settings.targetData == "lightGroup") then
			pnl:setLightGroupState(data)
		elseif(lul_settings.targetData == "temps") then
			pnl:setTempState(data)
		elseif(lul_settings.targetData == "body") then
			pnl:setBodyState(data)
		elseif(lul_settings.targetData == "pump") then
			pnl:setPumpState(data)
		elseif(lul_settings.targetData == "chlorinator") then
			pnl:setChlorinatorState(data)
		else
			logger:verbose("Unrecognized event" .. (data or "null"))
		end
	else
		logger:verbose("Unable to parse payload" .. (data or "null"))
	end
	return true
end
function jobSetBinaryTarget(lul_device, lul_settings, lul_job)
	local equipmentType = vars:getVariable(pnl.serviceId, "equipmentType", lul_device, "unknown")
	local equipmentId = vars:getVariable(pnl.serviceId, "equipmentId", lul_device, -1)
	logger:verbose("poolController: Setting [" .. lul_device .. "] state to " .. lul_settings.newTargetValue)
	if(equipmentType == "circuit" or equipmentType == "feature" or equipmentType == "circuitGroup" or equipmentType == "lightGroup") then
		comms:putJson("/state/" .. equipmentType .. "/setState", {["id"] = tonumber(equipmentId), ["state"] = util:makeBool(lul_settings.newTargetValue)})
	end
	return true
end
function jobSetDimmingTarget(lul_device, lul_settings, lul_job)
	local equipmentType = vars:getVariable(pnl.serviceId, "equipmentType", lul_device, "unknown")
	local equipmentId = vars:getVariable(pnl.serviceId, "equipmentId", lul_device, -1)
	logger:verbose("poolController: Setting [" .. lul_device .. "] dimmerLevel to " .. lul_settings.newLoadlevelTarget)
	if(equipmentType == "circuit") then
		comms:putJson("/state/" .. equipmentType .. "/setDimmerLevel", {["id"] = tonumber(equipmentId), ["level"] = lul_settings.newLoadlevelTarget})
	end
	return true
end
function jobSetBodyHeatModeTarget(lul_device, lul_settings, lul_job)
	local equipmentType = vars:getVariable(pnl.serviceId, "equipmentType", lul_device, "unknown")
	local equipmentId = vars:getVariable(pnl.serviceId, "equipmentId", lul_device, -1)
	logger:verbose("poolController: Setting [" .. lul_device .. "] heatMode to " .. lul_settings.NewModeTarget)
	if(equipmentType == "body") then
		comms:putJson("/state/" .. equipmentType .. "/heatMode", {["id"] = tonumber(equipmentId), ["mode"] = lul_settings.NewModeTarget})
	end
	return true
end
function jobSetBodySetpointTarget(lul_device, lul_settings, lul_job)
	local equipmentType = vars:getVariable(pnl.serviceId, "equipmentType", lul_device, "unknown")
	local equipmentId = vars:getVariable(pnl.serviceId, "equipmentId", lul_device, -1)
	logger:verbose("poolController: Changing [" .. lul_device .. "] body setPoint to " .. lul_settings.NewCurrentSetpoint)
	if(equipmentType == "body") then
		comms:putJson("/state/" .. equipmentType .. "/setPoint", {["id"] = tonumber(equipmentId), ["setPoint"] = lul_settings.NewCurrentSetpoint})
	end
	return true
end
function jobSetChlorSetpointTarget(lul_device, lul_settings, lul_job)
	local equipmentType = vars:getVariable(pnl.serviceId, "equipmentType", lul_device, "unknown")
	local equipmentId = vars:getVariable(pnl.serviceId, "equipmentId", lul_device, -1)
	local target = "pool"
	local setpoint = lul_settings.newPoolSetpointTarget
	if(lul_settings.newSpaSetpointTarget ~= nil) then 
		target = "spa" 
		setpoint = newSpaSetpointTarget
	end
	logger:verbose("poolController: Changing [" .. lul_device .. "] Chlorinator " .. target .. " setPoint to " .. setpoint)
	if(equipmentType == "chlorinator") then
		comms:putJson("/state/" .. equipmentType .. "/" .. target .. "SetPoint", {["id"] = tonumber(equipmentId), ["setPoint"] = setpoint})
	end
	return true
end
function jobSuperChlorinate(lul_device, lul_settings, lul_job)
	local equipmentType = vars:getVariable(pnl.serviceId, "equipmentType", lul_device, "unknown")
	local equipmentId = vars:getVariable(pnl.serviceId, "equipmentId", lul_device, -1)
	local super = util:makeBool(lul_settings.newTargetValue)
	if(super) then logger:verbose("poolController: SuperChlorinate [" .. lul_device .. "]")
	else logger:verbose("poolController: Cancel SuperChlorinate [" .. lul_device .. "]")
	end
	if(equipmentType == "chlorinator") then
		comms:putJson("/state/" .. equipmentType .. "/superChlorinate", {["id"] = tonumber(equipmentId), ["superChlorinate"] = super})
	end
	return true
end