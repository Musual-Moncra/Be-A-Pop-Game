# Hướng dẫn nội dung: Thiết kế, Cân bằng, Animator, Âm thanh

Làm được toàn bộ mà không cần sửa logic game. Tài liệu này chỉ cho bạn **sửa ở đâu**.
Khi nhấn Play trong Studio, Output in dòng `[ContentCheck]`: có `problems` > 0 thì đọc cảnh báo, nó nói chính xác thiếu gì.

## 1. Lưu asset ở đâu

| Loại | Chỗ lưu | Ghi chú |
|---|---|---|
| Animation, Texture (chỉ là một id) | `src/modules/Config/AssetConfig.lua` | Dán `rbxassetid://...` |
| Âm thanh hiệu ứng | `ReplicatedStorage.Assets.Sounds` | Instance `Sound`; âm lượng và pitch ở `SoundConfig` |
| Model, mesh client cần thấy | `ReplicatedStorage.Assets.Models` | Instance |
| Effect (particle, beam) | `ReplicatedStorage.Assets.Effects` | Instance |
| **Map chơi được** | `ServerStorage.Assets.Maps` | Instance, được clone cho từng phòng |
| Model chỉ server dùng | `ServerStorage.Assets.Models` | Instance |
| Lobby | `Workspace.Lobby` | Không nằm trong Rojo, luôn được giữ |

**Rojo không xóa** thứ bạn tự tạo trong các thư mục `Assets` ở trên. Thư mục con **mới tạo trong Studio** cũng được giữ. Instance chỉ có trong Studio được lưu cùng place, nên **hãy Save/Publish place sau khi sửa**.

## 2. Thêm hoặc sửa map

1. Đặt Model vào `ServerStorage.Assets.Maps`. Tên Model trùng `ModelName` trong `MapConfig`.
2. Cấu trúc bắt buộc trong Model:
   - `Props`: mỗi Model con có attribute `ObjectType`, giá trị là một khóa trong `ObjectConfig`.
   - `NPCs`: Model NPC, tên trùng `name` trong `RunConfig.NpcPatrols[<id map>]`.
   - `PlayArea`: Part đánh dấu vùng chơi (dùng để sinh perk và tính % map).
3. Thêm mục map trong `MapConfig` (`Spawn` là vị trí **trong lúc map đang đặt ở tọa độ gốc của nó**). Game tự cộng độ lệch khi clone cho từng phòng, nên **không di chuyển map sau khi đã ghi tọa độ** `Spawn` và patrol; nếu di chuyển phải cập nhật cả hai.
4. Muốn có trứng pet hoặc nhạc riêng: thêm vào `PetConfig` và `SoundConfig.Music.Maps`.

## 3. Animator

- Đi bộ của cục poop: `AssetConfig.Animations.Walk`.
- Tốc độ phát, thời gian fade, ngưỡng bắt đầu đi: `CharacterConfig`.
- Animation phải được publish dưới cùng tài khoản/group sở hữu game, nếu không sẽ không phát.
- Chuyển động của vật trong map (quạt, cây, đu quay): `MapAnimConfig`.

## 4. Cân bằng

| Muốn chỉnh | File (`src/modules/Config/`) |
|---|---|
| Điểm, quy đổi coins/XP, cấp độ | `GameConfig` |
| Giá mở map, hệ số thưởng | `MapConfig` |
| Chế độ chơi, thời lượng, mục tiêu | `ModeConfig` |
| Giá và giá trị nâng cấp | `UpgradeConfig` |
| Điểm và độ bền của từng loại vật | `ObjectConfig` |
| NPC: tầm nhìn, tốc độ đuổi, hình phạt | `NpcConfig` |
| NPC: tuyến tuần tra | `RunConfig.NpcPatrols` |
| Perk, thuốc | `PowerupConfig`, `PotionConfig` |
| Pet, trứng, độ hiếm | `PetConfig` |
| Skin, trail, crate | `CosmeticConfig` |
| Rebirth, daily, event, quest | `RebirthConfig`, `DailyRewardConfig`, `EventConfig`, `QuestConfig` |
| Phòng chơi: số người, đếm ngược, luật sẵn sàng | `RoomConfig` |
| Robux, Gamepass, Product | `MonetizationConfig` |

Mọi file Config đều có dạng `return { TenTruong = giaTri }` và giải thích từng trường, kèm đơn vị, ở đầu file.

**Không đổi tên hoặc xóa** khóa trong `DataConfig.Template`, vì sẽ làm hỏng dữ liệu người chơi đã lưu. Chỉ thêm khóa mới.

## 5. Giao diện

Màu, kích thước, chữ: `UIConfig`, `LobbyUIConfig`, `RunUIConfig`. Kích thước tính bằng "design pixel" và tự co giãn theo màn hình.

## 6. Âm thanh

- Hiệu ứng: tạo `Sound` trong `ReplicatedStorage.Assets.Sounds`, rồi đặt tên đó vào `Asset` của khóa tương ứng trong `SoundConfig.Sfx`.
- Nhạc nền: dán id vào `SoundConfig.Music`.

## 7. Trước khi phát hành

1. Điền toàn bộ `Id` trong `MonetizationConfig` (hiện là 0).
2. Điền nhạc trong `SoundConfig.Music`.
3. Mở Studio, Play, xác nhận `[ContentCheck] 0 problems`.
4. **Publish place** để giữ Lobby, Park và mọi instance chỉ có trong Studio.
