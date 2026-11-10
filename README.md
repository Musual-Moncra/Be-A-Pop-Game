# Be A Poop

Game Roblox thể loại Arcade / Simulator, viết bằng Luau với Rojo, React-lua, Packet và ProfileStore.

> Cập nhật: **10/11/2026** · Nhánh: `release/prep`
>
> Tài liệu thiết kế (GDD, backlog) có NDA nên không nằm trong repo này. README chỉ mô tả kỹ thuật và kết quả kiểm thử.

---

## 1. Trạng thái phát hành

**Gần sẵn sàng.** Vòng chơi đầy đủ (lobby → PLAY → bôi bẩn → 100% → rơi pet → kết quả) đã chạy trong Studio. Thiết kế Phase 7: `.coordination/PHASE7/DESIGN.md`. Việc của team ngoài code nằm trong Tasko, goal "BAP Launch – Phase 7".

### Bắt buộc trước khi phát hành

| # | Việc | Người làm |
|---|---|---|
| 1 | Save/Publish place từ Studio | Lead |
| 2 | Playtest tay: cảm giác điều khiển, combo, NPC hoảng loạn, revive 3 mức, Stain Bomb | Lead + QA |
| 3 | Điền Id Gamepass/Developer Product (`MonetizationConfig`, `PotionConfig`). `[ContentCheck]` liệt kê các Id còn 0 | Lead |
| 4 | Model pet đặt tên theo Id pet (`[ContentCheck]` liệt kê pet thiếu model) | Builder |
| 5 | Thu nhỏ map Park/Mall theo DESIGN §0 | Builder |
| 6 | Asset âm thanh: Combo, Milestone, PetReveal, PetPoop, NpcSqueal, LevelUp | Intern |
| 7 | Texture splat chính thức thay id tạm `AssetConfig.Textures.Splat` | Art |
| 8 | Test điện thoại/máy bảng và nhiều người | QA |

### Lỗi đã biết

