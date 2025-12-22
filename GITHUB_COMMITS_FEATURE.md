# GitHub Commits Viewer

## Giới thiệu
Tính năng mới cho phép xem lịch sử commits của repository Weather trực tiếp trong ứng dụng.

## Cách sử dụng

### Backend
1. Đảm bảo backend đang chạy:
   ```bash
   cd Backend
   npm install
   npm start
   ```

2. Backend sẽ chạy tại `http://localhost:3002`

3. Có thể test API bằng các endpoint sau:
   - `GET /github/commits` - Lấy danh sách commits
   - `GET /github/commits/:sha` - Lấy chi tiết một commit cụ thể

### Frontend
1. Mở ứng dụng Weather
2. Trên màn hình chính, nhấn vào biểu tượng **commit** (giữa icon chat và search) trên thanh app bar
3. Xem danh sách commits với thông tin:
   - Tên tác giả
   - Thời gian commit
   - Nội dung commit
   - SHA của commit

4. Nhấn vào bất kỳ commit nào để xem chi tiết

## Tính năng

### Backend API
- Lấy danh sách commits từ GitHub repository
- Hỗ trợ phân trang
- Lấy chi tiết commit bao gồm files thay đổi
- Tự động format dữ liệu để frontend dễ sử dụng

### Frontend
- Hiển thị danh sách commits với giao diện đẹp mắt
- Pull-to-refresh để tải lại dữ liệu
- Hiển thị thời gian relative (ví dụ: "2 giờ trước")
- Chi tiết commit với đầy đủ thông tin
- Fallback sang GitHub API trực tiếp nếu backend không khả dụng

## Cấu hình

### Backend URL
Mặc định frontend sử dụng `http://10.0.2.2:3002/github` cho Android emulator.

Để thay đổi, chỉnh sửa file `frontend/lib/services/github_service.dart`:
```dart
static const String baseUrl = 'http://your-backend-url/github';
```

### Repository
Mặc định hiển thị commits của repository `minhduonq/weather`.

Để thay đổi, chỉnh sửa trong file `github_service.dart` hoặc truyền parameters khác khi gọi hàm.

## Lưu ý
- GitHub API có giới hạn rate limit (60 requests/hour cho unauthenticated requests)
- Frontend tự động fallback sang GitHub API nếu backend không khả dụng
- Cần kết nối internet để sử dụng tính năng này
