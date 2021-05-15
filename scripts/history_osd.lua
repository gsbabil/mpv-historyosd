local opts = {
	
	key_closemenu = "ESC",
	key_moveup = "UP WHEEL_UP",
	key_movedown = "DOWN WHEEL_DOWN",
	key_playfile = "MBTN_LEFT ENTER",
	max_history = 5,
	font_size = 24,
	full_paths = false,
}

local assdraw = require("mp.assdraw")
local opt = require ('mp.options')
read_options(opts, "historyosd")

local history_path = (os.getenv('APPDATA') or os.getenv('HOME')..'/.config')..'/mpv/watch_history.log';

function find_value(tbl, value)
	local findex = 0
	for index, item in ipairs(tbl) do
		if(item == value) then 
			findex = index
			break
		end
	end
	return findex
end

mp.register_event('file-loaded', function()
	close_menu()

    local title, fp

    title = mp.get_property('media-title')
    title = (title == mp.get_property('filename') and '' or (' (%s)'):format(title))

    fp = io.open(history_path, 'r')
	
	local datalines = {}
	if fp ~= nil then 
		-- Read all lines except last
		local cline = 1
		while cline <= (opts.max_history) do
			local lx = fp:read()
			
			if not lx then
				break
			end
			
			table.insert(datalines, lx)
			cline = cline + 1
		end
		fp:close()
	end

	-- Output lines
	fp = io.open(history_path, 'w+')
	local ourLine = ("%s"):format(mp.get_property('path'))
	
	-- Find if our entry is already in the table.
	local valIndex = find_value(datalines, ourLine)
	if valIndex ~= 0 then 
		table.remove(datalines, valIndex)
		table.insert(datalines, 1, ourLine)
	else
		table.insert(datalines, 1, ourLine)
	end
	
	for index, item in ipairs(datalines) do
		if index > opts.max_history then
			break
		end
		fp:write(item .. "\n")
	end
    fp:close()
end);

-- OSD menu rendering
local menu_visible = false
local cursor = 1

function toggle_menu()
  if menu_visible then
    remove_keybinds()
    return
  end
	
	load_history()
	render()
end

function close_menu()
	remove_keybinds()
end

local menu_items = {}
local menu_size = 0

function load_history()
	local fp = io.open(history_path, 'r')
	
	menu_items = {}
	for s in fp:lines() do
		table.insert(menu_items, s)
	end
	
	menu_size = #menu_items
	
	fp:close()
end

function render()

	local font_size = opts.font_size
	
	local ass = assdraw.ass_new()
	ass:new_event()
	ass:pos(30, 15)
	ass:append("{\\fs" .. font_size .. "}")
	
	for index, item in ipairs(menu_items) do
		local selected = (index == cursor)
		local prefix = selected and "● " or "○ "
		local item_text = item
		
		if opts.full_paths ~= true then
			item_text = item_text:match("([%a%d-_.%[%]%(%)%s]+%..*)$")
		end
		
		ass:append(prefix .. item_text .. "\\N")
	end
	
	local w, h = mp.get_osd_size()
	mp.set_osd_ass(w, h, ass.text)
	
	menu_visible = true
	add_keybinds()
end

function move_up()
	if cursor ~= 1 then
		cursor = cursor - 1
	end
	render()
end

function move_down()
	if cursor ~= menu_size then
		cursor = cursor + 1
	end
	render()
end

function play_media()
	menu_visible = false
	toggle_menu()
	mp.commandv('loadfile', menu_items[cursor], "replace")
end

-- Keybinds
function bind_keys(keys, name, func, opts)
  if not keys then
    mp.add_forced_key_binding(keys, name, func, opts)
    return
  end
  local i = 1
  for key in keys:gmatch("[^%s]+") do
    local prefix = i == 1 and '' or i
    mp.add_forced_key_binding(key, name..prefix, func, opts)
    i = i + 1
  end
end

function unbind_keys(keys, name)
  if not keys then
    mp.remove_key_binding(name)
    return
  end
  local i = 1
  for key in keys:gmatch("[^%s]+") do
    local prefix = i == 1 and '' or i
    mp.remove_key_binding(name..prefix)
    i = i + 1
  end
end

function add_keybinds()

	bind_keys(opts.key_playfile, 'history-playfile', play_media)
	bind_keys(opts.key_moveup, 'history-moveup', move_up)
	bind_keys(opts.key_movedown, 'history-movedown', move_down)
	bind_keys(opts.key_closemenu, 'history-closemenu', remove_keybinds)

end

function remove_keybinds()
	menu_visible = false
	mp.set_osd_ass(0,0,"")
	unbind_keys(opts.key_playfile, 'history-playfile')
	unbind_keys(opts.key_moveup, 'history-moveup')
	unbind_keys(opts.key_movedown, 'history-movedown')
	unbind_keys(opts.key_closemenu, 'history-closemenu')
end

mp.register_script_message('history-toggle', toggle_menu)
mp.add_key_binding("MBTN_MID", 'history-toggle', toggle_menu)