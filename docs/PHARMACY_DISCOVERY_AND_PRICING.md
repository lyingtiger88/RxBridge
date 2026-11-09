# Pharmacy discovery, stock coverage and price comparison

## Product behavior
- Each pharmacy registers a separate business profile tied to an authenticated pharmacist account.
- The profile includes pharmacy name, address, city/province, map coordinates, optional license number, reservation support, and a publication state.
- The pharmacy location is a public business location. Patient coordinates are requested only after an explicit location permission and are passed transiently to the matching RPC; they are not persisted by this feature.
- A pharmacy cannot publish until its location is marked verified and its public identity/address are complete.
- Each pharmacy maintains its own inventory and price list. Inventory records include a canonical medicine key, name, pharmaceutical form, strength/package descriptors, stock quantity, unit price in IRR, and stock/price update timestamps.
- The canonical medicine key must identify the exact medicine/strength/pack. Do not map a prescribed product to a generic or alternative product automatically. Any substitution requires the applicable prescriber/pharmacist workflow and Iranian regulatory rules.

## Matching and ranking
- The patient selects one or more active prescriptions.
- Search uses the selected prescriptions, the patient's one-time location coordinates, and a radius (default 20 km; maximum 100 km).
- Coverage is the number of selected prescription line items for which a matching inventory row has stock at least equal to the prescribed quantity, divided by selected line items. The UI can show e.g. 100%, 70%, etc.
- A complete basket total is returned only when every selected item is available. Partial baskets show an available-item subtotal only; do not compare it as if it were the price of the full prescription.
- Results are ordered by complete availability first, then item coverage, then lowest complete-basket total, then distance. The UI should also expose distance and price/stock freshness so patients can choose an economical and convenient option.
- Prices are pharmacy-reported and can change. Display last update time and require reconfirmation by pharmacy before reservation/dispensing. No price is guaranteed until confirmed.
- Availability is a snapshot and can race with another sale. Reservation must atomically recheck stock before promising the items.

## Security and privacy
- Pharmacy profiles and published stock/prices are visible to authenticated app users.
- Pharmacy staff can edit only the profile and inventory belonging to their own account.
- Search RPC requires the authenticated patient to own the patient record and selected active prescriptions.
- Patient coordinates are not returned or stored by this search function.
- Do not show patient name, medical record, or prescription details to pharmacies merely because their inventory is listed. A separate patient-authorized reservation/fulfilment workflow must grant the selected pharmacy access to the minimum necessary prescription information and log the access.
- Only synthetic data in staging. Production requires a security review, pharmacy identity/license verification, price governance, and legal/regulatory review for Iran.

## Database migration
Apply `infra/supabase/migrations/0006_pharmacy_discovery_inventory.sql` after migrations 0001–0005.
It creates `pharmacies`, `pharmacy_inventory`, owner-scoped RLS policies, and `find_pharmacies_for_prescriptions(...)`.

## Not yet complete
The migration/backend data model is the first implementation slice. The pharmacy onboarding and inventory management screens, patient map/list UI, map provider integration, canonical medicine catalog, price verification, and stock reservation/checkout workflow remain to be implemented. No builds were run.
