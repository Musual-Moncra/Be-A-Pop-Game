# Be A Poop (BAP) — Báo cáo dự án

> Game Roblox thể loại **Arcade / Simulator**: người chơi là một cục "poop" lăn khắp bản đồ, bò lên tường và trần, làm bẩn mọi thứ để kiếm điểm, đổi điểm ra Poop Coins, nâng cấp và mở khóa bản đồ mới.
>
> Cập nhật: **28/10/2026** · Nhánh chính: `main` (`85b8a17`) · Công cụ: Rojo 7.7, Luau, React-lua, Packet, ProfileStore

---

## 1. Tóm tắt tiến độ

| Giai đoạn | Nội dung | Trạng thái |
|---|---|---|
| Phase 1 — Prototype | Di chuyển bám tường, vết bẩn, điểm, thời gian, coins | ✅ Xong |
| Phase 2 — Core Game | Mục tiêu, Stain Meter, nâng cấp, mở map, quests, chế độ chơi | ✅ Xong |
| Phase 3 — Hạ tầng | Lớp Remotes, tối ưu, UI responsive | ✅ Xong |
| Phase 4 — Tính năng GDD | Pets, Daily, Shop, Gacha, Rebirth, Perks, Potions, Events, Leaderboards, 4 map mới | ✅ Xong, đã playtest |
| Phase 5 — Ổn định & Polish | Sửa bug, chống lag, UI một nút, NPC tầm nhìn/đuổi, chuẩn hóa code | ✅ Code xong · ⏳ chưa playtest |

**Mức hoàn thành so với Dev Backlog (ước tính): ~90%.** Phần còn lại cần thao tác ngoài code (tạo Gamepass/Product trên Roblox, nhạc) hoặc tài liệu chưa có đặc tả (Pet Index, Admin Abuse, Onboarding).

---

## 2. Đối chiếu Dev Backlog

### Epic 1 — Core Loop & Stain System
| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| 1.1 Điều khiển nhân vật | ✅ | Poop lăn, bò tường/trần, camera theo trọng lực |
| 1.2 Vết bẩn môi trường | ✅ | Tái sử dụng part (ring buffer), giới hạn số vết |
| 1.3 Tính điểm theo diện tích | ✅ | Điểm = diện tích × hệ số vật thể × hệ số buff |
| 1.4 Làm bẩn vật thể | ✅ | Vật đổi màu dần → "soiled" + thưởng |
| 1.5 Stain Meter + NPC hoảng | ✅ | Meter ẩn từng vật, NPC bỏ chạy khi vật gần đó bị bẩn hoàn toàn |
| 1.6 Lifespan | ✅ | Hết giờ → kết thúc run (có Revive) |
| 1.7 Đổi điểm → Coins | ✅ | Nhân hệ số map, mode, pet, gamepass, rebirth, boost |

### Epic 2 — Level Design
| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| 2.1 Lobby | ✅ | Cổng chơi, 5 quầy (Upgrade, Eggs, Skins, Daily, Rebirth), 3 bảng xếp hạng |
| 2.2 Zone 1 — Kitchen (x1) | ✅ | Miễn phí |
| 2.3 Zone 2 — Shopping Mall (x2.5) | ✅ | 5.000 coins |
| 2.4 Zone 3 — Park (x6) | ✅ | 40.000 coins |
| 2.5 Zone 4 — Grand Hotel (x15) | ✅ | 250.000 coins |
| 2.6 Sự kiện ngẫu nhiên | ✅ | Special Time + Golden Targets |

Tất cả bản đồ dùng **texture Studs** cho mọi MaterialVariant và có chi tiết chuyển động (quạt trần, cây đung đưa, đu quay, xích đu, đèn chùm, bóng bay, biển neon).

### Epic 3 — Stats & Perks
| Hạng mục | Trạng thái |
|---|---|
| 3.1–3.2 Nâng cấp Lifespan / Speed / Stain Size, giá tăng theo cấp số nhân | ✅ |
| 3.3–3.4 Perk spawn ngẫu nhiên: Speed Boost, Time Bonus, Big Splat, Coin Rush, Combo Saver, Mini Bomb, Mega Size (cộng dồn) | ✅ |
| Stink Potions (x2 Lifespan / Speed / Stink theo thời gian) | ✅ |

