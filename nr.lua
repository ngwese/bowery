math = require("math")

-- constants
patterns = {34952,34954,34962,34964,34978}
num_patterns = #patterns
pattern_step = 10 / num_patterns

factors = {1,2,4,8,16,3,6,9,12,5,10,15,7,14,11,13}
num_factors = #factors
factor_step = 10 / num_factors

-- state
reset = false
step = 0     -- current step [0-15]
pattern = 0  -- current pattern value
fs = {}      -- current factor values
pn = {}      -- current txi param knob values
cn = {}      -- current txi cv in values
ch = 0       -- which txi channel we are polling
do_poll = {} -- flags which indicate whether it is safe to start another txi poll

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

function select_param(k)
  if k == 1 then
    local idx = math.floor(pn[k] / pattern_step)
    if idx ~= pattern then
      pattern = idx
      print("pattern: " .. pattern)
    end
  else
    local idx = math.floor(pn[k] / factor_step)
    local fn = k - 1
    if idx ~= fs[fn] then
      fs[fn] = idx
      print("factor " .. fn .. ": " .. idx)
    end
  end
end

function txi_event(e, data)
  local k = ch + 1
  if e == 'param' then
    pn[k] = data
    do_poll['param'] = true
    select_param(k)
  elseif e == 'in' then
    cn[k] = data
    do_poll['in'] = true
  end

  -- if all polls are accounted for move to the next channel
  if do_poll['param'] and do_poll['in'] then
    ch = (ch + 1) %  4
    --print("param: " .. pn[1] .. " " .. pn[2] .. " " .. pn[3] .. " " .. pn[4])
    --print("   in: " .. cn[1] .. " " .. cn[2] .. " " .. cn[3] .. " " .. cn[4])
  end
end

function txi_poll(count)
  local k = ch + 1 -- txi ch is one's based
  if do_poll['param'] and do_poll['in'] then
    -- print("polling: " .. k)
    -- request current knob/param value
    ii.txi.get('param', k)
    do_poll['param'] = false

    -- request current cv/in value
    ii.txi.get('in', k)
    do_poll['in'] = false
  end
end

function init()
  -- inputs
  input[1]{mode = 'change', direction = 'rising'}
  input[1].change = clock_in
  input[2]{mode = 'change', direction = 'rising'}
  input[2].change = reset

  -- initialize channel base params
  for i = 1,4 do
    -- outputs
    output[i].slew = 0
    output[i].volts = 0
    output[i].action = pulse(0.02, 6, true)

    pn[i] = 0 -- txi param knobs
    cn[i] = 0 -- txi cv in
  end

  do_poll['param'] = true
  do_poll['in'] = true

  -- misc
  ii.pullup(false)
  ii.txi.event = txi_event
  poller = metro.init{ event = txi_poll, time = 0.125 }
  poller:start()

  -- TODO: txi for factor selection and factor cv

  prime(0)
  factor(1, 3)
  factor(2, 0)
  factor(3, 0)

  reset(true)
end