- `rbxassetid://203785492` báo sai loại asset khi Play, chưa rõ nguồn (Tasko #28).
- MeshPart do Rojo sync không có dữ liệu mesh. `CharacterMeshService` nạp lại mesh nhân vật khi server chạy; model khác chứa MeshPart nên để Studio quản lý.
- Camera bị kéo sát khi poop áp tường (va chạm camera).

---

## 2. Thay đổi ở đợt này (Phase 7)

| Hạng mục | Kết quả |
|---|---|
| Pet | Bỏ egg. Pet rơi mỗi lần bẩn 100% map, 1 ô mặc định (+3 gamepass), Evolve 5 con giống nhau, pet ỉa trong lượt chơi tạo Stinky Stack và gems |
| Chỉ số hôi | `Stink` nhân toàn bộ coins cuối lượt, hiện ở lobby, HUD và kết quả |
| Pet Index | Mỗi map một bộ sưu tập; đủ bộ nhận pet độc quyền + 100 gems |
| Map | Park là map 1, Mall map 2, Kitchen/Hotel "Coming soon"; mở map sau khi map trước đạt 100% |
| Bỏ | Egg shop, trail cosmetic, cửa sổ Stats |
| Chơi | Nút PLAY một chạm cho từng map; "Play with friends" mở luồng phòng |
| Cảm giác | Combo x1–x2, số điểm bay lên, banner 25/50/75/100%, rung camera, squash & stretch, vết splat xoay ngẫu nhiên, nhân vật quay theo hướng di chuyển, camera giãn theo kích thước |
| NPC | Lăn vào NPC: hoảng loạn, "!", rơi 3 coin; đi tuần bằng pathfinding |
| Kiếm tiền | Revive 3 mức (4/9/13 R$), potion bán Robux, Stain Bomb theo kích cỡ, Newbie Pack một lần |
| Người mới | Hướng dẫn 5 bước, có Skip |
| Lỗi lớn đã sửa | Nhân vật poop vô hình (mesh không load) |

---

## 3. Dành cho team không lập trình

Đọc **[docs/CONTENT_GUIDE.md](docs/CONTENT_GUIDE.md)**: lưu asset ở đâu, thêm map, thay animation, chỉnh cân bằng, giao diện, âm thanh.

Khi Play trong Studio, Output in `[ContentCheck] N problems, M notes`. `problems` phải bằng 0.

---

## 4. Báo cáo kiểm thử

### Đã playtest trong Studio (một client)

| Ca | Kết quả |
|---|---|
| Mở cửa sổ từ MENU > PLAY, các tab Create và Browse | Đạt |
| Tạo phòng bằng giao diện, màn hình phòng, START | Đạt |
| Trạng thái `Waiting` > `Countdown` > `Running` | Đạt |
| Clone map đúng slot, nhân vật đáp trên sàn, không rơi | Đạt: Kitchen, Mall, Park |
| Di chuyển, vết bẩn, điểm, thanh % map | Đạt |
| NPC tuần tra đúng vị trí trong bản clone, có vùng nhìn | Đạt |
| NPC bắt người chơi, trừ thời gian, hiện thông báo | Đạt |
| Hitbox: đầu thân chạm NPC thì bị bắt, đứng ngang cách 7 studs thì không | Đạt |
| Mega Size: thân 11 > 22 > 11 studs, cả khi hết giờ giữa run và khi về lobby | Đạt |
| Chạy liền mạch sàn > tủ > tường > trần > tường > sàn ở Kitchen, không kẹt | Đạt |
| Nhảy | Đạt |
| Hết giờ: màn hình kết quả, thưởng, về lobby | Đạt |
| Sau khi hết phòng: map clone, vùng nhìn và thư mục perk được dọn, map gốc không đổi | Đạt |
| Rời phòng khi đang chơi | Đạt (qua packet) |
| Chạm Portal mở cửa sổ phòng, không vào thẳng map | Đạt |
| HUD đúng vị trí ở độ phân giải đang test | Đạt |
| `[ContentCheck]` | 0 problems |

### Chưa kiểm thử được

| Ca | Lý do |
|---|---|
| **Nhiều người chơi thật**: vào phòng, ready, kick, mời, chỉ bạn bè, đổi host | Công cụ test tự động chỉ chạy một client. Logic được kiểm bằng test headless (bên dưới), chưa chạy với client thật |
| **Giao diện điện thoại và máy bảng** | Chỉ tính toán kích thước, chưa chạy trên màn hình thật |
| **`Zone4`** | Tài khoản test chưa mở khóa. Chỉ qua `ContentCheck` |
| **Revive, Gamepass, Product** | Id đang là 0 |
| **Các perk khác, Golden Target, pet theo sau** | Chưa test riêng sau khi sửa scale |
| **Di chuyển ở Mall, Park, Hotel và đi ngang (A/D)** | Mới test kỹ ở Kitchen khi đi thẳng |
| **Bắt NPC bị tường chắn** | Chưa test có chủ đích |
| **Rojo kết nối lại thật sự** | Đã kiểm metadata `ignoreUnknownInstances` trên server Rojo là `true` cho cả hai thư mục Assets và thư mục con; chưa thử ngắt và kết nối lại |
| **Tải với nhiều phòng cùng lúc** | Chưa đo |

### Kiểm tra tĩnh

```bash
selene src          # 0 errors, 0 warnings
rojo build -o /tmp/bap.rbxlx
tools/tests/run.sh  # 55 ca config + công thức + hitbox + phòng, 69 ca lifecycle phòng: đều đạt
```

Test phòng chạy `RoomService` thật với người chơi giả và service giả: vào phòng, ready, đếm ngược, host rời, kick, chỉ bạn bè, phòng đầy, khởi động thất bại, rời trong lúc streaming, người chơi thoát game ở mọi trạng thái, map được giải phóng đúng một lần. Test này không thay thế được việc chơi thử nhiều người thật.

Vị trí đầu và đuôi của capsule hitbox được kiểm bằng test toán; playtest trong Studio mới xác nhận được NPC bắt khi đứng sát, chưa xác nhận riêng ca chạm đuôi.

---

## 5. Kiến trúc

```
src/
├── assets/
│   ├── replicated/          → ReplicatedStorage.Assets (Sounds, Models, Effects)
│   └── server/              → ServerStorage.Assets (Maps, Models)
├── modules/                 → ReplicatedStorage.Modules
│   ├── Config/              dữ liệu thuần, không logic
│   ├── Shared/              Net, ConfigLookup, Hitbox, runFramework
│   ├── Controllers/         client: Data, Gravity, Camera, Sound, Room, MapAnim, NpcVision...
│   └── UIs/ Screens/ UIComponents/   giao diện React
├── serverstorage/Modules/   → ServerStorage.Modules
│   ├── Services/            Run, Room, MapInstance, Data, Npc, Pet, Monetization...
│   ├── Remotes/             Outbound và các *Remotes qua RemoteGuard
│   └── Config/              DataConfig, RemoteConfig
├── character/ characterscripts/
└── server/ client/          cầu nối gọi runFramework
```

- **Lobby** nằm ở `Workspace.Lobby`, không thuộc Rojo.
- **Park** là instance chỉ có trong Studio, nằm ở `ServerStorage.Assets.Maps`, tương ứng map id `Zone3`.
- `src/workspace/` chỉ còn bản JSON cũ của Lobby và Zone3 do `tools/mapgen` sinh ra, không được map vào game.

### Phòng và map

1. Client gửi `CreateRoom` hoặc `JoinRoom`. `RoomService` kiểm tra toàn bộ ở server: quyền sở hữu map, cấp, số người, bạn bè, danh sách bị kick.
2. Host bấm START, đếm ngược theo `RoomConfig`.
3. `MapInstanceService` clone map sang một ô lưới riêng, cách nhau xa hơn bán kính streaming nên client không tải phòng khác. Bản clone stream nguyên khối (`Atomic`).
4. Mỗi thành viên có một run riêng trong bản clone: điểm, vết bẩn và thưởng tính riêng; NPC và perk thuộc về bản clone hoặc run đó.
5. Xong run, người chơi về lobby và rời phòng. Run cuối kết thúc thì phòng đóng, map bị hủy sau `EmptyRoomGrace`.

Tọa độ trong `MapConfig.Spawn` và `RunConfig.NpcPatrols` là **tọa độ gốc của map**. Game tự cộng độ lệch của ô lưới, trên cả server và client.

### Quy tắc mạng và dữ liệu

- Mọi gói tin định nghĩa ở `Shared/Net.lua`. Server gửi qua `Remotes/Outbound`; mọi yêu cầu từ client qua `RemoteGuard`.
- Dữ liệu dùng ProfileStore. Chỉ thêm khóa vào `DataConfig.Template`, không đổi tên hay xóa.

---

## 6. Cài đặt

```bash
rokit install
wally install
rojo serve         # kết nối bằng plugin Rojo trong Studio
selene src
```

**Lưu ý:** place cần có sẵn `Workspace.Lobby` và `ServerStorage.Assets.Maps.Park`. Hai instance này không build được từ repo, nên `rojo build` từ đầu sẽ thiếu chúng.

---

## 7. Quy tắc code

1. Mỗi file có **một khối ghi chú ở đầu** (mục đích, API, phụ thuộc); không ghi chú trong thân code.
2. Mọi giá trị có thể chỉnh nằm trong **Config**, tên ngắn, có giải thích và đơn vị ở đầu file.
3. Config là dữ liệu thuần dạng `return { ... }`: không hàm, không require.
4. Thay đổi nhỏ nhất mà đầy đủ; sửa tận gốc trong code dùng chung.
5. Không bỏ kiểm tra phía server hay bảo vệ dữ liệu.
6. Trước khi gộp: `selene src` 0 lỗi và `rojo build` thành công.
