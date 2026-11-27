# HyperMac

**HyperMac** là ứng dụng trên thanh menu dành cho macOS. Ứng dụng gom các thao tác với cửa sổ, clipboard, màn hình và phần cứng vào một giao diện viết bằng Swift, AppKit và SwiftUI. Bản phát hành mới nhất được đóng gói Universal 2 cho cả Apple Silicon và Intel.

[![Latest](https://img.shields.io/badge/release-Latest-brightgreen)](https://github.com/MacExtension/HyperMac/releases/latest)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)](https://github.com/MacExtension/HyperMac/releases/latest)
[![Universal 2](https://img.shields.io/badge/chip-Apple%20Silicon%20%2B%20Intel-brightgreen)](https://github.com/MacExtension/HyperMac/releases/latest)
[![GPLv3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

## Tải về và cài đặt

[**Tải HyperMac.dmg (Latest)**](https://github.com/MacExtension/HyperMac/releases/latest/download/HyperMac.dmg) · [Tải bản ZIP](https://github.com/MacExtension/HyperMac/releases/latest/download/HyperMac.zip) · [Xem ghi chú phát hành](https://github.com/MacExtension/HyperMac/releases/latest)

1. Tải `HyperMac.dmg`, mở tệp rồi kéo **HyperMac** vào thư mục **Applications**. Nếu chọn bản ZIP, giải nén `HyperMac.zip` rồi kéo `HyperMac.app` vào **Applications**.
2. Nếu đã cài bản cũ, thoát HyperMac trước khi thay ứng dụng trong **Applications**.
3. Mở HyperMac. Ứng dụng xuất hiện trên thanh menu và không có biểu tượng ở Dock.
4. Nếu macOS chặn ứng dụng vì chưa xác minh nhà phát triển, mở **Cài đặt hệ thống → Quyền riêng tư & Bảo mật** rồi chọn **Vẫn mở** cho HyperMac.
5. Mở bảng điều khiển từ thanh menu, vào thẻ **Cấp quyền phần mềm** để cấp những quyền cần cho tính năng bạn sử dụng.

> Theo [ghi chú phát hành](https://github.com/MacExtension/HyperMac/releases/latest), bản phát hành mới nhất có 7 ngày dùng thử tính năng Pro; hãy xem trang đó để biết điều kiện gia hạn và các thay đổi. Bản phát hành được ký bằng chứng chỉ tự ký, nên macOS có thể yêu cầu bước **Vẫn mở** ở trên.

## HyperMac có gì?

| Nhóm | Tính năng |
| --- | --- |
| Cửa sổ | Chia nửa hoặc chia góc, căn giữa, phóng to, khôi phục kích thước cũ và chuyển cửa sổ giữa các màn hình. Trình chuyển cửa sổ có ảnh xem trước, điều hướng bằng bàn phím và lọc theo màn hình. |
| Clipboard | Lưu lịch sử văn bản, ảnh, liên kết và mã màu bằng AES-256-GCM; tìm kiếm, ghim, dán nhanh và tự dọn theo giới hạn số mục hoặc số ngày. |
| Màn hình | Chỉnh sáng màn hình ngoài bằng F1/F2 khi màn hình hỗ trợ DDC/CI; chọn độ phân giải và tần số quét; tạo màn hình ảo và tắt tối màn hình chính khi cần điều khiển từ xa. |
| Chụp màn hình | Chọn vùng chụp, vẽ và thêm chữ, làm mờ hoặc làm pixel vùng nhạy cảm, sao chép hoặc lưu ảnh; quét chữ offline bằng OCR tiếng Việt và tiếng Anh. |
| Pin và nhiệt độ | Đặt giới hạn sạc, sạc đầy tạm thời, theo dõi nhiệt độ và tốc độ quạt. Trên máy có quạt, chọn Hệ thống, Medium, High, thanh tốc độ hoặc đường cong theo nhiệt độ. Mac bàn hiện trạng thái nguồn AC. |
| Theo dõi hệ thống | Xem CPU, RAM, GPU và tốc độ đọc/ghi ổ đĩa. Khi bật đo tốc độ chép file, ứng dụng hiển thị thêm lưu lượng giao diện mạng dùng cho ổ NAS. |
| Tiện ích | Cắt và dán tệp trong Finder, ngăn kéo biểu tượng thanh menu, chống ngủ màn hình, dọn rác, gỡ ứng dụng và tìm tệp lớn. |
| Âm thanh | Bật mixer để chỉnh 0–200% hoặc tắt tiếng từng ứng dụng đang phát, dùng CoreAudio Process Tap trên macOS 14.2+. |

Giao diện có tiếng Việt và tiếng Anh. Bạn có thể bật, tắt các tính năng và đổi những phím tắt được hỗ trợ trong ứng dụng.

## Bắt đầu sử dụng

Các phím dưới đây là **mặc định**. Nếu đã thay đổi trong tab **Phím tắt**, ứng dụng sẽ dùng tổ hợp bạn đã lưu.

| Thao tác | Phím tắt |
| --- | --- |
| Chuyển cửa sổ | `⌘Tab` hoặc `⌥Tab` |
| Mở lịch sử clipboard | `⇧⌘C` |
| Chụp màn hình | `⇧⌘1` hoặc `F4` |
| Quét chữ từ màn hình | `⇧⌘2` hoặc nút OCR (`⌘O`) trong trình chụp ảnh |
| Chia cửa sổ sang trái / phải | `⌃⌥←` / `⌃⌥→` |
| Chia cửa sổ lên trên / xuống dưới | `⌃⌥↑` / `⌃⌥↓` |
| Chia bốn góc | `⌃⌥U` / `⌃⌥I` / `⌃⌥J` / `⌃⌥K` |
| Phóng to / căn giữa / khôi phục kích thước | `⌃⌥↩` / `⌃⌥C` / `⌃⌥⌫` |
| Chuyển cửa sổ sang màn hình khác | `⌥⌘←` / `⌥⌘→` |
| Mở ngăn kéo thanh menu | `⌥⌘B` |
| Bật lại màn hình chính | `⌃⌥⌘1` |

Trong bảng clipboard, dùng `↑`/`↓` để chọn, `↩` để dán, `⌥P` để ghim và `⌥⌫` để xóa. Phím `1`–`9` dán nhanh các mục tương ứng khi ô tìm kiếm đang trống.

Để di chuyển tệp trong Finder, chọn tệp rồi bấm `⌘X`, mở thư mục đích và bấm `⌘V`. Bấm `Esc` để hủy thao tác cắt. Tính năng này có công tắc riêng trong tab **Phím tắt**.

## Quyền truy cập

Thẻ **Cấp quyền phần mềm** trong tab **Màn hình** giải thích từng quyền và mở đúng trang cài đặt macOS.

| Quyền | Dùng cho |
| --- | --- |
| **Trợ năng** | Phím tắt toàn cục, quản lý cửa sổ, ngăn kéo thanh menu và thao tác cắt/dán trong Finder. |
| **Ghi màn hình** | Ảnh xem trước cửa sổ và chụp màn hình. Nếu không cấp, trình chuyển cửa sổ vẫn có thể hiển thị biểu tượng ứng dụng. |
| **Helper SMC** | Giới hạn sạc và điều khiển quạt. Chỉ cài khi dùng các tính năng này; macOS sẽ yêu cầu quyền quản trị. |
| **Bluetooth** | Sleep Guard khi bật chế độ quản lý Bluetooth lúc máy ngủ. |
| **Ghi âm thanh hệ thống** | Mixer theo từng ứng dụng. macOS chỉ hỏi khi bạn bật mixer và điều chỉnh âm lượng. |

Một số tính năng phụ thuộc vào phần cứng: Mac không có quạt sẽ không hiện thẻ điều khiển quạt; chỉnh sáng DDC/CI cần màn hình và kết nối tương thích. Số liệu NAS là lưu lượng của giao diện mạng, nên có thể bao gồm hoạt động mạng khác.

## Tự biên dịch

Cần macOS 14 trở lên và Xcode Command Line Tools. Từ thư mục gốc của mã nguồn:

```bash
swift build -c release
```

Để đóng gói ứng dụng, máy cần có identity ký cố định `HyperMac Self-Signed`. Chỉ chạy lệnh đầu tiên một lần nếu máy chưa có identity này; các lần sau chỉ cần chạy lệnh thứ hai:

```bash
./scripts/setup-signing-identity.sh
./build.sh --universal
```

`./build.sh --universal` tạo `build/HyperMac.app`, `.zip` và `.dmg` cho Apple Silicon và Intel. Script không tự cài hoặc mở lại HyperMac. Trong ứng dụng đang chạy, chọn **Cập nhật từ build local** để áp dụng bản mới. Bản build local này chỉ chứa các tính năng kỹ thuật, không có cơ chế dùng thử Pro hoặc thanh toán VietQR. Không tạo identity mới nếu bạn đã có identity đang dùng, vì thay chứng chỉ có thể khiến macOS yêu cầu cấp lại quyền Trợ năng.

## Câu hỏi thường gặp

**Không thấy HyperMac trong Dock?** HyperMac là ứng dụng thanh menu. Hãy tìm biểu tượng của ứng dụng ở góc trên bên phải màn hình.

**Phím tắt không hoạt động?** Kiểm tra quyền **Trợ năng** trong Cài đặt hệ thống, sau đó xem tính năng đã được bật và tổ hợp phím có trùng với ứng dụng khác hay không.

**Máy Mac Intel có dùng được không?** Có. Bản phát hành mới nhất là Universal 2 cho Apple Silicon và Intel. Tính năng chỉnh âm lượng riêng từng ứng dụng yêu cầu macOS 14.2 trở lên.

**Cập nhật ứng dụng thế nào?** Tải bản mới từ [GitHub Releases](https://github.com/MacExtension/HyperMac/releases), thoát HyperMac, thay ứng dụng trong `/Applications` rồi mở lại. Cài đặt của bạn được macOS lưu riêng với tệp ứng dụng.

## Phiên bản, đóng góp và giấy phép

Xem thay đổi và tệp tải của từng phiên bản tại [GitHub Releases](https://github.com/MacExtension/HyperMac/releases). Báo lỗi hoặc đề xuất cải tiến tại [GitHub Issues](https://github.com/MacExtension/HyperMac/issues).

HyperMac © 2026 Nguyễn Khắc Đại và các cộng tác viên. Cảm ơn [@thaupc](https://github.com/thaupc) và [@dovantuit](https://github.com/dovantuit) vì các đóng góp cho dự án.

Mã nguồn được cấp phép theo [GNU GPL v3.0](LICENSE). Khi phân phối bản đã sửa đổi, hãy tuân thủ các điều khoản về bản quyền, giấy phép và cung cấp mã nguồn trong tệp `LICENSE`.
