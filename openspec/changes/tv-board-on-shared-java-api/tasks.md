## 1. Client

- [x] 1.1 `lib/core/config/app_config.dart` Java base URL, `TV_BOARD_KEY` and `TV_COMPANY_ID` from `--dart-define`. Verify: no `maleva.my` left in `lib/`.
- [x] 1.2 `lib/core/network/java_api_client.dart` sends `X-TV-Board-Key`, reads `Data1`, shows `Message`. Verify: `test/java_api_client_test.dart`.

## 2. Boards

- [x] 2.1 `SaleOrderApiService` calls `tv-search` (Home `westport=false`, Westport `westport=true`) and reads `Data1.salemaster`. Verify: `test/sale_order_api_service_test.dart`.
- [x] 2.2 Remove `F5RequestModel`, `ResponseViewModel`, the debug prints, `shared_preferences` and the old header scheme. Verify: `flutter analyze`.
- [x] 2.3 The app opens on the board with no sign-in. Verify: `test/widget_test.dart`.

## 3. Owner

- [ ] 3.1 Deploy maleva-backend change `tv-board-access-key` with `TV_BOARD_KEY` set on the server.
- [ ] 3.2 Build with `--dart-define=TV_BOARD_KEY=<same key>`, install on the TV. Verify: both boards show today's/tomorrow's jobs.

## 4. Board design (2026-10-14)

- [x] 4.1 Shared `lib/features/board/job_board_view.dart` + `board_theme.dart` for both boards: one column layout for headers and rows, larger vessel name with ship icon and LOAD/OFF tag, status chip and stripe, time cells as time over date, job count, clock, error and empty panels. Verify: `flutter analyze lib`.
- [x] 4.3 Redesign: status summary tiles, live clock, LOADING / OFF-LOADING grouped ETA/ETB, times within 2 hours in amber and passed times dimmed, employee initials, pause at top and bottom of the scroll, legend footer with last update. Design preview with sample data: `flutter run -d chrome -t lib/preview/board_preview.dart`.

## 5. Sign in like maleva_app instead of the TV key (owner, 2026-10-14)

- [x] 5.1 `core/session/tv_auth_service.dart`: `POST /api/mobile/auth/login` once with an employee account; account and token in Android encrypted storage (`flutter_secure_storage`, `allowBackup=false`). A 401 refreshes (`/api/mobile/auth/refresh`); when the 30-day session ends the TV signs in again with the saved account. No sign-out. Only a refused saved account shows the sign-in screen again. Verify: `test/core/tv_auth_test.dart`.
- [x] 5.2 `JavaApiClient` sends `Authorization: Bearer` (the employee path of `tv-search`, unchanged on the server); the board company is the session's `companyId`. Verify: `test/java_api_client_test.dart`, `test/widget_test.dart`.
- [x] 5.3 `--dart-define=TV_BOARD_KEY` dropped from the build. Tasks 3.1/3.2 (server key) are no longer needed for the TV.
- [ ] 5.4 Owner: install the APK, sign in once with an employee account kept for the TV. Verify: both boards show jobs; still signed in after a TV restart.

## 6. Vessel Planning data, one board, remote control (owner, 2026-10-14)

