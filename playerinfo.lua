-- Player information tool by ShadyRetard
local listen_to_events = {
    "game_init",
    "player_team",
    "player_changename",
    "game_end",
    "player_disconnect"
}

local SCRIPT_FILE_NAME = GetScriptName();
local SCRIPT_FILE_ADDR = "https://raw.githubusercontent.com/hyperthegreat/aw_playerinfo/master/playerinfo.lua";
local VERSION_FILE_ADDR = "https://raw.githubusercontent.com/hyperthegreat/aw_playerinfo/master/version.txt";
local NETWORK_GET_ADDR = "https://api.shadyretard.io/playerinfo/%s";

local SHOW_WINDOW_CB = gui.Checkbox(gui.Reference("MISC", "Automation", "Other"), "PIT_SHOW_WINDOW_CB", "Show player information", true);

local VERSION_NUMBER = "1.0.2";
local version_check_done = false;
local update_downloaded = false;
local update_available = false;

local selected_player_id;
local fields_to_show;
local playerinfo_cache = {};

local PLAYERINFO_WINDOW_X, PLAYERINFO_WINDOW_Y = 200, 200;
local PLAYERINFO_WINDOW_WIDTH, PLAYERINFO_WINDOW_HEIGHT = 640, 350;
local is_dragging = false;
local last_click = globals.RealTime();
local dragging_offset_x, dragging_offset_y;

for _, v in ipairs(listen_to_events) do
    client.AllowListener(v);
end

local function is_mouse_in_rect(left, top, width, height)
    local mouse_x, mouse_y = input.GetMousePos();
    return (mouse_x >= left and mouse_x <= left + width and mouse_y >= top and mouse_y <= top + height);
end

local function draw_shadow(left, top, right, bottom, color, length, fade)
    local shadow_r, shadow_g, shadow_b, shadow_a = gui.GetValue(color);

    local a = math.min(shadow_a, length);
    local l = left;
    local t = top;
    local r = right;
    local b = bottom;
    for i = 1, length / 2 do
        a = a - fade;

        if (a < 0) then
            break;
        end

        l = l - 1;
        t = t - 1;
        b = b + 1;
        r = r + 1;
        draw.Color(shadow_r, shadow_g, shadow_b, a);
        draw.OutlinedRect(l, t, r, b);
    end
end

local function draw_menu()
    draw.Color(gui.GetValue('clr_gui_window_background'));
    draw.FilledRect(PLAYERINFO_WINDOW_X, PLAYERINFO_WINDOW_Y - 25, PLAYERINFO_WINDOW_X + PLAYERINFO_WINDOW_WIDTH, PLAYERINFO_WINDOW_Y + PLAYERINFO_WINDOW_HEIGHT);
    draw.Color(gui.GetValue('clr_gui_window_header'));
    draw.FilledRect(PLAYERINFO_WINDOW_X, PLAYERINFO_WINDOW_Y - 50, PLAYERINFO_WINDOW_X + PLAYERINFO_WINDOW_WIDTH, PLAYERINFO_WINDOW_Y - 25);
    draw.Color(gui.GetValue('clr_gui_window_header_tab2'));
    draw.FilledRect(PLAYERINFO_WINDOW_X, PLAYERINFO_WINDOW_Y - 25, PLAYERINFO_WINDOW_X + PLAYERINFO_WINDOW_WIDTH, PLAYERINFO_WINDOW_Y - 25 + 4);
    draw.Color(gui.GetValue('clr_gui_text1'));
    draw.TextShadow(PLAYERINFO_WINDOW_X + 8, PLAYERINFO_WINDOW_Y - 25 - 18, "Player Information Tool");

    draw.Color(gui.GetValue('clr_gui_window_footer'));
    draw.FilledRect(PLAYERINFO_WINDOW_X, PLAYERINFO_WINDOW_Y + PLAYERINFO_WINDOW_HEIGHT, PLAYERINFO_WINDOW_X + PLAYERINFO_WINDOW_WIDTH, PLAYERINFO_WINDOW_Y + PLAYERINFO_WINDOW_HEIGHT + 20);
    draw.Color(gui.GetValue('clr_gui_window_footer_text'));
    draw.TextShadow(PLAYERINFO_WINDOW_X + 8, PLAYERINFO_WINDOW_Y + PLAYERINFO_WINDOW_HEIGHT + 4, "By ShadyRetard");
    draw_shadow(PLAYERINFO_WINDOW_X, PLAYERINFO_WINDOW_Y - 50, PLAYERINFO_WINDOW_X + PLAYERINFO_WINDOW_WIDTH, PLAYERINFO_WINDOW_Y - 25 + PLAYERINFO_WINDOW_HEIGHT + 20, 'clr_gui_window_shadow', 20, 2);
