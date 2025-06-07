# Frontend
## Chức năng đã thêm:
- Widget thời tiết (1 cái)
- Update danh sách địa điểm ở HomePage khi đã thay đổi
- Fix lỗi Pixel overflow
## Bugs:
- Widget: Không hiển thị icon thời tiết

## Code khác cần chú ý
Thêm đoạn code này vào hàm thay đổi nhiệt độ C/F trong màn hình cài đặt

```

// Thêm vào khi người dùng thay đổi cài đặt đơn vị nhiệt độ
void _changeTemperatureUnit(String newUnit) {
  // ...existing code...
  
  // Cập nhật lại widget khi đổi đơn vị
  WidgetService.updateWidgetData();
}

```
Phần này để tự động update trang HomePage khi thay đổi danh sách địa điểm
```
// Trong ManageLocationsScreen khi xóa địa điểm
void deleteLocation(int id) async {
  await DatabaseHelper().deleteLocation(id);
  
  // Làm mới danh sách địa điểm trong controller
  await Get.find<LocationController>().loadLocations(currentPosition, InitialName);
}

// Trong SearchPlace khi thêm địa điểm mới
void addLocation(Map<String, dynamic> location) async {
  await DatabaseHelper().insertLocation(location);
  
  // Làm mới danh sách địa điểm trong controller
  await Get.find<LocationController>().loadLocations(currentPosition, InitialName);
}
```
