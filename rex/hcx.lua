-- hcx Rex actions: drive herdr-core (hc) agents from Rex. Part of the hcx repo; installed by
-- its nix-darwin module as ~/.config/rex/hcx.lua. Load it from your Rex init.lua with
--   dofile(os.getenv("HOME") .. "/.config/rex/hcx.lua")
-- then `rex config reload`. Rex reads init.lua on the server your Rex.app follows for keys
-- (`rex home`), so this only needs loading on that Mac.
--
-- Actions: Agents… (cmd+shift+a), Answer Blocked Agent… (cmd+shift+b), New Agent…,
-- Toggle hc-tui (cmd+shift+space), Fit Agent to This Pane (cmd+shift+f).
-- Change a key after the dofile with rex.unbind / rex.bind. See docs/operations.md.

local HOME = os.getenv("HOME") or "/Users/nich"
local HC = HOME .. "/.local/bin/hc"
local HCX = "/run/current-system/sw/bin/hcx"
local PATH = HOME .. "/.local/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin"
local SHELL = "com.superlogical.terminal.shell"
local AGENTS_SESSION = "agents"

-- Run a command; return its stdout, or nil and why.
local function run(argv, timeout)
  local r, err = rex.exec(argv, { timeout = timeout or 20, env = { PATH = PATH } })
  if not r then return nil, err end
  if not r.ok then return nil, (r.stderr ~= "" and r.stderr or r.stdout) end
  return r.stdout
end

-- Rex shows an error an action raises, but not one it returns. Cancelling a prompt isn't one.
local function guard(f)
  return function(ctx, args)
    local result, why = f(ctx, args)
    if result == nil and why and why ~= "cancelled" then error(why, 0) end
    return result
  end
end

local RANK = { blocked = 0, error = 0, working = 1, done = 2, idle = 3 }

-- The Rex tab label hcx gives an agent (see VIEW_LABEL in hcx).
local function label_of(a)
  return (a.machine == "local" and "" or a.machine .. "/") .. (a.name or a.address:match("[^/]+$"))
end

