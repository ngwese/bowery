-- constants
patterns = {34952,34954,34962,34964,34978}
num_patterns = #patterns

factors = {1,2,4,8,16,3,6,9,12,5,10,15,7,14,11,13}
num_factors = #factors

-- state
reset = false
step = 0     -- current step [0-15]
pattern = 0  -- current pattern value
fs = {}      -- current factor values

function clock_in(v)
  if reset and ((step % 4) == 0) then
    -- print("did reset on: ".. step)
    step = 0
    reset = false
  end
  local s = 15 - step

  local o1 = (pattern >> s) & 0x1
  if o1 == 1 then output[1]() end

  local o2 = ((pattern * fs[1]) >> s) & 0x1
  if o2 == 1 then output[2]() end

  local o3 = (((pattern & 0x0f0f) * fs[2]) >> s) & 0x1
  if o3 == 1 then output[3]() end

  local o4 = (((pattern & 0xf003) * fs[3]) >> s) & 0x1
  if o4 == 1 then output[4]() end

  -- advance step
  step = (step + 1) % 16
end

function reset(v)
  reset = true
  -- print("reset")
end

function prime(n)
  pattern = patterns[(n % num_patterns) + 1]
  print("pattern: " .. pattern)
end

function factor(f, n)
  fs[f] = factors[(n % num_factors) + 1] 
end

function txi_event(e, data)
  print("e: " .. e .. " d: " .. data)
end

function txi_poll(count)
  ii.txi.get('param', 3)
end

function init()
  -- inputs
  input[1]{mode = 'change', direction = 'rising'}
  input[1].change = clock_in
  input[2]{mode = 'change', direction = 'rising'}
  input[2].change = reset

  -- outputs
  for i = 1,4 do
    output[i].slew = 0
    output[i].volts = 0
    output[i].action = pulse(0.02, 6, true)
  end
  
  -- misc
  ii.pullup(false)
  ii.txi.event = txi_event
  --poller = metro.init{ event = txi_poll, time = 0.5 }
  --poller:start()
  
  -- TODO: txi for factor selection and factor cv

  prime(0)
  factor(1, 3)
  factor(2, 0)
  factor(3, 0)
  
  reset(true)
end

init()
