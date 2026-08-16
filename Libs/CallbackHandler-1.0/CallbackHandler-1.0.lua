--[[ Questie CallbackHandler-1.0 API, Lua 5.0 syntax compatibility ]]
-- Original Questie foundation: CallbackHandler-1.0 r1131 / MINOR 6.
-- Turtle 1.12 Lua 5.0 supports vararg declarations but consumes them through
-- the implicit 'arg' table rather than Lua 5.1's '...' expression.
local MAJOR, MINOR = "CallbackHandler-1.0", 6
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)

if not CallbackHandler then return end

local meta = {__index = function(tbl, key) tbl[key] = {} return tbl[key] end}

local tconcat = table.concat
local assert, error, loadstring = assert, error, loadstring
local setmetatable, rawset, rawget = setmetatable, rawset, rawget
local next, pairs, type, tostring = next, pairs, type, tostring
local unpack = unpack
local xpcall = xpcall

local function errorhandler(err)
  return geterrorhandler()(err)
end

-- Same Questie dispatcher strategy, emitted with fixed named arguments so the
-- generated source contains no Lua 5.1 vararg expressions.
local function CreateDispatcher(argCount)
  local args={}
  local oldargs={}
  for i=1,argCount do
    args[i]="arg"..i
    oldargs[i]="old_arg"..i
  end

  local argList=tconcat(args,", ")
  local oldArgList=tconcat(oldargs,", ")
  local dispatchSignature="handlers"
  if argCount>0 then dispatchSignature=dispatchSignature..", "..argList end

  local saveOld
  local assignArgs
  local restoreOld

  if argCount>0 then
    saveOld="local old_CALL_ARGS = CALL_ARGS"
    assignArgs="CALL_ARGS = {"..argList.."}"
    restoreOld="CALL_ARGS = old_CALL_ARGS"
  else
    saveOld="local old_CALL_ARGS = CALL_ARGS"
    assignArgs="CALL_ARGS = {}"
    restoreOld="CALL_ARGS = old_CALL_ARGS"
  end

  local code=[[
    return function(next, xpcall, eh, unpack)
      local method
      local CALL_ARGS = {}

      local function call()
        method(unpack(CALL_ARGS, 1, CALL_ARGS.n or table.getn(CALL_ARGS)))
      end

      local function dispatch(DISPATCH_SIGNATURE)
        local index
        index, method = next(handlers)
        if not method then return end

        SAVE_OLD
        ASSIGN_ARGS
        CALL_ARGS.n = ARG_COUNT

        repeat
          xpcall(call, eh)
          index, method = next(handlers, index)
        until not method

        RESTORE_OLD
      end

      return dispatch
    end
  ]]

  code=string.gsub(code,"DISPATCH_SIGNATURE",dispatchSignature)
  code=string.gsub(code,"SAVE_OLD",saveOld)
  code=string.gsub(code,"ASSIGN_ARGS",assignArgs)
  code=string.gsub(code,"RESTORE_OLD",restoreOld)
  code=string.gsub(code,"ARG_COUNT",tostring(argCount))

  local chunk=assert(loadstring(code,"safecall Dispatcher["..argCount.."]"))
  local factory=chunk()
  return factory(next,xpcall,errorhandler,unpack)
end

local Dispatchers=setmetatable({},{
  __index=function(self,argCount)
    local dispatcher=CreateDispatcher(argCount)
    rawset(self,argCount,dispatcher)
    return dispatcher
  end
})

function CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)
  RegisterName=RegisterName or "RegisterCallback"
  UnregisterName=UnregisterName or "UnregisterCallback"
  if UnregisterAllName==nil then
    UnregisterAllName="UnregisterAllCallbacks"
  end

  local events=setmetatable({},meta)
  local registry={recurse=0,events=events}

  function registry:Fire(eventname, ...)
    if not rawget(events,eventname) or not next(events[eventname]) then return end

    local oldrecurse=registry.recurse
    registry.recurse=oldrecurse+1

    local count=arg.n or table.getn(arg)
    local callargs={eventname}
    callargs.n=count+1
    for i=1,count do callargs[i+1]=arg[i] end
    Dispatchers[count+1](events[eventname],unpack(callargs,1,callargs.n))

    registry.recurse=oldrecurse

    if registry.insertQueue and oldrecurse==0 then
      for queuedEvent,callbacks in pairs(registry.insertQueue) do
        local first=not rawget(events,queuedEvent) or not next(events[queuedEvent])
        for self,func in pairs(callbacks) do
          events[queuedEvent][self]=func
          if first and registry.OnUsed then
            registry.OnUsed(registry,target,queuedEvent)
            first=nil
          end
        end
      end
      registry.insertQueue=nil
    end
  end

  target[RegisterName]=function(self,eventname,method,...)
    if type(eventname)~="string" then
      error("Usage: "..RegisterName.."(eventname, method[, arg]): 'eventname' - string expected.",2)
    end

    method=method or eventname
    local first=not rawget(events,eventname) or not next(events[eventname])

    if type(method)~="string" and type(method)~="function" then
      error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): 'methodname' - string or function expected.",2)
    end

    local regfunc
    local optionalCount=arg.n or table.getn(arg)

    if type(method)=="string" then
      if type(self)~="table" then
        error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): self was not a table?",2)
      elseif self==target then
        error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): do not use Library:"..RegisterName.."(), use your own 'self'",2)
      elseif type(self[method])~="function" then
        error("Usage: "..RegisterName.."(\"eventname\", \"methodname\"): 'methodname' - method '"..tostring(method).."' not found on self.",2)
      end

      if optionalCount>=1 then
        local extra=arg[1]
        regfunc=function(...)
          self[method](self,extra,unpack(arg,1,arg.n or table.getn(arg)))
        end
      else
        regfunc=function(...)
          self[method](self,unpack(arg,1,arg.n or table.getn(arg)))
        end
      end
    else
      if type(self)~="table" and type(self)~="string" and type(self)~="thread" then
        error("Usage: "..RegisterName.."(self or \"addonId\", eventname, method): 'self or addonId': table or string or thread expected.",2)
      end

      if optionalCount>=1 then
        local extra=arg[1]
        regfunc=function(...)
          method(extra,unpack(arg,1,arg.n or table.getn(arg)))
        end
      else
        regfunc=method
      end
    end

    if events[eventname][self] or registry.recurse<1 then
      events[eventname][self]=regfunc
      if registry.OnUsed and first then
        registry.OnUsed(registry,target,eventname)
      end
    else
      registry.insertQueue=registry.insertQueue or setmetatable({},meta)
      registry.insertQueue[eventname][self]=regfunc
    end
  end

  target[UnregisterName]=function(self,eventname)
    if not self or self==target then
      error("Usage: "..UnregisterName.."(eventname): bad 'self'",2)
    end
    if type(eventname)~="string" then
      error("Usage: "..UnregisterName.."(eventname): 'eventname' - string expected.",2)
    end

    if rawget(events,eventname) and events[eventname][self] then
      events[eventname][self]=nil
      if registry.OnUnused and not next(events[eventname]) then
        registry.OnUnused(registry,target,eventname)
      end
    end

    if registry.insertQueue and rawget(registry.insertQueue,eventname) and registry.insertQueue[eventname][self] then
      registry.insertQueue[eventname][self]=nil
    end
  end

  if UnregisterAllName then
    target[UnregisterAllName]=function(...)
      local count=arg.n or table.getn(arg)
      if count<1 then
        error("Usage: "..UnregisterAllName.."([whatFor]): missing 'self' or \"addonId\" to unregister events for.",2)
      end
      if count==1 and arg[1]==target then
        error("Usage: "..UnregisterAllName.."([whatFor]): supply a meaningful 'self' or \"addonId\"",2)
      end

      for i=1,count do
        local self=arg[i]

        if registry.insertQueue then
          for eventname,callbacks in pairs(registry.insertQueue) do
            if callbacks[self] then callbacks[self]=nil end
          end
        end

        for eventname,callbacks in pairs(events) do
          if callbacks[self] then
            callbacks[self]=nil
            if registry.OnUnused and not next(callbacks) then
              registry.OnUnused(registry,target,eventname)
            end
          end
        end
      end
    end
  end

  return registry
end
