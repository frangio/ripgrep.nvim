local function class()
  local klass = {}
  local meta = {__index = klass}
  function klass.new(...)
    local instance = {}
    setmetatable(instance, meta)
    if instance.initialize ~= nil then
      instance:initialize(...)
    end
    return instance
  end
  return klass
end

return class
