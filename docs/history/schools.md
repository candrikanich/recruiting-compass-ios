# Schools History

## 2026-08-12 — Visited Card Real Visits
Cross-platform fix: "Visited" stat card now counts real visit interactions/events instead of wrong status values. Both web and iOS.

## 2026-08-12 — iOS Personal Fit Signals
Design + implementation plan to replace dead numeric fit score with web-parity Personal Fit signals (Location/Size/Cost) computed on-device. Pure calculator + UI (detail cards, tile pill, list filter). Academic Fit deferred.

## 2026-08-08 — iOS Distance from Home Design
Design to fix iOS school detail distance-from-home: read from user_preferences instead of dead family_units columns.

## 2026-08-13 — iOS School Fit (Academic Fit)
Added an Academic Fit section (SAT/ACT vs percentile ranges) beside Personal Fit, plus an enrich-endpoint lookup for schools lacking range data.

## 2026-08-12 — Schools "Contacted" stat card
Added a 4th "Contacted" stat card to the iOS Schools page (2×2 grid), a web-parity `status === "contacted"` count derived from loaded schools. Shipped.

## 2026-08-08 — iOS Distance from Home
"Distance from Home" on school detail/list reads home coords from `user_preferences` with a web-parity haversine calculation and a set-home CTA.
