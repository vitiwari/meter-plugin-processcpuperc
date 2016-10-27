-- Copyright 2015 Boundary, Inc.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- Add require statements for built-in libaries we wish to use
local math = require('math')
local os = require('os')
local string = require('string')
local timer = require('timer')
local io = require('io')
local fs = require('fs')
local net = require('net')
local json = require('json')
local table = require('table')


local  params = json.parse(fs.readFileSync('param.json')) or {}
local options  = params.items or {}


--[[
  @Vitiwari
  This function creates the JSON RPC command to meter according to the params
]]--
function getProcessData(opt)
   local parameter = {}
   parameter.process = opt.processName or ''
   parameter.path_expr = opt.processPath or ''
   parameter.cwd_expr = opt.processCwd or ''
   parameter.args_expr = opt.processArgs or ''
   parameter.reconcile = opt.reconcile or ''
   local prm = parameter or { match = ''}
   return '{"jsonrpc":"2.0","method":"get_process_info","id":1,"params":' .. json.stringify(prm) .. '}\n'
end

--Utility functions 
function parseJson(body)
  return pcall(json.parse, body)
end

function trim(val)
  return string.match(val, '^%s*(.-)%s*$')
end
function isEmpty(str)
  return (str == nil or trim(str) == '')
end
function notEmpty(str, default)
  return not isEmpty(str) and str or default
end

local POLL_INTERVAL = 2000; -- currently poll as 2sec TODO Dynamic

-- this function is called for every param
local jsonRpcCall=function (process)
  local callback = function()
    --print("callback called")
  end
  local socket = net.createConnection(9192, '127.0.0.1', callback)
  socket:write(getProcessData(process))
  socket:once('data',function(data)
      local sucess,  parsed = parseJson(data)
      if(parsed.result.processes==nil)then
        --print No process Stay Silent TODO logs
      else
        for K,V  in pairs(parsed.result.processes) do
          local per = V["cpuPct"]/100
          local name = process.source.."_"..V["name"]
          local timestamp=os.time()
          print(string.format("%s %s %s %s", 'TRUESIGHT_METER_PROCESSCPU', per,name, timestamp))
        end
      end
      socket:destroy()
  end)
  socket:once('error',function(data)
    print("Socket Resulted in error "..json.stringify(data))
  end)
end


local poll=function ()
  for key,process  in pairs(options) do
    jsonRpcCall(process)
  end
end


-- Set the timer interval and call back function poll().
timer.setInterval(POLL_INTERVAL, poll)

