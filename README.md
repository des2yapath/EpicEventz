# EpicEventz 360

> **Unified High-Concurrency Event Operations, Discovery & Ticketing Platform built on Salesforce Core.**

EpicEventz 360 unifies front-of-house attendee experiences (event discovery, dynamic pricing, and gate check-in) with back-of-house event production operations (event projects, vendor contracts, operational tasks, and sub-sessions) on Salesforce.

---

## Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                           EPICEVENTZ 360 PLATFORM                              │
├─────────────────────────────────────┬──────────────────────────────────────────┤
│        FRONT-OF-HOUSE (ATTENDEE)    │       BACK-OF-HOUSE (OPERATIONS)         │
│  • Event Explorer (Discovery LWC)   │  • Event Projects & Budget Rollups       │
│  • Gate Check-in Scanner LWC        │  • Vendor Contracts & SLA Tracking       │
│  • Dynamic Tiered Pricing           │  • Operational Stage & Run Tasks         │
│  • Cryptographic QR Ticket Passes   │  • Multi-Track Sub-Sessions              │
├─────────────────────────────────────┴──────────────────────────────────────────┤
│                          AUTONOMOUS ENGINES & LOGIC                            │
│  • Hero Recovery Loop: Auto-converts 1-2★ feedback to High-Priority Case & Task │
│  • Concurrency Engine: Compare-And-Swap (CAS) prevents overselling at drop time│
│  • Money Ledger: Idempotent checkout preventing duplicate charges on drop      │
│  • Self-Healing: Nightly batch repairing inventory counter drift               │
│  • Observability: Structured logging, correlation IDs, automated PII masking  │
│  • Headless REST API: POST /services/apexrest/epiceventz/v1/orders             │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start (Deployment to Any Salesforce Org)

If you are a teammate or judge deploying this to your own Trailhead Playground or Developer Edition org:

### 1. Authenticate your Salesforce Org (if not already authenticated)
```bash
sf org login web --set-default
```

### 2. Deploy Metadata
```bash
sf project deploy start
```

### 3. Seed Demo Data
```bash
# Seed Events, Venues, and Ticket Tiers
sf apex run --file scripts/seed.apex

# Seed Demo Orders, QR Passes, Payment Ledger & AI Feedback
sf apex run --file scripts/seed_passes.apex
```

### 4. Launch EpicEventz 360
```bash
sf org open -p "lightning/app/c__EpicEventz_360"
```

---

## 🧪 Demo Scenarios

### 1. Real-Time Gate Check-In & Double-Entry Refusal
* Open the **Checkin Console** tab (`/lightning/n/Checkin_Console`).
* Paste the active pass token: `PASS-TOKEN-DEMO-VIP-002` and click **Validate & Check In**.
  * **Result:** Green badge admits `Sean Forbes` to `VIP` at `Table A - Seat 2`.
* Click **Validate & Check In** a second time.
  * **Result:** Instant Red refusal badge: *"Entry Refused: Ticket was already checked in. Duplicate entry prevented."*

### 2. Attendee Discovery & Dynamic Pricing
* Open the **Event Explorer** tab (`/lightning/n/Event_Explorer`).
* Search for *"Convergence"* or filter by *"Tech Conference"*.
* Dynamic price floor shows *"Price From ₹1,500"*. Click the event card to open the slide-out drawer with live tier availability.

### 3. The "Hero" Autonomous Service Recovery Loop
* Open the **Feedback Intelligence** tab (`/lightning/o/Feedback_Intelligence__c/list`).
* Create a review with `Rating = 1` or `2` (e.g., *"Keynote sound system failed and check-in queues took 45 minutes"*).
* Save the record.
  * **Autonomous Action:** AI heuristic classifies sentiment as `Negative`, categorizes topic as `Audio/Visual`, auto-creates a **High-Priority Case** (`standard-Case`), and assigns a **Next-Day Action Task** (`standard-Task`) to the event manager.

### 4. Enterprise Observability & Security
* Open the **Logs** tab (`/lightning/o/Log__c/list`).
* Every checkout, reservation, and check-in shares a unique **Correlation ID** for end-to-end tracing.
* Attendee emails are masked (e.g. `s***s@example.com`) to prevent PII exposure.

---

## 📊 Apex Unit Tests & Code Coverage
* **Tests Ran:** 17
* **Pass Rate:** 100% (17 / 17 Passed)
* **Org-Wide Code Coverage:** 87% (Exceeds Salesforce 75% standard)
* Run tests locally:
  ```bash
  sf apex run test --test-level RunLocalTests --code-coverage --result-format human
  ```
