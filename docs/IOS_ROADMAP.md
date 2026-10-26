# RxBridge iOS roadmap

**Status:** iOS is now an explicitly supported target platform in the product plan. No iOS binary, Xcode project, or IPA has been built yet.

## Approach
Use **one Flutter/Dart mobile workspace** in `apps/mobile` with platform targets `android/` and `ios/`. Keep the existing static web proof-of-concept separate until it is migrated. Share UI models, localization, prescription data validation, custom-entry reconfirmation, pharmacy workflow and pricing estimate logic; keep security-sensitive checks server-side.

## App sections
- Role-based home and simulated prescription workflow
- Drug dosage form, route, frequency, instructions, and explicit custom-field confirmation
- Simulated pricing (IRR), product/pack units, unverified insurance estimate clearly labelled
- About: product overview, version, release status, roadmap, privacy and safety disclosures
- Accessibility: Dynamic Type, VoiceOver, sufficient touch target sizes, RTL Persian and English

## Planned milestones
| Version target | iOS work | Exit condition |
| --- | --- | --- |
| 0.2.0 | Flutter project, Cupertino-adaptive interface, navigation, About screen, simulator setup | iOS simulator debug build and widget tests |
| 0.3.0 | Prescription editor, custom field review/invalidation, demo state | Confirm edits invalidate prior confirmation; unit tests |
| 0.4.0 | Authorized identity and test API client | Token storage in Keychain; role boundary tests |
| 0.5.0 | Versioned medication catalog and safeguards | Product-specific constraints; pharmacist review of rule tests |
| 0.6.0 | Pricing and inventory foundation | Provenance & integer-IRR arithmetic tests; no invented official prices |
| 0.9.0 | QA: iPhone layouts, VoiceOver, dynamic fonts, RTL, security | QA gate / no release blockers |
| 1.0.0 | TestFlight and App Store readiness | Certificates, profiles, privacy disclosures, legal and clinical review |

## Build & release
- Requires macOS, supported Xcode, Flutter SDK, CocoaPods as applicable and Apple signing credentials for device/TestFlight distribution.
- Example after workspace bootstrap: `flutter create --platforms=android,ios apps/mobile`; `cd apps/mobile && flutter pub get && flutter test && flutter build ios --simulator`.
- Production archive: Xcode signing, bundle ID, provisioning profiles, privacy manifest if required by integrated SDKs, App Store Connect setup; TestFlight before external distribution.
- Do not claim an IPA is ready without an actual signed successful archive.

## Safety / privacy
No real patient data in demo builds. Avoid cleartext logging, use TLS and Keychain for secrets, and enforce server-side authorization. User acknowledgment of a custom field never substitutes for pharmacist/clinical review. No real insurance or national prescribing integration without approval.
