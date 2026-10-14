## Context

One HTTP call in the whole app (`SaleOrderApiService`), used by the Home and Westport boards through
Riverpod `FutureProvider`s that `MainNavigationScreen` invalidates every minute.

## Decisions

- **Endpoint:** `POST {javaBaseUrl}/api/sale-orders/tv-search?westport=<bool>`, base URL
  `https://maleva.mydriverszone.com` (same as `maleva_app`) in `lib/core/config/app_config.dart`.
- **Access:** header `X-TV-Board-Key: <TV_BOARD_KEY>` on every request; no token, no sign-in screen.
  A build without the key shows "built without TV_BOARD_KEY" and never calls the server.
- **Answer:** `{IsSuccess, StatusCode, Message, Data1: {salemaster: [...], saledetails: [...]}}`; only
  `salemaster` is used, an empty list is `salemaster: []`.
- **Errors:** 403 (key refused: "rebuild with the current TV_BOARD_KEY"), 400 with `Message`, 5xx,
  network/timeout; shown on the board, retried on the next minute refresh.
- **Client:** `JavaApiClient` on the existing `http` package.

## Build

    flutter build apk --release --dart-define=TV_BOARD_KEY=<server TV_BOARD_KEY>

The same value is set on the server as env `TV_BOARD_KEY`. Changing it means a new TV build.

## Tests

`test/` with `http/testing.dart` `MockClient`: key header and no token, refused key, keyless build,
request shape, `Data1.salemaster` parsing, empty list, the app opening on the board.
