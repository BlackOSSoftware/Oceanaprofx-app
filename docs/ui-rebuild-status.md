# Oceana UI rebuild status

Screenshots source: `docs/ui-screenshots/` (client WhatsApp dump 2026-11-02).

## Done (foundation + primary tabs)

| Area | Status |
|------|--------|
| Design tokens (`OcColors`, Inter via Google Fonts) | Done |
| Lucide icon library (no MT5 PNGs in new shell) | Done |
| Bottom nav: Quote / Chart / Trade / Dashboard / More | Done |
| Welcome + Login | Done (wired to `tradingService.login`) |
| Dashboard account cards + details sheet | Done |
| More / Settings hub (profile, theme, logout…) | Done |
| Quotes watchlist (sort / swipe delete / account sheet) | Done |
| Trade Market / Pending tabs + close action | Done |
| Chart ticket (SELL/BUY) | Done — candle painter TBD |

## Still to match pixel-perfect from screenshots

- Broker search + Contact Support modal
- Edit Profile form
- Verify account steps
- Pending order form + order-type sheet
- Close / Modify position full page
- Trade History + filter sheets
- Add instruments search chips
- Deposit / Withdraw / Transfer / Finance screens (backend APIs)
- Replace remaining legacy MT5 feature files when unused

## Entry

`lib/main.dart` → `OceanaApp` → `OceanaShell` (MT5 `MainShell` / drawer no longer used as home).