- [x] 6.1 The board reads `POST /api/vessel-plannings/search` (shared with React's Vessel Planning page; employee token, no backend change): the selected day only (today at start, ◀▶ for another day) by ETA on either vessel, finished jobs hidden. `features/home/data/datasources/vessel_planning_api.dart`; `JobModel` reads the Java fields (`JobNo`, `SETD`, `SOETD`, ...). Verify: `test/vessel_planning_api_test.dart`.
- [x] 6.2 ETD (departure) column for both vessels; 1900-01-01 shows as no date.
- [x] 6.3 Westport board removed fully (screen, controller, provider, `tv-search` service and its test, the unused use-case / repository layer).
- [x] 6.4 Remote: ▲▼ rows, ◀▶ date, OK / ⏯ / Back auto mode, auto mode back after 45 s. Verify: `test/features/board/remote_control_test.dart`.
- [x] 6.5 Readability: auto-scroll slowed to ~15 px/s (a row every ~6 s); job numbers shrink to fit instead of "…", long statuses and vessel names wrap to two lines.
- [x] 6.6 Remote reach: ▲ on the first row (or in auto mode) jumps to the last row, ▼ on the last back to the first; a held ▲▼ moves fast and stops at the end; CH± / ⏪⏩ / Page Up/Down jump 6 rows; Home/End first/last. Scrollbar and "ROW n / total" show the position. Verify: `test/features/board/remote_control_test.dart`.
- [x] 6.7 More rows on screen: one slim title row (counts inline), mode badge and remote help moved to the footer, header 84 px and rows 80 px. About 8-9 rows at 1080p instead of 4.
- [x] 6.8 Smaller text in the grid (vessel 18, times 19, job no. / employee 15, status 12) with 68 px rows and a 74 px header: about 10-11 rows at 1080p.
- [x] 6.9 Smaller header: title bar 58 px (title 20, counts 18, date 15, clock 26) and column header 66 px (headings 12-13).
- [x] 6.10 Footer cut to one 20 px line (mode badge, remote help, legend and update time at 10 px).
- [x] 6.11 PORT column: `SPort` (L) and `OPort` (O) when they differ, one line when the same. The vessel's second line is now the off vessel (or "OFF VESSEL"), no longer the port. Status chips show the whole status on up to two lines ("WAITING FOR L-VESSEL"); employee and status columns widened. Verify: `test/vessel_planning_api_test.dart` reads `OPort`.
- [x] 6.12 Vessel search: a letter (or the search / menu key, or /) opens a search bar; results update as you type (350 ms pause) from the same Vessel Planning search over 7 days back to 30 days ahead, filtered on the loading vessel, off vessel and job number (every word must match, any case); matches are highlighted in amber. ▼ or Enter moves into the results; Back clears the text, then closes the search; a forgotten search closes after 2 minutes. Rows stay on screen while a new search loads. Verify: `test/features/board/vessel_search_test.dart`, `test/vessel_planning_api_test.dart`.
- [x] 6.13 Status count tiles removed from the title bar; the vessel search field takes their place (always visible, showing "n VESSELS", or "n FOUND" while searching). The separate search row is gone, so the grid keeps its height.
- [x] 6.14 EMPLOYEE column shows `PICName` (person in charge, `EmployeeRefId`) instead of `EmployeeName` (`ISNULL(LastEmployeeRefid, EmployeeRefId)`), owner's choice. Verify: `test/vessel_planning_api_test.dart`.
- [x] 6.15 Vessel name 18 → 22 (line height 1.0), off-vessel line 12 → 13; a two-line name plus the off line still fits the 68 px row.
- [x] 6.16 Office remote: MENU (Android 82, `contextMenu`) and the blue button (186, `colorF3Blue`) open the search; number keys open it with the digit. The mic button goes to Google Assistant (system), not the app. Search hint says "PRESS MENU".
- [x] 6.17 Ship icon removed from the vessel column; the name starts under the VESSEL heading (16 px) and has the freed width.
- [x] 6.18 Desktop (Mac and Windows): macOS `network.client` entitlement; window titled "Maleva Vessel Board", opening full-screen (Mac) / maximised (Windows); Escape acts as Back; the sign-in is kept in the classic macOS keychain (`usesDataProtectionKeychain: false`; the data-protection keychain refused an unsigned app with -34018, checked on this Mac) and in Windows' credential store. Build steps in `RELEASE_BUILD.md`.
- [ ] 6.19 Owner: build on a Windows PC (`flutter build windows --release`) and sign in once.
- [x] 6.20 Desktop icons: the round Maleva emblem (`assets/company/logo1.png`) on a white rounded tile replaces the Flutter icon - Windows `app_icon.ico` (16-256 px) and the macOS AppIcon set (16-1024 px, Apple margin). Windows program named "Maleva Vessel Board" by Maleva, exe `MalevaVesselBoard.exe`.
- [x] 6.21 Port filter, as on React's Vessel Planning page: the ports come from `GET /api/port-masters/company/{id}/active` (shared API, employee token, no backend change) and the picked port is sent as the search's `search`, which the server matches against `SPort` and `OPort`. PORT chip in the title bar; the remote's green button (or a click) opens the list - up/down, OK picks, Back closes. The pick is kept on the device. `JavaAnswer` also reads `data` (port-master answers use `{success, data}`). Verify: `test/features/board/port_filter_test.dart`, `test/vessel_planning_api_test.dart`.
- [x] 6.22 Port text 14 → 20 (L/O marks 13); port column widened (flex 3 → 5) so "SOUTHPORT-B11" fits.

## 7. Planning board (owner, 2026-10-14)

- [x] 7.1 Second board PLANNING from the shared, read-only `POST /api/planing/select-planning` (React /planning/view; employee token; no backend change): the day's `saledetails` - truck (`TruckName`, else `TruckNameD`), driver (`DriverName`, else `DriverNameD`), job no., customer, from → to, vessel, pickup / delivery time, status. Grouped by truck, pickup time inside a truck. The TV never saves or changes a plan.
- [x] 7.2 Tabs VESSEL PLANNING / PLANNING in the title bar; the remote's yellow button (Tab on desktop) or a click switches; the board is kept on the device. Same grid, auto-scroll, remote, search (truck, driver, vessel, job no., customer) and port filter (`SPort` / `OPort`).
- [x] 7.3 `BoardView<T>` (one layout for both boards), `BoardHeaderRow`, `BoardCells` (time, status, highlight) shared. `JavaAnswer` reads unwrapped answers (select-planning has no `Data1`). Verify: `test/features/planning/planning_test.dart`.
