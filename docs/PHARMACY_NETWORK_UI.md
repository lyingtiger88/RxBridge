# Pharmacy network workspaces — UI design slice

Two role-specific interfaces have been added to the Flutter staging portal.

## Pharmacy operator workspace
File: `apps/mobile/lib/pharmacy_network_pages.dart`
- Overview dashboard with stock counts and publication readiness checklist.
- Inventory and price list with search, add-item dialog, stock and price editing.
- Pharmacy profile with name, address, map-location placeholder, and publication control.
- UI uses synthetic sample inventory only. Changes stay in widget memory and are not sent to Supabase.

## Patient pharmacy finder
- Selected-prescription summary.
- Map-style preview with pharmacy pins and coverage labels.
- Pharmacy result cards show coverage percentage, distance, inventory freshness, and price.
- Sort by coverage/price, lowest displayed basket subtotal, or distance.
- Filter to pharmacies with 100% coverage.
- Partial-basket prices are explicitly labelled as the subtotal of available items and are not presented as the full prescription total.
- Reservation action is a disabled-by-backend demonstration notice; it does not create a reservation.

## Integration
- Staging portal renders the pharmacy operator workspace for `pharmacist` accounts.
- Staging portal renders the patient pharmacy finder for `patient` accounts.
- Existing prescription and habit panels remain in place.

## Explicitly not implemented by this UI slice
- Live map SDK, geocoding, current patient location permission, and verified pharmacy coordinates.
- Supabase repository methods for pharmacy profile and inventory writes/reads.
- Live prescription-to-inventory matching and authoritative availability.
- Stock locking, reservation, pharmacy confirmation, payment, or fulfilment.
- Real pharmacy identity/license verification.

The map pins, pharmacy names, prices, availability, and distance shown in this interface are illustrative synthetic values. They must not be represented as live pharmacy data. No build was run.
