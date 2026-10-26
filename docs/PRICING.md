# RxBridge pricing architecture — Iran-first (2026-10-26)

## Research and source hierarchy
Iran FDA TTAC (https://ttac.ir) is identified by Iran FDA officials as the official current consumer drug-price reference. Public reporting in 1405 notes that package-printed prices may differ, with nuanced rules governing marked packages; the software must not decide legal precedence without an up-to-date validated ruleset.
- https://www.tasnimnews.ir/fa/news/1405/03/09/3603454/
- https://www.tasnimnews.ir/fa/news/1405/03/30/3621626/
- https://www.tasnimnews.ir/fa/news/1405/03/06/3601189/

These are contextual media reports, **not API documentation or a substitute for formal legal review**. No sanctioned real-time API access verified for RxBridge.

## Current implementation (v0.1.1)
Static web demo with quantity x manual price (integer IRR), optional purchase-cost display and an **explicitly unverified** insurance contribution input. Patient remainder = gross - user-entered simulated contribution. No official price lookup, no actual dispensing/billing, no insurance adjudication or professional fees. Data kept only in page memory.

## Production domain model
- DrugProduct: catalog identity, IRC/GTIN if available, product strength/form/package_size/unit, manufacturer.
- PriceRecord: product_id, amount_minor_units, currency=IRR, price_kind [official_consumer, purchase, negotiated], unit_basis [each, pack], pack_multiplier, jurisdiction, source_name, source_uri, acquired_at, effective_from/to, verification_status, import_batch, reviewer_id.
- PurchaseLot: organization_id, supplier, invoice, inventory SKU, amount, discounts, taxes when applicable, lot and expiry, effective cost (NOT public official price).
- PrescriptionCharge: product_id, quantity_dispensed, applicable_approved_unit_price, overrides separately audited, total, charge_snapshot.
- InsuranceEstimate vs InsuranceAdjudication: payer identifier, plan, coverage eligibility response, copay, deductible, supplement, tariff, signed official response and time; never interchange estimates and official decisions.
- CompoundCharge: ingredients with concentrations and yields, material cost, validated fee schedule, packaging, waste and explicit approval.
- AuditEvent: actor, source, before/after values, reason, timestamps and signatures; immutable append-only.

## Required safety and financial controls
1. Normalize amount to integer rial, avoid JS float arithmetic in production; explicit conversions between toman/rial.
2. Never present unverified manual price as official; source age, pack/each basis and price status always visible.
3. Official-price overrides cannot bypass legal price ceilings through mere checkbox confirmation.
4. No hardcoded percentages for insurance reimbursement, discount, pharmacy fee or VAT. Get payer-specific adjudication and current signed fee/tariff rules.
5. Price history immutable with temporal validity and reconciliation for price changes between writing and dispensing.
6. Separate patient copay, insurer obligations, discounts, professional fees, purchase cost and gross total.
7. Pharmacy substitutions need independent clinical authorization and corresponding official price.
8. Enforce provenance, product identity, audit, permission boundaries, encrypted PHI and retention requirements.

## Delivery phases
- v0.1.1 DONE: demo standalone estimate (test-only identifiers)
- v0.2 PLANNED: Android Flutter pricing view + navigation/about
- v0.3 PLANNED: domain schema and unit/pack rules with automated tests
- v0.5 PLANNED: sourced data ingestion from authorized feeds, reviewer workflow
- v0.6 PLANNED: inventory and purchasing support
- v0.8 PLANNED: authorized insurance adapter and payer evaluation
- v0.9+ PLANNED: security, reconciliation, compliance, pharmacist validation and production testing

## Test scenarios for implementation
- Quantity 3, unit price 1000 IRR, simulated insurance 500 -> gross 3000, remainder 2500.
- Insurance > gross blocks calculation.
- Negative, fractional, blank, non-safe-integer values reject.
- Manual source without rationale rejects.
- Non-TEST product identifier rejects in demo mode.
- Input edits invalidate previous result; page reload clears calculations.

No real pricing or clinical use until formal validation.