### Epic 4 — Economy & Monetization
| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| 4.1 Poop Coins + Gems | ✅ | |
| 4.2 Gamepass: x2 Coins, x2 Gems, Magnet, +3 Pet Slots, VIP | ⚠️ | Code xong, **ID = 0** chờ tạo trên Roblox |
| 4.3 Dev Products: gói Gems/Coins, Revive (4/9/13 R$), Stain Bomb, Newbie Pack | ⚠️ | Như trên; ProcessReceipt chống trùng |
| 4.4 Gacha crate skin/trail | ✅ | Skins: Gold, Rainbow, Frozen, Ninja, Alien… · Trails: Neon, Fire, Water, Ice Cream |
| 4.5 Tỉ lệ rơi 8 bậc hiếm | ✅ | Common → Darkness |

### Epic 5 — UI & Retention
| Hạng mục | Trạng thái |
|---|---|
| 5.1 HUD: timer, điểm, icon perk, thanh % map, banner sự kiện, popup Revive | ✅ |
| 5.2 Menu nâng cấp | ✅ |
| 5.3 Bảng xếp hạng "Best Stinker" theo ngày / tuần / mọi thời đại | ✅ |
| 5.4 Daily reward 7 ngày (ngày 7 skin độc quyền) | ✅ |
| 5.6 Phong cách cartoon | ✅ |

### Mở rộng (Phase 2 trong backlog)
| Hạng mục | Trạng thái |
|---|---|
| 6.1 Pets: 4 trứng × 6 pet, gộp 5 con → Golden → Rainbow, pet theo sau | ✅ |
| 6.2 Special Time: mỗi 4 phút, kéo dài 2 phút, map ngẫu nhiên | ✅ |
| 6.3 Thưởng Gems khi map đạt 100% | ✅ |
| Rebirth (reset coins/nâng cấp, nhận hệ số vĩnh viễn + gems) | ✅ Bản cơ bản |

---

## 3. Phase 5 — Thay đổi mới nhất

| Yêu cầu | Kết quả |
|---|---|
| Bug cục poop vàng vĩnh viễn | Save cũ thiếu skin `Default` → không đổi lại được. Default nay luôn sở hữu và khôi phục đúng màu 3 tầng gốc; trail có thể tháo |
| UI chưa scale | Thay thanh nút bên trái (tràn màn hình mobile) bằng dock co giãn theo vùng an toàn |
| UI tinh gọn | **Một nút MENU ở giữa** → bấm bung **một hàng ngang** 8 nút (PLAY to nhất ở giữa, có tia sáng xoay) |
| Lag | Pet kéo lệch nhân vật người chơi (nguyên nhân chính) đã sửa; tái sử dụng vết bẩn; gói mạng giảm ~50%; hệ số pet được cache; animation map gom 1 lệnh BulkMoveTo/30 Hz |
| NPC tầm nhìn | Vùng **bầu dục đỏ** dưới chân NPC chỉ hướng nhìn. Vào vùng → NPC đuổi (đỏ đậm); ra khỏi vùng đủ lâu → NPC bỏ cuộc về tuyến tuần tra |
| Chuẩn code | Chỉ ghi chú ở đầu file; mọi giá trị cân bằng được nằm trong Config, tên ngắn gọn |

---

## 4. Việc còn lại

1. **Playtest Phase 5** trong Studio (NPC đuổi, sửa skin vàng, đo lag thực tế).
2. **Tạo Gamepass và Developer Product** trên Roblox, điền ID vào `src/modules/Config/MonetizationConfig.lua`.
3. **Nhạc nền**: điền asset ID vào `src/modules/Config/SoundConfig.lua`.
4. Chờ đặc tả: **Pet Index**, **Admin Abuse**, chi tiết **Rebirth**.
5. **Onboarding / tutorial** cho người chơi mới (mục Polish).
6. NPC đuổi theo đường thẳng (chưa pathfinding), có thể xuyên đồ vật ở góc.

