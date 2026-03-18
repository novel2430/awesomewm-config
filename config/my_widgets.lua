local M           = {}
local wibox       = require("wibox")
local gears       = require("gears")
local awful       = require("awful")
local config_var  = require("config.var")
local bat0_path   = "/sys/class/power_supply/BAT0/"
local bat1_path   = "/sys/class/power_supply/BAT1/"
-- help Function
---- Path Exist
local path_exists = function(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  else
    return false
  end
end
---- Read File
local read_file   = function(path)
  local file = io.open(path, "r")
  if file then
    local value = file:read("*l")
    file:close()
    return value
  else
    return nil
  end
end
---- CPU update
local prev_total  = 0
local prev_idle   = 0
local function read_cpu_stat()
  local f = io.open("/proc/stat", "r")
  if not f then return nil end
  local line = f:read("*l")
  f:close()
  local cpu, user, nice, system, idle, iowait, irq, softirq, steal =
      line:match("(%S+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")
  user = tonumber(user)
  nice = tonumber(nice)
  system = tonumber(system)
  idle = tonumber(idle)
  iowait = tonumber(iowait)
  irq = tonumber(irq)
  softirq = tonumber(softirq)
  steal = tonumber(steal)

  local total = user + nice + system + idle + iowait + irq + softirq + steal
  local idle_total = idle + iowait
  return total, idle_total
end
local cpu_update = function()
  local total, idle_total = read_cpu_stat()
  if not total then return end -- 讀取失敗就跳過

  local usage = 0
  if prev_total ~= 0 then
    local diff_total = total - prev_total
    local diff_idle  = idle_total - prev_idle
    usage            = (diff_total - diff_idle) * 100 / diff_total
  end

  prev_total  = total
  prev_idle   = idle_total

  -- 設定 widget markup
  local icon  = ""
  local color = config_var.my_color.fg
  if usage >= 90 then
    color = "#bf616a"
  end

  M.cpu_widget.markup = string.format("<span foreground='%s'>%s %.1f%%</span>", color, icon, usage)
end
---- BAT update
local bat_update = function()
  -- Get Correct BAT path
  local base_path = ""
  if path_exists(bat0_path .. "capacity") then
    base_path = bat0_path
  elseif path_exists(bat1_path .. "capacity") then
    base_path = bat1_path
  else
    M.bat_widget.text = ""
    M.bat_widget.markup = ""
    return
  end

  local status = read_file(base_path .. "status") or "Unknown"
  local per = tonumber(read_file(base_path .. "capacity") or "0") or 0
  local icon = "󰁿"
  local color = config_var.my_color.fg

  if status == "Charging" then
    color = "#78cc81ff"
    icon = "󰠠"
  else
    if per >= 90 then
      icon = "󰁹"
    elseif per >= 80 then
      icon = "󰂂"
    elseif per >= 70 then
      icon = "󰂁"
    elseif per >= 60 then
      icon = "󰂀"
    elseif per >= 50 then
      icon = "󰁿"
    elseif per >= 40 then
      icon = "󰁾"
    elseif per >= 30 then
      icon = "󰁽"
    elseif per >= 20 then
      icon = "󰁼"
    elseif per >= 10 then
      icon = "󰁻"
    elseif per < 10 then
      icon = "󰂃"
    end
  end

  M.bat_widget.markup = string.format("<span foreground='%s'>%s %s%%</span>", color, icon, per)
end
-- TEMP update
local function read_cpu_temp()
  local paths = {
    "/sys/class/thermal/thermal_zone0/temp",
    "/sys/class/hwmon/hwmon1/temp1_input"
  }

  local temp_raw = nil
  for _, path in ipairs(paths) do
    local f = io.open(path, "r")
    if f then
      temp_raw = tonumber(f:read("*l"))
      f:close()
      break
    end
  end

  if not temp_raw then
    return nil
  end

  return temp_raw / 1000
end
local function cpu_temp_update()
  local temp = read_cpu_temp()
  local display = ""
  if temp then
    display = string.format(" %.1f", temp)
  else
    display = ""
  end

  M.temp_widget.markup = string.format("<span foreground='%s'>%s</span>", config_var.my_color.fg, display)
end
-- textclock widget
M.textclock         = wibox.widget.textclock(" %Y-%m-%d %a %H:%M", 5, "Asia/Shanghai")
-- Taglist Buttons
M.taglist_buttons   = gears.table.join(
  awful.button({}, 1, function(t) t:view_only() end),
  awful.button({}, 4, function(t) awful.tag.viewprev(t.screen) end),
  awful.button({}, 5, function(t) awful.tag.viewnext(t.screen) end)
)
-- Focus client name widget
M.focus_titlebox    = wibox.widget {
  text   = "",
  align  = "center",
  valign = "center",
  widget = wibox.widget.textbox
}
-- CPU widget
M.cpu_widget        = wibox.widget {
  align = "center",
  valign = "center",
  widget = wibox.widget.textbox
}
-- CPU widget - Watch Function
M.cpu_widget_watch  = function()
  gears.timer {
    timeout = 1,
    autostart = true,
    call_now = true,
    callback = cpu_update,
  }
end
-- RAM widget
M.ram_widget        = wibox.widget {
  align = "center",
  valign = "center",
  widget = wibox.widget.textbox
}
-- RAM widget - Watch Function
M.ram_widget_watch  = function()
  awful.widget.watch(
    [[
      sh -c "free | awk '/Mem:/ { printf(\"%.1f\", \$3 / \$2 * 100) }'"
    ]],
    5,
    function(widget, stdout)
      local ram_usage = tonumber(stdout) or 0
      widget.text = string.format(" %.1f%%", ram_usage)
    end,
    M.ram_widget
  )
end
-- TEMP widget
M.temp_widget       = wibox.widget {
  align = "center",
  valign = "center",
  widget = wibox.widget.textbox
}
-- TEMP widget - Watch Function
M.temp_widget_watch = function()
  gears.timer {
    timeout = 5,
    autostart = true,
    call_now = true,
    callback = cpu_temp_update,
  }
end
-- Layout widget
M.layout_widget     = wibox.widget {
  align = "center",
  valign = "center",
  widget = wibox.widget.textbox,
  text = config_var.layout_icon.tile
}
-- BAT widget
M.bat_widget        = wibox.widget {
  widget = wibox.widget.textbox,
  align = "center",
  valign = "center"
}
-- BAT widget - Update Function
M.bat_widget_update = function()
  gears.timer {
    timeout = 5,
    autostart = true,
    call_now = true,
    callback = bat_update
  }
end
return M