local function short(path)
  if path and path:sub(1, #HOME) == HOME then return "~" .. path:sub(#HOME + 1) end
  return path or ""
end

-- Live agents on every machine, most urgent first.
local function list_agents()
  local out, err = run({ HCX, "agents", "--json" }, 30)
  if not out then return nil, err end
  local list = rex.json.decode(out)
  table.sort(list, function(x, y)
    local rx, ry = RANK[x.state] or 4, RANK[y.state] or 4
    if rx ~= ry then return rx < ry end
    return label_of(x) < label_of(y)
  end)
  return list
end

-- Ask for one agent (optionally only those `keep` accepts). Returns the agent, or nil and why.
local function pick_agent(title, keep)
  local list, err = list_agents()
  if not list then return nil, err end
  local items, by = {}, {}
  for _, a in ipairs(list) do
    if not keep or keep(a) then
      by[a.address] = a
      items[#items + 1] = {
        id = a.address, title = label_of(a), icon = "terminal", detail = a.state or "",
        subtitle = short(a.cwd) .. (a.msg and ("  ·  " .. a.msg) or ""),
      }
    end
  end
  if #items == 0 then return nil, "no agents to show" end
  local id, why = rex.ui.pick{ title = title, placeholder = "Filter agents", items = items }
  if not id then return nil, why end
  return by[id]
end

-- The ssh target of a Rex host, from its first ssh:// endpoint (`rex hosts`).
local function ssh_target(label)
  local r = rex.exec({ HOME .. "/.local/bin/rex", "hosts", "--json" }, { timeout = 5 })
  if not (r and r.ok) then return nil end
  for _, h in ipairs(rex.json.decode(r.stdout).hosts or {}) do
    if h.host and h.host.label == label then
      for _, e in ipairs(h.host.endpoints or {}) do
        local t = e:match("^ssh://([^/]+)")
        if t then return t end
      end
    end
  end
end

-- A command for another Mac over ssh. Its login shell (fish on the Studio) has a
-- non-interactive PATH without ~/.local/bin, and `env PATH=…` works in fish and sh alike.
-- Callers pass only [a-z0-9:/_.-] words.
local function ssh_argv(target, words)
  return { "/usr/bin/ssh", "-o", "BatchMode=yes", target,
           "env PATH=\"$HOME/.local/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/bin:/bin\" "
           .. table.concat(words, " ") }
end

-- Each Mac mirrors its own agents into its own Rex `agents` session (see hcx rex-sync), so an
-- agent's tab is on its machine's Rex server, labelled without the machine prefix.
local function server_for(machine)
  if machine == "local" then return rex end
  local ok, srv = pcall(rex.server, machine)
  if ok then return srv end
  return nil, "Rex isn't connected to host " .. machine
end

local function agents_session(srv)
  local sessions = srv.call("session.list") or { sessions = {} }
  for _, s in ipairs(sessions.sessions or {}) do
    if s.label == AGENTS_SESSION then return s.session_id end
  end
end

-- The session and window of an agent's tab on its own Mac, after making sure it exists.
local function agent_tab(a)
  if a.machine == "local" then
    run({ HCX, "rex-sync" }, 60)
  else
    local target = ssh_target(a.machine)
    if target then run(ssh_argv(target, { "hcx", "rex-sync" }), 60) end
  end
  local srv, err = server_for(a.machine)
  if not srv then return nil, err end
  local sid = agents_session(srv)
  if not sid then return nil, "no agents session on " .. a.machine end
  local want = a.name or a.address:match("[^/]+$")
  local blocks = srv.call("session.list_blocks", { session_id = sid }) or { blocks = {} }
  for _, b in ipairs(blocks.blocks or {}) do
    if b.label == want then return sid, b.window_id end
  end
  return nil, "no tab for " .. label_of(a)
end

local function show(session_id, window_id)
  rex.client.queue("session.select", { session_id = session_id, window_id = window_id })
end

local function go_to(a)
  local sid, wid = agent_tab(a)
  if not sid then return nil, wid end
  show(sid, wid)
end

-- Recent output in a floating pane over the window you're in, read by the hc core of the Mac
-- that window lives on. This Mac's core sees every machine; another Mac's sees only its own.
local function read_output(a, ctx)
  if not a.address:match("^[%w/._-]+$") then return nil, "unexpected address" end
  local srv, sid, addr = rex, ctx.session_id, a.address
  if ctx.server then
    if ctx.server == a.machine then
      srv, addr = server_for(ctx.server), a.address:match("[^/]+$")
    else   -- that Mac can't see this agent: read it here, in this Mac's agents session
      sid = agents_session(rex)
      if not sid then return nil, "no agents session on this Mac" end
    end
  end
  if not (srv and sid) then return nil, "no window to show the output in" end
  local _, err = srv.session.new_layer{
    session_id = sid, focus = true, bounds = { 0.04, 0.04, 0.92, 0.92 },
    layout = rex.layout.block{ flavor = SHELL, options = {
      command = { "/bin/sh", "-c", "\"$HOME/.local/bin/hc\" read '" .. addr .. "' --lines 3000 | less -R +G" } } },
  }
  if err then return nil, err end
  if ctx.server and ctx.server ~= a.machine then show(sid) end
end

local function send_to(a)
  local text, why = rex.ui.input{ title = "Message to " .. label_of(a), placeholder = "Sent when it's not busy with a draft" }
  if not text then return nil, why end
  if text == "" then return end
  return run({ HC, "send", a.address, text })
end

rex.action{
  name = "agents",
  title = "Agents…",
  description = "Pick an agent on any machine, then go to its tab, read its output, message it or interrupt it.",
  category = "Agents",
  keywords = "hc herdr agent omp list switch go message send interrupt read output",
  run = guard(function(ctx)
    local a, why = pick_agent("Agents")
    if not a then return nil, why end
    local what, why2 = rex.ui.pick{
      title = label_of(a) .. "  ·  " .. (a.state or "no status"),
      items = {
        { id = "view", title = "Go to its tab", icon = "terminal" },
        { id = "read", title = "Read recent output", icon = "document" },
        { id = "send", title = "Send a message", icon = "person" },
        { id = "interrupt", title = "Interrupt", subtitle = "Presses its stop key", icon = "clock" },
      },
    }
    if not what then return nil, why2 end
    if what == "view" then return go_to(a) end
    if what == "read" then return read_output(a, ctx) end
    if what == "send" then return send_to(a) end
    if what == "interrupt" then return run({ HC, "interrupt", a.address }) end
  end),
}

rex.action{
  name = "answer_agent",
  title = "Answer Blocked Agent…",
  description = "Pick an agent that is waiting for you and answer it. A single digit picks that option.",
  category = "Agents",
  keywords = "hc herdr agent blocked waiting question answer asks approve",
  run = guard(function()
    local a, why = pick_agent("Answer a blocked agent", function(x) return x.state == "blocked" or x.state == "error" end)
    if not a then return nil, why end
    local reply, why2 = rex.ui.input{
      title = label_of(a) .. ": " .. (a.msg or "waiting for you"),
      placeholder = "Your answer (a single digit picks that option)",
    }
    if not reply then return nil, why2 end
    if reply == "" then return end
    if reply:match("^%d$") then return run({ HC, "keys", a.address, reply }) end
    -- --force: the agent is blocked on exactly this question, and a plain send waits it out.
    return run({ HC, "send", "--force", a.address, reply })
  end),
}

rex.action{
  name = "new_agent",
  title = "New Agent…",
  description = "Start omp in hc on this Mac or another machine, then open its tab.",
  category = "Agents",
  keywords = "hc herdr agent omp new start launch run",
  run = guard(function()
    local machines = { { id = "local", title = "This Mac", icon = "terminal" } }
    local out = run({ HC, "machine", "ls", "--json" })
    for _, m in ipairs(out and (rex.json.decode(out).machines or {}) or {}) do
      machines[#machines + 1] = { id = m.name, title = m.name, subtitle = m.host or m.target, icon = "server" }
    end
    local machine = "local"
    if #machines > 1 then
      local why
      machine, why = rex.ui.pick{ title = "Start the agent on", items = machines }
      if not machine then return nil, why end
    end
    -- Folders agents on that machine use now, plus whatever you type.
    local seen, dirs = {}, {}
    for _, a in ipairs(list_agents() or {}) do
      if a.machine == machine and a.cwd and not seen[a.cwd] then
        seen[a.cwd] = true
        dirs[#dirs + 1] = { id = a.cwd, title = short(a.cwd), icon = "folder" }
      end
    end
    local dir, why = rex.ui.pick{ title = "Folder", placeholder = "Pick or type a full path", items = dirs, allow_other = true }
    if not dir then return nil, why end
    if type(dir) == "table" then dir = (dir.text:gsub("^~", HOME)) end
    local name, why2 = rex.ui.input{ title = "Agent name", value = dir:match("([^/]+)/*$") or "agent" }
    if not name then return nil, why2 end
    if not name:match("^[%w._-]+$") then return nil, "names are letters, digits, . _ and - only" end
    local argv = { HC, "run", "--bg", "--name", name, "--cwd", dir }
    if machine ~= "local" then table.insert(argv, 3, machine); table.insert(argv, 3, "--on") end
    argv[#argv + 1] = "--"
    argv[#argv + 1] = "omp"
    local ok, err = run(argv, 30)
    if not ok then return nil, err end
    run({ "/bin/sleep", "3" })   -- hc names the agent once omp is in the foreground
    local a = { machine = machine, name = name, address = name }
    return go_to(a)
  end),
}

rex.action{
  name = "toggle_hc_tui",
  title = "Toggle hc-tui",
  description = "Show or hide hc-tui floating over this window, on the Mac this window lives on.",
  category = "Agents",
  keywords = "hc herdr hc-tui tui agents floating overlay",
  run = guard(function(ctx)
    -- The pane opens on the server of the window you're in (this Mac or a host), so the command
    -- must work on either Mac: hc-tui is in ~/.local/bin on the Studio and in the system path here.
    local sid = ctx.session_id
    if not sid then return nil, "no window to show hc-tui in" end
    local blocks = rex.call("session.list_blocks", { session_id = sid }) or { blocks = {} }
    for _, b in ipairs(blocks.blocks or {}) do
      if b.label == "hc-tui" then return rex.call("block.close", { session_id = sid, block_id = b.block_id }) end
    end
    local _, err = rex.session.new_layer{
      session_id = sid, focus = true, bounds = { 0.06, 0.05, 0.88, 0.9 },
      layout = rex.layout.block{ flavor = SHELL, label = "hc-tui", options = { command = { "/bin/sh", "-c",
        'for p in "$HOME/.local/bin/hc-tui" /run/current-system/sw/bin/hc-tui; do [ -x "$p" ] && exec "$p"; done; '
        .. 'echo "hc-tui is not installed on $(hostname -s)"; sleep 8' } } },
    }
    if err then return nil, err end
  end),
}


rex.action{
  name = "fit_agent",
  title = "Fit Agent to This Pane",
  description = "Make the hc terminal shown in this pane take the pane's size again.",
  category = "Agents",
  keywords = "hc herdr agent resize size fit redraw attach",
  run = guard(function(ctx)
    if not (ctx.session_id and ctx.block_id) then return nil, "no pane to fit" end
    if not (ctx.session_id .. ctx.block_id):match("^[%w:%-]+$") then return nil, "unexpected pane id" end
    local argv
    if ctx.server then
      local target = ssh_target(ctx.server)
      if not target then return nil, "no ssh:// endpoint for host " .. ctx.server end
      -- ssh hands the remote command to that machine's login shell (fish on the Studio), whose
      -- non-interactive PATH may miss ~/.local/bin; `env PATH=…` works in fish and sh alike.
      -- Session and block ids are [a-z0-9:-] only (checked above).
      argv = { "/usr/bin/ssh", "-o", "BatchMode=yes", target,
               "env PATH=\"$HOME/.local/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/bin:/bin\" " ..
               "hcx fit --rex-block " .. ctx.session_id .. " " .. ctx.block_id }
    else
      argv = { HCX, "fit", "--rex-block", ctx.session_id, ctx.block_id }
    end
    return run(argv, 15)
  end),
}

rex.bind("cmd+shift+a", "agents")
rex.bind("cmd+shift+b", "answer_agent")
rex.bind("cmd+shift+space", "toggle_hc_tui")
rex.bind("cmd+shift+f", "fit_agent")