---

## 5. Cân bằng game (không cần sửa code)

Mọi số liệu nằm trong `src/modules/Config/` (dữ liệu thuần, mỗi file có phần đầu giải thích từng trường và đơn vị):

| File | Chỉnh |
|---|---|
| `GameConfig` | Điểm, quy đổi coins/XP, kích thước ô vết bẩn |
| `MapConfig` | Giá mở map, hệ số thưởng, gems khi đạt 100% |
| `UpgradeConfig` | Nâng cấp, giá, giá trị mỗi cấp |
| `PowerupConfig` / `PotionConfig` | Perk trong map, thuốc |
| `NpcConfig` | Tầm nhìn (`ViewLength`, `ViewWidth`), tốc độ đuổi (`ChaseSpeed`), thời gian bỏ cuộc (`LoseTime`), phạt khi bị bắt |
| `PetConfig` | Trứng, pet, độ hiếm, hệ số |
| `CosmeticConfig` | Skin, trail, crate, tỉ lệ rơi |
| `DailyRewardConfig` / `RebirthConfig` / `EventConfig` | Daily, rebirth, Special Time |
| `MonetizationConfig` | ID và giá Robux |
| `UIConfig` / `LobbyUIConfig` / `RunUIConfig` | Màu, kích thước, chữ trên UI |

---

## 6. Kiến trúc

```
src/
├── modules/                 → ReplicatedStorage.Modules (dùng chung)
│   ├── Config/              dữ liệu cân bằng (không có logic)
│   ├── Shared/              Net (gói mạng), ConfigLookup (công thức), runFramework
│   ├── Controllers/         client: Data, Gravity, Camera, Sound, MapAnim, NpcVision, GoldenGlow…
│   ├── UIs/ Screens/ UIComponents/   giao diện React (App, LobbyDock, các cửa sổ, thư viện nút/thẻ)
├── serverstorage/Modules/   → ServerStorage.Modules (chỉ server)
│   ├── Services/            Run, Data, Npc, Pet, Cosmetic, Monetization, Daily, Event, Leaderboard…
│   ├── Remotes/             Outbound (server → client) + *Remotes (client → server, có RemoteGuard)
│   └── Config/              DataConfig (cấu trúc save), RemoteConfig (giới hạn tần suất)
├── workspace/               Lobby + Zone1–4 (sinh từ tools/mapgen/gen_maps.py)
└── server/ client/          cầu nối gọi runFramework
```

- **Mạng**: mọi gói tin định nghĩa ở `Shared/Net.lua`; server chỉ gửi qua `Remotes/Outbound`; mọi yêu cầu từ client đi qua `RemoteGuard` (giới hạn tần suất + kiểm tra kiểu).
- **Dữ liệu**: ProfileStore, chỉ thêm khóa mới vào `DataConfig.Template` (không đổi tên/xóa).
- **Bản đồ**: chỉnh trong `tools/mapgen/gen_maps.py` rồi chạy `python3 tools/mapgen/gen_maps.py .`.

---

## 7. Cài đặt & chạy

```bash
wally install                                         # cài packages
rojo build -o "( Project ) Be A Pop (Do All ).rbxlx"  # build place
rojo serve                                            # đồng bộ với Studio
selene src                                            # kiểm tra code (phải 0 lỗi)
```

Mở file `.rbxlx` trong Roblox Studio, bật plugin Rojo và kết nối tới `rojo serve`.

---

## 8. Quy tắc code

1. Mỗi file chỉ có **một khối ghi chú ở đầu** (mục đích, API, phụ thuộc); không ghi chú trong thân code.
2. Mọi giá trị có thể cân bằng/chỉnh sau này nằm trong **Config**, tên ngắn gọn, có giải thích ở đầu file Config.
3. Config là dữ liệu thuần: không hàm, không require.
4. Thay đổi nhỏ nhất mà đầy đủ; sửa tận gốc một lần trong code dùng chung.
5. Trước khi gộp: `selene src` = 0 lỗi và `rojo build` thành công.
