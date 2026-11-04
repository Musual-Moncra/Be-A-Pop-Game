# Be A Poop

Game Roblox thể loại Arcade / Simulator, viết bằng Luau với Rojo, React-lua, Packet và ProfileStore.

> Cập nhật: **04/11/2026** · Nhánh: `release/prep`
>
> Tài liệu thiết kế (GDD, backlog) có NDA nên không nằm trong repo này. README chỉ mô tả kỹ thuật và kết quả kiểm thử.

---

## 1. Trạng thái phát hành

**Chưa sẵn sàng phát hành.** Vòng chơi một người đã được playtest trong Studio. Cần làm xong các mục dưới đây trước.

### Bắt buộc trước khi phát hành

| # | Việc | Người làm |
|---|---|---|
| 1 | **Save/Publish place.** `Lobby`, `Park` và mọi instance chỉ có trong Studio được lưu trong place, không nằm trong repo | Lead |
| 2 | **Test nhiều người thật** bằng Studio > Test > Start Server với 2-3 người, xem mục 4 | QA |
| 3 | Tạo Gamepass và Developer Product, điền `Id` trong `MonetizationConfig` (đang là 0). Popup Revive chỉ hiện khi có id, nên chưa test được | Lead |
| 4 | Test giao diện trên điện thoại và máy bảng thật hoặc giả lập, xem mục 4 | QA |
| 5 | Chơi thử `Zone4` bằng tài khoản đã mở khóa, xem mục 4 | QA |

### Chờ quyết định thiết kế

| Câu hỏi | Hiện tại trong code | Cách đổi |
|---|---|---|
| Điều kiện mở map | Chỉ tính coins | `MapConfig.RequirePreviousComplete` |
| Số ô pet mặc định | 3 | `PetConfig.BaseSlots` |
| Thưởng khi đạt 100% map | Gems | Thêm Pet cần viết logic |
| Theme các map | Theo bản đã dựng | Đổi theme cần dựng lại map |
| Bán kính Stain Bomb | Cố định, `StainBombRadius` | Cần định nghĩa rõ cách tính theo kích cỡ |
| Thời gian cộng theo từng mức Revive | Một giá trị, `ReviveSeconds` | Cần thêm trường theo mức |

### Chưa làm

- Pet Index và cơ chế pet tạo tài nguyên: chưa có đặc tả chi tiết.
- Giá Robux của thuốc: `PotionConfig` chưa có trường giá.
- Hiệu ứng lửa cho trail của một loại thuốc.
- Nhạc nền và âm `LevelUp`: chưa có asset.
- Onboarding cho người mới.
- NPC đuổi theo đường thẳng, chưa có pathfinding.

### Lỗi đã biết

- `rbxassetid://203785492` báo sai loại asset khi Play. Không tìm thấy id này trong `src` hay trong các thuộc tính asset phổ biến của map và lobby, nên chưa xác định được nguồn. Không ảnh hưởng lối chơi trong các lần test.
- `rbxasset://sounds/action_landing.mp3` báo lỗi đọc tạm trong Studio. Cần kiểm tra lại ngoài Studio, đây là âm `RunEnd`.

---

## 2. Thay đổi ở đợt này

| Hạng mục | Kết quả |
|---|---|
| Config | Mọi file dùng dạng `return { Field = value }` |
| Assets | `ReplicatedStorage.Assets` và `ServerStorage.Assets`, Rojo không xóa instance tạo tay |
| Id dạng text | Animation và texture nằm ở `AssetConfig` |
| Map | Mọi map trừ Lobby nằm ở `ServerStorage.Assets.Maps`, được clone cho từng phòng |
| Phòng chơi | Tạo phòng, chọn số người, chỉ bạn bè, danh sách phòng, mời, sẵn sàng, đếm ngược, kick, đổi host |
| Hitbox | Một capsule theo thân cho bắt, nhặt đồ và tầm nhìn NPC; chặn bắt xuyên tường |
| Thuật toán | Khóa ô vết bẩn dạng số, bỏ attribute được gửi qua mạng, NPC tách theo phòng, dọn tham chiếu khi hủy map, giảm cấp phát trong vòng lặp |
| Giao diện | Scale và layout mới, Lifespan ở giữa trên, Score ở góc phải trên |
| Nội dung | `ContentCheckService` cảnh báo thiếu asset khi Play trong Studio; `docs/CONTENT_GUIDE.md` cho team không lập trình |

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
| **Perk, Golden Target, Mega Size, pet theo sau khi đổi hitbox** | Chưa test riêng trong đợt này |
| **Leo tường trên các viền sàn sau khi đổi điểm dò** | Chưa test có chủ đích |
| **Rojo kết nối lại thật sự** | Đã kiểm metadata `ignoreUnknownInstances` trên server Rojo là `true` cho cả hai thư mục Assets và thư mục con; chưa thử ngắt và kết nối lại |
| **Tải với nhiều phòng cùng lúc** | Chưa đo |

### Kiểm tra tĩnh

```bash
selene src          # 0 errors
rojo build -o /tmp/bap.rbxlx
tools/tests/run.sh  # 45 ca config + công thức + hitbox, 69 ca lifecycle phòng: đều đạt
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
