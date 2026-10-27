--!strict

--[[
	Primitives
	Small element builders shared by every UI component so the chunky cartoon look
	(outlined text, gradients, strokes, rounded corners) is defined once.

	API:
		Primitives.corner(radius) -> UICorner element (radius in design pixels, or "Round")
		Primitives.stroke(color, thickness, transparency?) -> UIStroke element (border)
		Primitives.gradient(top, bottom) -> vertical UIGradient element
		Primitives.padding(all) / Primitives.paddingXY(x, y) -> UIPadding element
		Primitives.list(direction, gap, hAlign?, vAlign?) -> UIListLayout element
		Primitives.displayFont() / Primitives.bodyFont() -> Font
		Primitives.swatch(name) -> UIConfig swatch table (falls back to Grey)
		Primitives.text(props) -> outlined TextLabel element
			props: Text, TextSize, Color?, Font? ("Display" | "Body"), Size?, Position?, AnchorPoint?,
			       XAlign?, YAlign?, Stroke? (false to disable), StrokeSize?, LayoutOrder?, Wrapped?,
			       RichText?, Transparency?, ZIndex?, AutomaticSize?, NoTruncate?, StrokeColor?, Fit?
			Fit = true shrinks the text to fit its box (never larger than TextSize, never smaller
			than UIConfig.TextSizes.Min), so a label can never spill out of a narrow button or card.
		Primitives.gloss(radius) -> soft white shine for the top of a button or bar face; fades out
			downward and is never taller than Shape.GlossMaxHeight, so big cards get a thin highlight
			instead of a white slab
		Primitives.scroll(props, children) -> vertical ScrollingFrame element that keeps its scrollbar
			beside the content instead of over it
			props: Size?, Position?, LayoutOrder?, Thickness? (design pixels)

	Dependencies: React, UIConfig
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIConfig = require(ReplicatedStorage.Modules.Config.UIConfig)

local e = React.createElement
local Palette = UIConfig.Palette
local Shape = UIConfig.Shape

local Primitives = {}

local displayFont = Font.new(UIConfig.Fonts.Display, UIConfig.Fonts.DisplayWeight)
local bodyFont = Font.new(UIConfig.Fonts.Body, UIConfig.Fonts.BodyWeight)

function Primitives.displayFont(): Font
	return displayFont
end

function Primitives.bodyFont(): Font
	return bodyFont
end

function Primitives.swatch(name: string?): any
	local swatches: any = UIConfig.Swatches
	return swatches[name or ""] or swatches.Grey
end

function Primitives.corner(radius: number | string)
	if radius == "Round" then
		return e("UICorner", { CornerRadius = UDim.new(1, 0) })
	end
	return e("UICorner", { CornerRadius = UDim.new(0, radius :: number) })
end

function Primitives.stroke(color: Color3, thickness: number, transparency: number?)
	return e("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		LineJoinMode = Enum.LineJoinMode.Round,
		Thickness = thickness,
		Transparency = transparency or 0,
	})
end

function Primitives.gradient(top: Color3, bottom: Color3)
	return e("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = Shape.GradientRotation,
	})
end

function Primitives.padding(all: number)
	return e("UIPadding", {
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		PaddingTop = UDim.new(0, all),
	})
end

function Primitives.paddingXY(x: number, y: number)
	return e("UIPadding", {
		PaddingBottom = UDim.new(0, y),
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y),
	})
end

function Primitives.list(
	direction: Enum.FillDirection,
	gap: number,
	hAlign: Enum.HorizontalAlignment?,
	vAlign: Enum.VerticalAlignment?
)
	return e("UIListLayout", {
		FillDirection = direction,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
	})
end

function Primitives.text(props: any)
	local children = {}
	if props.Fit then
		children.Fit = e("UITextSizeConstraint", {
			MaxTextSize = props.TextSize,
			MinTextSize = math.min(UIConfig.TextSizes.Min, props.TextSize),
		})
	end
	if props.Stroke ~= false then
		children.Stroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = props.StrokeColor or Palette.Ink,
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = props.StrokeSize or Shape.TextStroke,
			Transparency = props.Transparency or 0,
		})
	end
	return e("TextLabel", {
		AnchorPoint = props.AnchorPoint,
		AutomaticSize = props.AutomaticSize,
		BackgroundTransparency = 1,
		FontFace = if props.Font == "Body" then bodyFont else displayFont,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		RichText = props.RichText,
		Size = props.Size or UDim2.fromScale(1, 1),
		Text = props.Text or "",
		TextColor3 = props.Color or Palette.Text,
		TextScaled = props.Fit == true,
		TextSize = props.TextSize,
		TextTransparency = props.Transparency or 0,
		TextTruncate = if props.Wrapped or props.NoTruncate then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		TextWrapped = props.Wrapped == true,
		TextXAlignment = props.XAlign or Enum.TextXAlignment.Center,
		TextYAlignment = props.YAlign or Enum.TextYAlignment.Center,
		ZIndex = props.ZIndex,
	}, children)
end

function Primitives.gloss(radius: number | string)
	return e("Frame", {
		BackgroundColor3 = Palette.Text,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(Shape.Stroke * 2, Shape.Stroke),
		Size = UDim2.new(1, -Shape.Stroke * 4, Shape.GlossHeight, 0),
	}, {
		Corner = Primitives.corner(radius),
		Limit = e("UISizeConstraint", { MaxSize = Vector2.new(math.huge, Shape.GlossMaxHeight) }),
		Fade = e("UIGradient", {
			Rotation = Shape.GradientRotation,
			Transparency = NumberSequence.new(Shape.GlossTransparency, 1),
		}),
	})
end

function Primitives.scroll(props: any, children: any)
	return e("ScrollingFrame", {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		ScrollBarImageColor3 = Palette.PanelRim,
		ScrollBarThickness = props.Thickness or Shape.ScrollBar,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = props.Size or UDim2.fromScale(1, 1),
		VerticalScrollBarInset = Enum.ScrollBarInset.Always,
	}, children)
end

return Primitives
