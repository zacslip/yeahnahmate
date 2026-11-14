-- luacheck settings (https://github.com/lunarmodules/luacheck). Run by the Tests workflow on every push
-- and pull request: luacheck YeahNahMate
--
-- What it's for here: catching a global written by mistake (on WoW Forever a stray global can taint
-- Blizzard's UI), unused or shadowed locals, and typos in names. The game's API is huge and changes,
-- so reading globals isn't checked (113); tests/test_rules.lua covers which game functions we may use.
std = "lua51"
max_line_length = 180
unused_args = false             -- handlers take (msg, from, channel, isSelf) whether they use them or not
exclude_files = { "YeahNahMate/libs/**" }
ignore = {
    "113",          -- reading a global the config doesn't list: the WoW API
    "211/ADDON",    -- every file starts with `local ADDON, ns = ...`
}
files["YeahNahMate/Strings.lua"] = { max_line_length = false }   -- one line per text
-- The only globals the addon may write.
globals = {
    "YeahNahMateDB",                                        -- saved variables (.toc)
    "SLASH_YEAHNAHMATE1", "SLASH_YEAHNAHMATE2", "SlashCmdList",
    "BINDING_HEADER_YEAHNAHMATE", "BINDING_NAME_YEAHNAHMATE_VOICE",   -- Bindings.xml
    "YeahNahMate_VoiceToggle",                              -- the key binding's handler
    "YeahNahMate_OnAddonCompartmentClick",                  -- .toc AddonCompartmentFunc
}
