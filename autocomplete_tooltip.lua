VERSION = "0.0.5"

local micro  = import("micro")
local config = import("micro/config")
local buffer = import("micro/buffer")
local util   = import("micro/util")
local strings = import("strings")

local plugName = "autocomplete_tooltip"
---@module 'tooltip'
local TooltipModule = nil

local function log(...)
    -- micro.Log("["..plugName.."]", unpack(arg))
end

--NOTE: Top-level call to load the colorscheme without errors.
config.AddRuntimeFile(plugName, config.RTColorscheme, "colorschemes/autocomplete-tooltip.micro")

function init()
    local plugDirPath = config.ConfigDir .. "/plug/?.lua;"
    if string.find(package.path, plugDirPath, 1, true) == nil then
        package.path = plugDirPath .. package.path
    end
    config.AddRuntimeFile(plugName, config.RTSyntax, "syntax/autocomplete-tooltip.yaml")

    local ok, module = pcall(require, 'micro-autocomplete-tooltip.tooltip')
    if ok then -- Cloned as micro-autocomplete-tooltip
        TooltipModule = module
    else -- Downloaded from Micro as autocomplete_tooltip
        TooltipModule = require(plugName .. ".tooltip")
    end
end

---@class (exact) Autocomplete Keeps the state of the plugin.
---@field public tooltip Tooltip | nil The only instance of the tooltip.
---@field protected name string The name of the tooltip's Buffer.
---@field public freshCreated boolean Indicates if the tooltip was just created, allowing us to ignore calls to `AutocompleteTooltip()`. When creating the tooltip, events are generated (sometimes two, other times only one).
local Autocomplete = {
    tooltip = nil,
    name = "Autocomplete",
    freshCreated = false,
}

---Closes and resets the tooltip.
local function AutocompleteClose()
    Autocomplete.tooltip = Autocomplete.tooltip:Close()
    Autocomplete.freshCreated = false
end

---Creates a string containing a list of suggestions and returns the maximum
---values for height and width.
---@param bp BufPane|InfoPane The BufPane or InfoPane from which to extract the suggestions.
---@return string, number, number The list of suggestion, maximum width, and maximum height.
local function GetSuggestionsData(bp)
    local sugNum = #bp.Buf.Suggestions
    local maxWidth, maxHeight = 0, sugNum + 1 --+1 needed for status bar
    local curSugIdx = bp.Buf.CurSuggestion + 1 -- +1 lua index

    local prefix = config.GetGlobalOption(plugName..".Prefix") or ""
    assert(type(prefix) == "string")
    local prefixLen = util.CharacterCountInString(prefix)
    local prefixPadding = prefix == "" and "" or string.rep(" ", prefixLen)

    local data = {}
    for i = 1, sugNum do
        local sug = string.format("%s%s", prefixPadding, bp.Buf.Suggestions[i])
        local sugLen = util.CharacterCountInString(sug)
        if maxWidth < sugLen then maxWidth = sugLen end
        table.insert(data, { content = sug, length = sugLen})
    end
    maxWidth = maxWidth + 1 -- space for "\u200B" when sugLen is max

    --NOTE trailing "\u200B" is used to mark the current suggestion with syntax
    data[curSugIdx].content = string.format(
        "%s%s%s",
        prefix,
        prefix == "" and data[curSugIdx].content or string.sub(data[curSugIdx].content, prefixLen + 1),
        string.char(0xE2, 0x80, 0x8B) -- "\u200B"
    )

    local padded = {}
    for _, d in ipairs(data) do
        table.insert(padded, d.content .. string.rep(" ", maxWidth - d.length))
    end

    return table.concat(padded, "\n"), maxWidth, maxHeight
end

---Calculates the position (x, y) and size (width, height) for creating the tooltip.
---@param bp BufPane The BufPane to fit around the provided location `loc`.
---@param loc Loc The location to fit around.
---@param maxWidth number The maximum width that the text in the tooltip can occupy.
---@param maxHeight number The maximum height that the text in the tooltip can occupy.
---@return number, number, number, number The x, y, width, and height.
local function FitAroundLocation(bp, loc, maxWidth, maxHeight)
    local ScreenLoc = TooltipModule.ScreenLocFromBufLoc(bp, loc)
    local bufView = bp:BufView()
    local x = bp:VLocFromLoc(loc).VisualX + maxWidth < bufView.Width
            and ScreenLoc.X
            or bufView.X + bufView.Width - maxWidth
    local y = ScreenLoc.Y + 1 --+1 under cursor

    local curCompletion = bp.Buf.Completions[bp.Buf.CurSuggestion + 1]
    local curCompletionExtraLines = strings.Count(curCompletion, "\n")

    local spaceAbove = ScreenLoc.Y - bufView.Y - curCompletionExtraLines
    local spaceBelow = bufView.Height - spaceAbove - 1 -- -1: statusline

    local width, height = maxWidth, maxHeight
    if spaceBelow < maxHeight then
        log("does NOT fit below")
        if spaceAbove < maxHeight then
            log("does NOT fit above")
            --NOTE if it "has to fit" then the scrollbar appears; increment width by 1.
            width = maxWidth + 1
            if spaceBelow > spaceAbove then
                log("fit below")
                height = spaceBelow
            else
                log("fit above")
                y, height = bufView.Y, spaceAbove
            end
        else
            log("does fit above")
            y = y - maxHeight - curCompletionExtraLines - 1 -- -1 to correct the "under the cursor"
        end
    end
    log("y", y, "height", height)

    return x, y, width, height