end

local function draw_list(mouse_down)
    draw.Color(gui.GetValue('clr_gui_groupbox_background'))
    draw.FilledRect(PLAYERINFO_WINDOW_X + 10, PLAYERINFO_WINDOW_Y - 10, PLAYERINFO_WINDOW_X + 210, PLAYERINFO_WINDOW_Y + PLAYERINFO_WINDOW_HEIGHT);
    draw.Color(gui.GetValue('clr_gui_text1'));
    draw.Text(PLAYERINFO_WINDOW_X + 15, PLAYERINFO_WINDOW_Y - 15, "Player List");

    local offset = 5;
    for steam_id, info in pairs(playerinfo_cache) do
        draw.Color(gui.GetValue('clr_gui_text1'));

        if (selected_player_id ~= nil and selected_player_id == steam_id) then
            draw.Color(255, 191, 0, 255);
        end

        local w, h = draw.GetTextSize(info["summary"]["nickname"]);
		if (h ~= nil) then
            draw.Text(PLAYERINFO_WINDOW_X + 15, PLAYERINFO_WINDOW_Y + offset, info["summary"]["nickname"]);

            if (mouse_down and is_mouse_in_rect(PLAYERINFO_WINDOW_X + 15, PLAYERINFO_WINDOW_Y + offset, 200, h)) then
                if (selected_player_id ~= steam_id) then
                    selected_player_id = steam_id;
                    fields_to_show = nil;
                end

                last_click = globals.RealTime();
            end

            offset = offset + h;
        end
    end
end

