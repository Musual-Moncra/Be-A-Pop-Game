--[[
	Musual @ October 2024
	RunFramework
	
	Runs the client/server framework based on locations, takes in priorities.
]]

return function(Locations: {Instance})
	-- Lưu trữ dưới dạng mảng các object thay vì dictionary để dễ dàng sort
	local ModulesToRun = {} 

	for _, Location in Locations do
		for _, Item in Location:GetDescendants() do
			local Ancestor = Item:FindFirstAncestorWhichIsA("ModuleScript") 
			local IsValidModule = Item:IsA("ModuleScript") 
				and not (Ancestor and not Ancestor:GetAttribute("Folder"))
				and not Item:GetAttribute("Folder")

			if not IsValidModule then 
				continue 
			end

			local Priority = Item:GetAttribute("Priority") or 999

			-- Đẩy thẳng vào mảng cùng với thông tin Priority
			table.insert(ModulesToRun, {
				Module = Item,
				Priority = Priority
			})
		end
	end

	-- Sắp xếp mảng dựa trên Priority (từ bé đến lớn)
	table.sort(ModulesToRun, function(a, b)
		return a.Priority < b.Priority
	end)

	-- Chạy các module theo thứ tự đã được sắp xếp chuẩn xác
	for _, Data in ipairs(ModulesToRun) do
		task.defer(function()
			local Contents = require(Data.Module)
			if typeof(Contents) == "function" then
				task.spawn(Contents)
			end
		end)
	end
end