## Why

The TV board still reads the old .NET server (`POST https://maleva.my/api/SaleOrderApp/SelectTVSaleOrder`).
The .NET API is being retired (workspace rule, 2026-10-02). The Java port already exists and is shared
with `maleva_app`: `POST /api/sale-orders/tv-search?westport=` (maleva-backend change
`port-sale-order-field-updates`, migrated from .NET `SaleOrderAppController.SelectTVSaleOrder` /
`SaleOrderServices.SelectTVSaleOrder`).

## What Changes

- **No sign-in (owner, 2026-10-12):** the TV opens straight on the board. It sends the header
  `X-TV-Board-Key`, which the backend accepts on `tv-search` only, for one company, read-only
  (maleva-backend change `tv-board-access-key`). The key is given at build time
  (`--dart-define=TV_BOARD_KEY=...`), never kept in the source.
- **Board data:** both boards call `tv-search`; Westport passes `?westport=true` instead of the body
  field `Westport: 1`. The rows come from `Data1.salemaster`; their field names (`Id`, `BillNoDisplay`,
  `SETA`, ...) are the ones `JobModel` already reads.
- **Request body:** `Comid` (`TV_COMPANY_ID`, default 6; the server uses its own company for the key),
  `Fromdate`/`Todate` as `yyyy/MM/dd` (the Java format; the old `yyyy-MM-dd` would be a 400),
  `Remarks 0`, `ETA false`, `Pickup false`.
- **Removed:** the .NET base URL, `F5RequestModel`, `ResponseViewModel`, the `Tokenkey/Userid/Profile`
  header scheme, `shared_preferences` and the request/response `print`s.

Unchanged: the board layout, auto-scroll, the 30 s page slide and the 1 minute refresh. The list is
still jobs with ETA or ETB today or tomorrow by the server clock (.NET used `GETDATE()`, Java
`LocalDate.now()`), so the date control only changes which day sorts first, as before.

## Capabilities

### New Capabilities
- `tv-board`: showing the Home and Westport sale order boards from the shared Java API without a sign-in.
