--[[

MIT License

Copyright (c) 2025 usfbih8u

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]

local micro  = import("micro")
local buffer = import("micro/buffer")
local util   = import("micro/util")

---Creates and sets the buffer for the tooltip.
---@param data string The content of the Buffer.
---@param name string The name of the Buffer.
---@param opts table A list of options and values for the Buffer.
---@return Buffer The Buffer created.
local function SetTooltipBuffer(data, name, opts)
    local buf = buffer.NewBuffer(data, name)
    buf.Type.Scratch = true
    buf.Type.Readonly = true
    if opts then for k,v in pairs(opts) do buf:SetOptionNative(k, v) end end
    return buf
end

---Obtains the index of the BufPane `bp` in the tree node.
---@param bp BufPane The BufPane for which to obtain the index.
---@return number The index of the BufPane in the tree node.
local function GetSplitIndex(bp)
    assert(bp)
    return bp:Tab():GetPane(bp:ID())
end

---Takes a snapshot of the panes' view opened in a tab, ignoring the tooltip.
---@param tab Tab Tab from which to extract the pane views.
---@param tooltipIdx integer|nil The split index for the tooltip.
---@return table An array containing the view reference and value for each pane.
local function TabLayoutSnapshot(tab, tooltipIdx)
    assert(tab)
    local snapshot = {}
    local panes = tab.Panes
    for i = 1, #panes do
        if not tooltipIdx or i ~= tooltipIdx + 1 then -- ignore tooltipIdx(+1 lua index)
            local paneView = panes[i]:GetView()
            table.insert(snapshot,{ view = paneView, viewValue = -paneView })
        end
    end
    return snapshot
end

---Recovers the views from a snapshot.
---@param snapshot table The snapshot of a Tab.
local function TabLayoutRecover(snapshot)
    assert(snapshot)
    for _, pane in ipairs(snapshot) do
        --NOTE you can't assign directly a value to a reference
        pane.view.X = pane.viewValue.X
        pane.view.Y = pane.viewValue.Y
        pane.view.Width = pane.viewValue.Width
        pane.view.Height = pane.viewValue.Height
        pane.view.StartLine = pane.viewValue.StartLine
        pane.view.StartCol = pane.viewValue.StartCol
    end
end

---@class Tooltip
---@field name string The name of the tooltip.
---@field origin BufPane The BufPane that generates the tooltip.
---@field bp BufPane The BufPane associated with the tooltip.
local Tooltip = {}
Tooltip.__index = Tooltip

---Creates a tooltip named `name` with `content` as the value of the buffer at
---coordinates {x,y} with a size of {width, height}.
---@param name string The name of the Buffer.
---@param content string The content of the Buffer.
---@param x number The X coordinate to draw the left top corner of the Buffer.
---@param y number The Y coordinate to draw the left top corner of the Buffer.
---@param width number The width of the buffer display.
---@param height number The height of the buffer display.
---@param opts table Options for the Buffer.
---@return Tooltip The created tooltip.
function Tooltip.new(name, content, x, y, width, height, opts)
    assert(type(name) == "string", "`nil` used to indicate IsClosing.")
    local self = setmetatable({}, Tooltip)

    self.name = name
    self.origin = micro.CurPane()
    self.bp = nil

    local snapshot = TabLayoutSnapshot(self.origin:Tab(), nil)

    local buf = SetTooltipBuffer(content, name, opts)
    self.origin:HSplitIndex(buf, true)
    self.bp = micro.CurPane()
    self.bp:Resize(width, height)
    self:DrawAt(x, y)

    TabLayoutRecover(snapshot)

    return self
end

---Replaces the content of the tooltip's Buffer with `content`.
---@param content string The content of the Buffer.
---@return Tooltip
function Tooltip:Buffer(content)
    local buf = self.bp.Buf
    local endi = buf:End()
    buf.EventHandler:Remove(buf:Start(), endi)
    buf.EventHandler:Insert(endi, content)
    return self
end

---Moves the Cursor to the location `loc`.
---@param loc Loc The location where the cursor should be positioned.
---@return Tooltip
function Tooltip:SetCursor(loc)
    self.bp:GotoLoc(loc)
    return self
end

---Centers the Buffer at the cursor location.
---@return Tooltip
function Tooltip:Center()
    self.bp:Center()
    return self
end

---Draws the tooltip at the (X,Y) location (top left corner) on the screen.
---@param x number The global X coordinate for the top left corner of the tooltip.
---@param y number The global Y coordinate for the top left corner of the tooltip.
---@return Tooltip
function Tooltip:DrawAt(x, y)
    local tooltipView = self.bp:GetView()
    tooltipView.X, tooltipView.Y = x, y
    return self
end

---Resizes the tooltip to the specified width and height.
---If nil is passed that variable is set to the current value in the tooltip.
---@param width number The tooltip's view width.
---@param height number The tooltip's view height.
---@return Tooltip
function Tooltip:Resize(width, height)
    local snapshot = TabLayoutSnapshot(self.origin:Tab(), GetSplitIndex(self.bp))

    local tooltipView = self.bp:GetView()
    if not width then width = tooltipView.Width end
    if not height then height = tooltipView.Height end
    self.bp:Resize(width, height)

    TabLayoutRecover(snapshot)
    return self
end

---Closes the tooltip and handles the layout as well.
---@return nil Used primarily to set the tooltip to `nil`
function Tooltip:Close()
    if self:IsClosing() then return nil end -- we entered close previously

    local snapshot = TabLayoutSnapshot(self.origin:Tab(), GetSplitIndex(self.bp))

    self.name = nil -- NOTE indicate we are closing
    assert(self.bp)
    self.bp:Quit()
    local originIdx = GetSplitIndex(self.origin)
    self.origin:Tab():SetActive(originIdx)

    TabLayoutRecover(snapshot)

    return nil
end

---Indicates whether the tooltip is already closing. To inform callbacks that we
---are closing the tooltip, `name` is set to nil.
---@return boolean Returns true if the tooltip is closing; otherwise, returns false.
function Tooltip:IsClosing() return self.name == nil end

---Indicates whether the BufPane `bp` passed is the tooltip's origin.
---@param bp BufPane The BufPane to check.
---@return boolean Returns true if `bp` is the tooltip's origin; otherwise, returns false.
function Tooltip:IsOrigin(bp) return bp and bp == self.origin end

---Indicates whether the BufPane `bp` passed is the tooltip itself.
---@param bp BufPane The BufPane to check.
---@return boolean Returns true if bp is the tooltip; otherwise, returns false.
function Tooltip:IsTooltip(bp) return bp and bp == self.bp end

---Returns the screen size, **ONLY** for the zone where the BufPanes are created.
---@return { Width: number, Height: number } The screen width and height.
local function ScreenSize()
    local infoBarView = micro.InfoBar():GetView()
    assert(infoBarView)
    local tabWindowHeight = #micro.Tabs().List == 1 and 0 or 1

    return {
        Width = infoBarView.Width,
        Height = infoBarView.Y - tabWindowHeight - 1 -- 1 for statusline
    }
end

---Gets the corresponding Screen location for a Buffer location.
---@param bp BufPane The BufPane from which the location `loc` is derived.
---@param loc Loc The Buffer location.
---@return Loc The location in Screen coordinates.
local function ScreenLocFromBufLoc(bp, loc)
    local vloc = bp:VLocFromLoc(loc)
    local ix, iy = vloc.VisualX, vloc.Line + vloc.Row
    local bufView = bp:BufView() -- rename to bufView

    local numExtraLines = 0
    if bp.Buf.Settings["softwrap"] then
        -- TODO is there a better way to calculate all this ??
        local startLine = bufView.StartLine.Line
        -- take into account when the first line is shown partially.
        numExtraLines = numExtraLines - bufView.StartLine.Row
        for l = startLine, vloc.Line - 1 do
            local line = bp.Buf:Line(l)
            local lineEndX = util.CharacterCountInString(line)
            local sloc = bp:SLocFromLoc(buffer.Loc(lineEndX, l))
            numExtraLines = numExtraLines + sloc.Row
        end
    end

    return {
        X = bufView.X - bufView.StartCol + ix,
        Y = bufView.Y - bufView.StartLine.Line + numExtraLines + iy
    }
end

return {
    Tooltip = Tooltip,
    ScreenSize = ScreenSize,
    ScreenLocFromBufLoc = ScreenLocFromBufLoc,
}