local function draw_player_info(mouse_down)
    draw.Color(gui.GetValue('clr_gui_groupbox_background'))
    draw.FilledRect(PLAYERINFO_WINDOW_X + 230, PLAYERINFO_WINDOW_Y - 10, PLAYERINFO_WINDOW_X + 230 + 400, PLAYERINFO_WINDOW_Y + PLAYERINFO_WINDOW_HEIGHT);
    draw.Color(gui.GetValue('clr_gui_text1'));
    draw.Text(PLAYERINFO_WINDOW_X + 245, PLAYERINFO_WINDOW_Y - 15, "Player Info");

    if (selected_player_id == nil) then return end
    if (fields_to_show == nil) then
        fields_to_show = {};
    local playerinfo = playerinfo_cache[selected_player_id]
    if (playerinfo == nil) then return end

    local summary = playerinfo["summary"];
    if (summary ~= nil) then
        table.insert(fields_to_show, { title = "SteamID", value = summary["steamID"] });
        table.insert(fields_to_show, { title = "Steam URL", value = summary["url"] });
        table.insert(fields_to_show, { title = "Nickname", value = summary["nickname"] });
        table.insert(fields_to_show, { title = "Real name", value = summary["realName"] });
        table.insert(fields_to_show, { title = "Account Created", value = os.date('%Y-%m-%d %H:%M:%S', summary["created"]) });
        table.insert(fields_to_show, { title = "Last logged in", value = os.date('%Y-%m-%d %H:%M:%S', summary["lastLogOff"]) });
        table.insert(fields_to_show, { title = "Playing CS:GO", value = tostring(summary["gameID"] == 730) });
    end

    local friends = playerinfo["friends"];
    if (friends ~= nil) then
        table.insert(fields_to_show, { title = "Friends", value = #friends });
    else
        table.insert(fields_to_show, { title = "Friends", value = 0 });
    end

    table.insert(fields_to_show, { title = "Steam Level", value = playerinfo["level"] })

    local bans = playerinfo["bans"];
    if (bans ~= nil) then
        table.insert(fields_to_show, { title = "Game Bans", value = bans["gameBans"] });
        table.insert(fields_to_show, { title = "VAC Bans", value = bans["vacBans"] });
        table.insert(fields_to_show, { title = "Economy Ban", value = bans["economyBan"] });
        table.insert(fields_to_show, { title = "Days since last ban", value = bans["daysSinceLastBan"] });
    end

    local statistics = playerinfo["stats"];
    if (statistics ~= nil) then
        local stats = statistics["stats"];
        if (stats ~= nil) then
            table.insert(fields_to_show, { title = "Total Time Played", value = string.format("%.2f", stats["total_time_played"] / 60 / 60) .. " hours" })
            table.insert(fields_to_show, { title = "Total Matches Played", value = stats["total_matches_played"] });
            table.insert(fields_to_show, { title = "Total Matches Won", value = stats["total_matches_won"] });
            table.insert(fields_to_show, { title = "Total Win Ratio", value = string.format("%.2f", stats["total_matches_won"] / stats["total_matches_played"] * 100) .. "%" });
            table.insert(fields_to_show, { title = "Total Kills", value = stats["total_kills"] });
            table.insert(fields_to_show, { title = "Total Kills Headshot", value = stats["total_kills_headshot"] });
            table.insert(fields_to_show, { title = "Total Deaths", value = stats["total_deaths"] });
            table.insert(fields_to_show, { title = "Total KDA", value = string.format("%.2f", stats["total_kills"] / stats["total_deaths"]) });
            table.insert(fields_to_show, { title = "Total Shots Fired", value = stats["total_shots_fired"] });
            table.insert(fields_to_show, { title = "Total Shots Hit", value = stats["total_shots_hit"] });
            table.insert(fields_to_show, { title = "Total Shot Accuracy", value = string.format("%.2f", (stats["total_shots_hit"] / stats["total_shots_fired"]) * 100) .. "%" });
        end

        local achievements = statistics["achievements"];
        if (achievements ~= nil) then
            table.insert(fields_to_show, { title = "Achievements", value = #achievements });
        else
            table.insert(fields_to_show, { title = "Achievements", value = 0 });
        end
    end
end

    local offset = 5;
    for _, v in ipairs(fields_to_show) do
        if (v ~= nil and v["title"] ~= nil and v["value"] ~= nil) then
            local w, h = draw.GetTextSize(v["title"] .. ": " .. v["value"]);
            draw.Text(PLAYERINFO_WINDOW_X + 245, PLAYERINFO_WINDOW_Y + offset, v["title"] .. ": " .. v["value"]);
            offset = offset + h;
        end
    end
end

local function key_in_table(tbl, key)
    for k, _ in pairs(tbl) do
        if key == k then
            return true
        end
    end
    return false
end

local function value_in_table(tbl, value)
    for _, v in ipairs(tbl) do
        if value == v then
            return true
        end
    end
    return false
end

local char_to_hex = function(c)
  return string.format("%%%02X", string.byte(c))
end

local function urlencode(url)
  if url == nil then
    return
  end
  url = url:gsub("\n", "\r\n")
  url = url:gsub("([^%w ])", char_to_hex)
  url = url:gsub(" ", "+")
  return url
end

local function update_players()
    local my_player = entities.GetLocalPlayer();
    if (my_player == nil) then return end

	for i = 1, globals.MaxClients(), 1 do
		local player_info = client.GetPlayerInfo(i);
		if (player_info ~= nil and player_info["IsBot"] == false and key_in_table(playerinfo_cache, player_info["SteamID"]) == false) then
			http.Get(string.format(NETWORK_GET_ADDR, urlencode(player_info["SteamID"])), function(response)
				if (response == nil or response == "error" or key_in_table(playerinfo_cache, player_info["SteamID"]) == true) then return end
				playerinfo_cache[player_info["SteamID"]] = json.decode(response);
			end)
		end
	end
end

callbacks.Register("Draw", function()
    if (gui.GetValue("lua_allow_http") == false) then
        draw.Color(255, 0, 0, 255);
        draw.Text(25, 25, "[PIT] Allow internet connections from lua needs to be enabled to use this script");
        return;
    end
    if (gui.GetValue("lua_allow_cfg") == false) then
        draw.Color(255, 0, 0, 255);
        draw.Text(25, 25, "[PIT] Allow script/config editing from lua need to be enabled to use this script");
        return;
    end

    if (not gui.Reference("MENU"):IsActive() or SHOW_WINDOW_CB:GetValue() == false) then return end

    if (last_click ~= nil and last_click > globals.RealTime()) then
        last_click = globals.RealTime();
    end

    local mouse_down = input.IsButtonPressed(1);
    draw_menu();
    draw_list(mouse_down);
    draw_player_info(mouse_down);
end)

callbacks.Register("Draw", function()
    if (gui.GetValue("lua_allow_http") == false or gui.GetValue("lua_allow_cfg") == false) then
        return;
    end

    if (SHOW_WINDOW_CB:GetValue() == false) then return end

    local mouse_x, mouse_y = input.GetMousePos();
    local left_mouse_down = input.IsButtonDown(1);
    local left_mouse_pressed = input.IsButtonPressed(1);

    if (is_dragging == true and left_mouse_down == false) then
        is_dragging = false;
        dragging_offset_x = 0;
        dragging_offset_y = 0;
        return;
    end

    if (is_dragging == true) then
        PLAYERINFO_WINDOW_X = mouse_x - dragging_offset_x;
        PLAYERINFO_WINDOW_Y = mouse_y - dragging_offset_y;
        return;
    end

    if (left_mouse_pressed and is_mouse_in_rect(PLAYERINFO_WINDOW_X, PLAYERINFO_WINDOW_Y - 50, PLAYERINFO_WINDOW_WIDTH, 25)) then
        is_dragging = true;
        dragging_offset_x = mouse_x - PLAYERINFO_WINDOW_X;
        dragging_offset_y = mouse_y - PLAYERINFO_WINDOW_Y;
        return;
    end
end)

callbacks.Register("Draw", function()
    if (update_available and not update_downloaded) then
        if (gui.GetValue("lua_allow_cfg") == false) then
            draw.Color(255, 0, 0, 255);
            draw.Text(0, 0, "[PlayerInfo] An update is available, please enable Lua Allow Config and Lua Editing in the settings tab");
        else
            local new_version_content = http.Get(SCRIPT_FILE_ADDR);
            local old_script = file.Open(SCRIPT_FILE_NAME, "w");
            old_script:Write(new_version_content);
            old_script:Close();
            update_available = false;
            update_downloaded = true;
        end
    end

    if (update_downloaded) then
        draw.Color(255, 0, 0, 255);
        draw.Text(0, 0, "[PlayerInfo] An update has automatically been downloaded, please reload the player info script");
        return;
    end

    if (not version_check_done) then
        if (gui.GetValue("lua_allow_http") == false) then
            draw.Color(255, 0, 0, 255);
            draw.Text(0, 0, "[PlayerInfo] Please enable Lua HTTP Connections in your settings tab to use this script");
            return;
        end

        version_check_done = true;
        local version = http.Get(VERSION_FILE_ADDR);
        if (version ~= VERSION_NUMBER) then
            update_available = true;
        end
    end
end);

callbacks.Register("FireGameEvent", function(event)
    if (value_in_table(listen_to_events, event:GetName())) then
        update_players();
    end
end)

update_players();

-- Lightweight JSON Library for Lua
-- Credits: RXI
-- Link / Github: https://github.com/rxi/json.lua/blob/master/json.lua
-- Minified Version
json = { _version = "0.1.1" } local b; local c = { ["\\"] = "\\\\", ["\""] = "\\\"", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" } local d = { ["\\/"] = "/" } for e, f in pairs(c) do d[f] = e end; local function g(h) return c[h] or string.format("\\u%04x", h:byte()) end

; local function i(j) return "null" end

; local function k(j, l) local m = {} l = l or {} if l[j] then error("circular reference") end; l[j] = true; if j[1] ~= nil or next(j) == nil then local n = 0; for e in pairs(j) do if type(e) ~= "number" then error("invalid table: mixed or invalid key types") end; n = n + 1 end; if n ~= #j then error("invalid table: sparse array") end; for o, f in ipairs(j) do table.insert(m, b(f, l)) end; l[j] = nil; return "[" .. table.concat(m, ",") .. "]" else for e, f in pairs(j) do if type(e) ~= "string" then error("invalid table: mixed or invalid key types") end; table.insert(m, b(e, l) .. ":" .. b(f, l)) end; l[j] = nil; return "{" .. table.concat(m, ",") .. "}" end end

; local function p(j) return '"' .. j:gsub('[%z\1-\31\\"]', g) .. '"' end

; local function q(j) if j ~= j or j <= -math.huge or j >= math.huge then error("unexpected number value '" .. tostring(j) .. "'") end; return string.format("%.14g", j) end

; local r = { ["nil"] = i, ["table"] = k, ["string"] = p, ["number"] = q, ["boolean"] = tostring } b = function(j, l) local s = type(j) local t = r[s] if t then return t(j, l) end; error("unexpected type '" .. s .. "'") end; function json.encode(j) return b(j) end

; local u; local function v(...) local m = {} for o = 1, select("#", ...) do m[select(o, ...)] = true end; return m end

; local w = v(" ", "\t", "\r", "\n") local x = v(" ", "\t", "\r", "\n", "]", "}", ",") local y = v("\\", "/", '"', "b", "f", "n", "r", "t", "u") local z = v("true", "false", "null") local A = { ["true"] = true, ["false"] = false, ["null"] = nil } local function B(C, D, E, F) for o = D, #C do if E[C:sub(o, o)] ~= F then return o end end; return #C + 1 end

; local function G(C, D, H) local I = 1; local J = 1; for o = 1, D - 1 do J = J + 1; if C:sub(o, o) == "\n" then I = I + 1; J = 1 end end; error(string.format("%s at line %d col %d", H, I, J)) end

; local function K(n) local t = math.floor; if n <= 0x7f then return string.char(n) elseif n <= 0x7ff then return string.char(t(n / 64) + 192, n % 64 + 128) elseif n <= 0xffff then return string.char(t(n / 4096) + 224, t(n % 4096 / 64) + 128, n % 64 + 128) elseif n <= 0x10ffff then return string.char(t(n / 262144) + 240, t(n % 262144 / 4096) + 128, t(n % 4096 / 64) + 128, n % 64 + 128) end; error(string.format("invalid unicode codepoint '%x'", n)) end

; local function L(M) local N = tonumber(M:sub(3, 6), 16) local O = tonumber(M:sub(9, 12), 16) if O then return K((N - 0xd800) * 0x400 + O - 0xdc00 + 0x10000) else return K(N) end end

; local function P(C, o) local Q = false; local R = false; local S = false; local T; for U = o + 1, #C do local V = C:byte(U) if V < 32 then G(C, U, "control character in string") end; if T == 92 then if V == 117 then local W = C:sub(U + 1, U + 5) if not W:find("%x%x%x%x") then G(C, U, "invalid unicode escape in string") end; if W:find("^[dD][89aAbB]") then R = true else Q = true end else local h = string.char(V) if not y[h] then G(C, U, "invalid escape char '" .. h .. "' in string") end; S = true end; T = nil elseif V == 34 then local M = C:sub(o + 1, U - 1) if R then M = M:gsub("\\u[dD][89aAbB]..\\u....", L) end; if Q then M = M:gsub("\\u....", L) end; if S then M = M:gsub("\\.", d) end; return M, U + 1 else T = V end end; G(C, o, "expected closing quote for string") end

; local function X(C, o) local V = B(C, o, x) local M = C:sub(o, V - 1) local n = tonumber(M) if not n then G(C, o, "invalid number '" .. M .. "'") end; return n, V end

; local function Y(C, o) local V = B(C, o, x) local Z = C:sub(o, V - 1) if not z[Z] then G(C, o, "invalid literal '" .. Z .. "'") end; return A[Z], V end

; local function _(C, o) local m = {} local n = 1; o = o + 1; while 1 do local V; o = B(C, o, w, true) if C:sub(o, o) == "]" then o = o + 1; break end; V, o = u(C, o) m[n] = V; n = n + 1; o = B(C, o, w, true) local a0 = C:sub(o, o) o = o + 1; if a0 == "]" then break end; if a0 ~= "," then G(C, o, "expected ']' or ','") end end; return m, o end

; local function a1(C, o) local m = {} o = o + 1; while 1 do local a2, j; o = B(C, o, w, true) if C:sub(o, o) == "}" then o = o + 1; break end; if C:sub(o, o) ~= '"' then G(C, o, "expected string for key") end; a2, o = u(C, o) o = B(C, o, w, true) if C:sub(o, o) ~= ":" then G(C, o, "expected ':' after key") end; o = B(C, o + 1, w, true) j, o = u(C, o) m[a2] = j; o = B(C, o, w, true) local a0 = C:sub(o, o) o = o + 1; if a0 == "}" then break end; if a0 ~= "," then G(C, o, "expected '}' or ','") end end; return m, o end

; local a3 = { ['"'] = P, ["0"] = X, ["1"] = X, ["2"] = X, ["3"] = X, ["4"] = X, ["5"] = X, ["6"] = X, ["7"] = X, ["8"] = X, ["9"] = X, ["-"] = X, ["t"] = Y, ["f"] = Y, ["n"] = Y, ["["] = _, ["{"] = a1 } u = function(C, D) local a0 = C:sub(D, D) local t = a3[a0] if t then return t(C, D) end; G(C, D, "unexpected character '" .. a0 .. "'") end; function json.decode(C) if type(C) ~= "string" then error("expected argument of type string, got " .. type(C)) end; local m, D = u(C, B(C, 1, w, true)) D = B(C, D, w, true) if D <= #C then G(C, D, "trailing garbage") end; return m end

; return a