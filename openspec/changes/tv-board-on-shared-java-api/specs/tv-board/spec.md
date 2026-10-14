## ADDED Requirements

### Requirement: The TV signs in once with an employee account

The app SHALL sign in with `POST /api/mobile/auth/login` (an employee account, like maleva_app), keep
the account and token in encrypted storage, and send `Authorization: Bearer <token>` on every request.
It SHALL renew the token on a 401 (`/api/mobile/auth/refresh`, then a new sign-in with the saved
account) and offer no sign-out.

#### Scenario: First start
- **WHEN** the TV has never signed in
- **THEN** the sign-in screen shows; after a sign-in the board opens

#### Scenario: Later starts
- **WHEN** the TV signed in before
- **THEN** the board opens with no sign-in screen

#### Scenario: Saved account refused
- **WHEN** the saved account can no longer sign in (password changed, account disabled)
- **THEN** the sign-in screen shows again with the user name filled in

### Requirement: One board reads the shared Vessel Planning search

The app SHALL show one board, fed by `POST /api/vessel-plannings/search` (the API behind React's
Vessel Planning page) with `comid` = the session's company, `fromdate` and
`todate` = the selected day (`yyyy-MM-dd`; today at start, ◀▶ for another day), `etaType` 0 (ETA on either vessel) and `DeliveryDone` true
(finished jobs hidden). There is no Westport board.

#### Scenario: Rows shown
- **WHEN** the search returns rows
- **THEN** each row shows `JobNo`, the vessel names, employee, status, and `SETA`/`SETB`/`SETD` under
  LOADING VESSEL and `SOETA`/`SOETB`/`SOETD` under OFF VESSEL as ETA (arrival), ETB (berthing) and
  ETD (departure)

#### Scenario: No date
- **WHEN** a time is empty or 1900-01-01
- **THEN** its cell shows a dash

#### Scenario: No jobs
- **WHEN** the search returns an empty list
- **THEN** the board shows "No jobs for this date", not an error

### Requirement: Remote control

The board SHALL scroll by itself (auto mode). ▲▼ SHALL stop auto mode and move a highlight over the
rows; ◀▶ SHALL change the day; OK, ⏯ or Back SHALL return to auto mode, which also returns after
45 s without a key.

#### Scenario: Pick a row
- **WHEN** ▼ is pressed in auto mode
- **THEN** scrolling stops, the first row is highlighted and the mode badge shows PAUSED

#### Scenario: Left alone
- **WHEN** no key is pressed for 45 s while paused
- **THEN** auto mode comes back
