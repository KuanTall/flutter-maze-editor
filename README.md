# Maze-editor

Maze-editor 是一個使用 Flutter 製作的網頁版迷宮地圖編輯器。你可以在畫布上
繪製相連的房間、設定起點與終點、復原編輯步驟，並在不需要後端服務的情況下
保存本地地圖存檔。

線上展示：
https://kuantall.github.io/flutter-maze-editor/

## 功能

- 在大型迷宮畫布上平移與縮放。
- 從既有房間拖曳繪製相連房間。
- 在兩個已連接的相鄰房間之間再次繪製時，可切換連線狀態。
- 移動綠色起點標記與紅色終點標記。
- 復原與重做近期編輯步驟。
- 自動保存目前地圖。
- 從側邊面板建立具名地圖存檔。
- 從側邊面板載入或刪除地圖存檔。

## 本地存檔

專案使用瀏覽器本地端儲存資料：

- 自動存檔保存於 cookie。
- 具名地圖存檔保存於 `localStorage`。

這樣可以讓最新編輯中的地圖自動保留，同時讓手動建立的存檔清單不受 cookie
容量限制影響。

## 專案結構

```text
lib/
  main.dart
  models/
  pages/
  painters/
  storage/
test/
  widget_test.dart
```

主要目錄說明：

- `lib/main.dart`：應用程式入口。
- `lib/pages/maze_page.dart`：迷宮編輯器頁面與主要互動邏輯。
- `lib/models/`：迷宮、房間與存檔資料模型。
- `lib/painters/`：房間、牆線與方向箭頭的自訂繪製邏輯。
- `lib/storage/`：cookie 與 localStorage 的本地儲存封裝。

## 本地執行

安裝 Flutter 後執行：

```bash
flutter pub get
flutter run -d chrome
```

## 建置 GitHub Pages

```bash
flutter build web --base-href /flutter-maze-editor/
```

產生的靜態網站檔案會輸出到：

```text
build/web
```

目前部署目標分支為 `gh-pages`。

## 測試

```bash
flutter test
```
