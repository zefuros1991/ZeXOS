-- Workspaces that behave like niri's
--
-- * There is always exactly one empty workspace, right after the last one
--   with windows. Open a window on it and the next empty one appears.
-- * Close the last window of a workspace and, once you leave it, it is gone:
--   the workspaces after it move up by one (3 becomes 2, and so on).
--   While you are standing on the empty one it stays, so it does not
--   vanish under you.
-- * Going to a number, or stepping next/previous, never goes past that
--   empty workspace, and stepping up from workspace 1 does nothing (no
--   wrapping around).
-- * Taking a window along (Mod+Ctrl+...) follows the same rules and your
--   focus goes with the window.
--
-- Hyprland itself numbers workspaces for good and lets empty ones vanish
-- wherever they are, so this file keeps the numbers in line itself. Keys,
-- mouse wheel and the touchpad gesture all call the functions at the
-- bottom, which is also what tests/workspaces runs.
-- With more than one screen the numbers are shared between the screens,
-- so the tidying up is switched off (the limits still work).
local M = {}

local busy = false

local function screens()
    local n = 0
    for _ in pairs(hl.get_monitors()) do n = n + 1 end
    return n
end

-- Numbers of the normal workspaces that hold windows, lowest first.
local function filled()
    local ids = {}
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.id > 0 and ws.windows > 0 then ids[#ids + 1] = ws.id end
    end
    table.sort(ids)
    return ids
end

local function current()
    local ws = hl.get_active_workspace()
    return ws and ws.id or 1
end

-- The empty workspace after the last one with windows.
local function last_slot()
    local ids = filled()
    return (ids[#ids] or 0) + 1
end

-- Where a request really lands: at least 1, at most the empty one at the end.
local function clamp(n)
    return math.max(1, math.min(n, last_slot()))
end

local function view(n)
    hl.dispatch(hl.dsp.focus({ workspace = n }))
end

-- Squeeze out the gaps: workspaces with windows (plus the one you stand on)
-- get the numbers 1, 2, 3 ... in their present order.
local function tidy()
    if busy or screens() > 1 then return end
    busy = true
    local here = current()
    local keep, seen = {}, {}
    for _, id in ipairs(filled()) do keep[#keep + 1] = id; seen[id] = true end
    if not seen[here] and here > 0 then keep[#keep + 1] = here end
    table.sort(keep)
    local new_here = here
    for rank, id in ipairs(keep) do
        if id ~= rank then
            for _, w in ipairs(hl.get_windows()) do
                if w.workspace and w.workspace.id == id then
                    hl.dispatch(hl.dsp.window.move({ workspace = rank, window = w, follow = false }))
                end
            end
            if id == here then new_here = rank end
        end
    end
    if new_here ~= here then view(new_here) end
    busy = false
end

function M.go(n) view(clamp(n)) end

function M.next() view(clamp(current() + 1)) end

function M.prev() view(clamp(current() - 1)) end

function M.move(n)
    hl.dispatch(hl.dsp.window.move({ workspace = clamp(n) }))
end

function M.move_next() M.move(current() + 1) end

function M.move_prev() M.move(current() - 1) end

-- Tidy up a moment after anything that can leave a gap (the delay lets
-- Hyprland finish what it is doing first).
local function later()
    hl.timer(tidy, { timeout = 50, type = "oneshot" })
end
hl.on("workspace.active", later)
hl.on("window.close", later)
hl.on("window.move_to_workspace", later)

return M
