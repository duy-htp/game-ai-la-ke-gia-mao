# Device testing matrix

Không đánh dấu PASS nếu chưa chạy trên thiết bị/simulator thật. Mỗi lần chạy cần
ghi thiết bị, OS, build SHA và bằng chứng không chứa secret.

| Platform | Scenario | Expected | Status |
|---|---|---|---|
| iPhone/iOS | Fresh launch | Giữ identity, khôi phục Home/Room/Game | Not run |
| iPhone/iOS | Background/resume | Ẩn secret, refetch, hội tụ deadline | Not run |
| iPhone/iOS | Network off/on | Giữ snapshot, banner, không rời room | Not run |
| iPhone/iOS | Kill/restart | Cùng user/role/room và đúng phase | Not run |
| iPhone/iOS | Complete game | Result/reward đúng một lần | Not run |
| iPhone/iOS | Play Again response loss | Lobby, không reset hai lần | Not run |
| iPhone/iOS | Profile edit/relaunch | Username/avatar mới được giữ, stats không đổi | Not run |
| iPhone/iOS | History pagination | Chỉ ván của user, không trùng khi load more | Not run |
| iPhone/iOS | Result → Profile | XP/coin/stats/history cập nhật authoritative | Not run |
| Android/Samsung | Fresh launch | Giữ identity, khôi phục Home/Room/Game | Not run |
| Android/Samsung | Background/resume | Ẩn secret, refetch, hội tụ deadline | Not run |
| Android/Samsung | Network off/on | Giữ snapshot, banner, không rời room | Not run |
| Android/Samsung | Kill/restart | Cùng user/role/room và đúng phase | Not run |
| Android/Samsung | Complete game | Result/reward đúng một lần | Not run |
| Android/Samsung | Play Again response loss | Lobby, không reset hai lần | Not run |
| Android/Samsung | Profile edit/relaunch | Username/avatar mới được giữ, stats không đổi | Not run |
| Android/Samsung | History pagination | Chỉ ván của user, không trùng khi load more | Not run |
| Android/Samsung | Result → Profile | XP/coin/stats/history cập nhật authoritative | Not run |

Supabase SDK được phép persist refresh/session token trong secure platform
storage. Ứng dụng không persist keyword, role, vote target, Final Guess answer,
service-role key hoặc database credential.