end

---The main function for the plugin is called **only** by the plugin itself from
---the `onAnyEvent` callback.
---@param bp BufPane The BufPane for normal buffers.
---@param infobar InfoPane|nil The micro.InfoBar().
--`NOTE` uses `infobar` to detect where we are autocompleting
local function AutocompleteTooltip(bp, infobar)
    if Autocomplete.freshCreated then
        Autocomplete.freshCreated = false
        return
    end

    ---@type boolean
    local onInfoBar = infobar ~= nil
    if onInfoBar then assert(bp and infobar and infobar.Buf.HasSuggestions)
    else assert(bp and bp.Buf.HasSuggestions) end

    local suggestionsFrom = onInfoBar and infobar or bp
    local dataStr, maxWidth, maxHeight = GetSuggestionsData(suggestionsFrom)

    local x, y, width, height
    if onInfoBar then
        local infoBufView = infobar:BufView() -- InfoBar's view never changes
        width = maxWidth < infoBufView.Width and maxWidth or infoBufView.Width

        local spaceAboveInfobar = infoBufView.Y - 1 -- -1 for statusline
        if maxHeight < spaceAboveInfobar then
            y, height = infoBufView.Y - maxHeight, maxHeight
        else -- NOTE: will create scrollbar
            width = width + 1 -- space for scrollbar
            local numTabs = #micro.Tabs().List
            if numTabs > 1 then y, height = 1, spaceAboveInfobar - 1
            else                y, height = 0, spaceAboveInfobar end
        end

        -- NOTE: Here, there shouldn't be a completion with a newline...
        local curSuggestion = infobar.Buf.Suggestions[infobar.Buf.CurSuggestion + 1]
        x = infobar.Cursor.Loc.X - util.CharacterCountInString(curSuggestion) + string.len("> ")

    else --not onInfoBar
        -- NOTE: we catch the event after the completion is inserted, so the cursor
        -- is positioned after the current completion.
        local _, wordStart = bp.Buf:GetWord()
        local loc = buffer.Loc(wordStart, bp.Cursor.Loc.Y)
        x, y, width, height = FitAroundLocation(bp, loc, maxWidth, maxHeight)
    end

    -- NOTE: GetPane(splitid) returns the index of the current tab in the tree of Nodes
    local active = bp:Tab():GetPane(bp:ID())
    if not Autocomplete.tooltip then
        Autocomplete.tooltip = TooltipModule.Tooltip.new(
            Autocomplete.name, dataStr,
            x, y, width, height, {
                ["ruler"] = false,
                ["filetype"] = "autocomplete",
                ["softwrap"] = false,
                ["eofnewline"] = false,
                ["diffgutter"] = false,
                ["statusline"] = false,
                ["colorcolumn"] = 0,
                ["hltrailingws"] = false,
        })
        Autocomplete.freshCreated = true

    else
        Autocomplete.tooltip:Buffer(dataStr)
                            :Resize(width, height)
                            :DrawAt(x, y)
                            :SetCursor(buffer.Loc(0, suggestionsFrom.Buf.CurSuggestion))
                            :Center()
    end

    bp:Tab():SetActive(active)
end

---Closes the tooltip  `onAnyEvent` if there are not suggestions for the current buffer,
---or continues cycling through the suggestions. This is **the entry point for the plugin**.
function onAnyEvent()
    local bp = micro.CurPane()
    if not bp then return end
    local infobar = micro.InfoBar()
    local anySuggestion = bp.Buf.HasSuggestions or infobar.Buf.HasSuggestions

    if Autocomplete.tooltip and not anySuggestion then
        AutocompleteClose()
    elseif infobar.Buf.HasSuggestions then AutocompleteTooltip(bp, infobar)
    elseif bp.Buf.HasSuggestions      then AutocompleteTooltip(bp, nil) end
end

---Cycles back through the suggestions if the tooltip is open.
---@param bp BufPane The current BufPane.
function preCursorUp(bp)
    if config.GetGlobalOption(plugName..".EnableCursorUpDown") ~= nil
    and Autocomplete.tooltip
    then
        bp.Buf:CycleAutocomplete(false)
        return false
    end
    return true
end

---Cycle through the suggestions if the tooltip is open.
---@param bp BufPane The current BufPane.
function preCursorDown(bp)
    if config.GetGlobalOption(plugName..".EnableCursorUpDown") ~= nil
    and Autocomplete.tooltip
    then
        bp.Buf:CycleAutocomplete(true)
        return false
    end
    return true
end

---If the tooltip exists (is open), close it.
---@return true # always returns true; you decide whether to propagate it upstream.
local function IfTooltipCloseIt()
    if Autocomplete.tooltip then AutocompleteClose() end
    return true
end

---Close the tooltip before adding or changing a Tab. It seems that we can not
---catch them with `onAnyEvent`.

function preAddTab(_)     return IfTooltipCloseIt() end
function prePreviousTab() return IfTooltipCloseIt() end
function preNextTab()     return IfTooltipCloseIt() end

-- Close the tooltip before new BufPane is created (on buffer open).
function onBufferOpen(_) IfTooltipCloseIt() end
