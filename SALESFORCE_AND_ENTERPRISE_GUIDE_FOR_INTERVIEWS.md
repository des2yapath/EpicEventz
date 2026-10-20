# EpicEventz 360: The Beginner-to-Interview Salesforce & Enterprise Guide

> **Who is this for?**  
> If you have an interview or project evaluation tomorrow, haven't spent months learning Salesforce, and need to explain *exactly* what was built, how each technology works, and why it was designed this way—**this guide is for you.**
>
> Written in plain English using real-world analogies, with the exact technical buzzwords you need to impress engineering judges.

---

## Table of Contents
1. [The 30-Second Elevator Pitch (Memorize This)](#1-the-30-second-elevator-pitch-memorize-this)
2. [What is Salesforce Really? (The Layman's Analogy)](#2-what-is-salesforce-really-the-laymans-analogy)
3. [Module 1: The Data Foundation (Objects, Fields & Relationships)](#module-1-the-data-foundation-objects-fields--relationships)
4. [Module 2: Frontend UI (Lightning Web Components - LWC)](#module-2-frontend-ui-lightning-web-components---lwc)
5. [Module 3: The Backend Brains (Apex & Domain Services)](#module-3-the-backend-brains-apex--domain-services)
6. [Module 4: Integrations & Headless API (Apex REST)](#module-4-integrations--headless-api-apex-rest)
7. [Module 5: Background Batch & Self-Healing (Batch Apex)](#module-5-background-batch--self-healing-batch-apex)
8. [Module 6: Security, Roles & Governor Limits](#module-6-security-roles--governor-limits)
9. [Module 7: How EpicEventz Connects to SAP / ERP Concepts](#module-7-how-epiceventz-connects-to-sap--erp-concepts)
10. [Cheat Sheet: "How Do I Answer If Asked About..." (Interview Scenarios)](#cheat-sheet-how-do-i-answer-if-asked-about-interview-scenarios)

---

## 1. The 30-Second Elevator Pitch (Memorize This)

If the interviewer asks: **"What did you build in this project?"**

> *"We built **EpicEventz 360**, an enterprise event operations and ticketing platform hosted on Salesforce Core.  
> Most event companies are broken into two disconnected worlds: a consumer ticketing app that crashes during high-traffic drops, and messy spreadsheets for backstage vendor contracts and stage tasks.  
> We unified both on Salesforce:  
> 1. **Front-of-house:** High-concurrency ticket sales, dynamic pricing, and turnstile gate check-in preventing duplicate barcodes.  
> 2. **Back-of-house:** Real-time budget variance formulas, vendor contract rollups, and run-of-show task management.  
> 3. **The 'Hero' Recovery Loop:** An autonomous service engine that detects 1-star negative feedback and instantly creates a high-priority Case and action Task to rescue the attendee relationship before they even leave the venue."*

---

## 2. What is Salesforce Really? (The Layman's Analogy)

* **Think of Salesforce not just as a CRM, but as an Enterprise Cloud Operating System.**
* It gives you:
  1. A relational SQL database (called **Objects** instead of Tables).
  2. A backend coding language like Java (called **Apex**).
  3. A modern frontend reactive web framework (called **Lightning Web Components** or **LWC**).
  4. An out-of-the-box user interface with navigation bars, search, mobile apps, and security permissions.
* **Why build on Salesforce instead of a generic MERN/Django stack?**  
  Because in an enterprise, customer data, money, vendor contracts, support tickets (Cases), and automated workflows are already in Salesforce. Building natively means zero sync lag, zero third-party webhook costs, and enterprise-grade security out of the box.

---

## 3. Module 1: The Data Foundation (Objects, Fields & Relationships)

### What is an Object in Salesforce?
* An **Object** is just a database table.
* **Standard Objects:** Tables Salesforce gives you for free (`Account`, `Contact`, `Case`, `Task`).
* **Custom Objects:** Tables you create yourself. In Salesforce, all custom objects end with `__c` (which stands for *"custom"*).

### The Objects We Built & Used:
| Object Name | Layman's Explanation | Why We Have It |
| :--- | :--- | :--- |
| `Account` *(Standard)* | Companies / Organizations | We use Record Types to categorize Accounts into `Corporate Host`, `Vendor Company`, and `Talent Agency`. |
| `Contact` *(Standard)* | Real human beings | We categorize Contacts into `Fan Attendee`, `Artist / Talent`, and `Vendor Staff`. Has custom fields like `VIP_Tier__c`. |
| `Event_Project__c` | The Master Operational Project | The master spreadsheet for an event (e.g., *Tech Convergence 2026*). Tracks total budget, venue capacity, and dates. |
| `Ticket_Tier__c` | Ticket Categories & Pricing | Tracks VIP vs General Admission, ticket price, total inventory, and how many are sold. |
| `Booking_Order__c` | Financial Purchase Order | When a customer buys tickets, this records total amount paid, payment status, and buyer information. |
| `Ticket_Pass__c` | The Actual Individual Ticket | If you buy 3 tickets, 1 `Booking_Order__c` is created, and 3 `Ticket_Pass__c` records are issued, each with a unique cryptographic QR token. |
| `Vendor_Contract__c` | Backstage Supplier Agreement | Tracks contracts for sound, stage lighting, catering, or security, including advance payments and balance due. |
| `Operational_Task__c` | Backstage Run-of-Show Task | Production checklists: "Audio soundcheck by 2 PM", "Security barricade inspection". |
| `Sub_Session__c` | Multi-track stage agenda | Keynote speeches, breakout workshops, artist performances. |
| `Feedback_Intelligence__c` | Attendee Reviews & Ratings | Collects 1-to-5 star ratings and written reviews from attendees. |
| `Payment__c` | The Money Ledger | Financial audit log tracking amount, gateway transaction ID, and **Idempotency Key**. |
| `Log__c` | System Health & Diagnostics | Diagnostic log recording errors, execution speeds, and correlation IDs with zero PII leaks. |
| `Case` *(Standard)* | Customer Support Ticket | Automatically created whenever an attendee leaves a 1- or 2-star review! |
| `Task` *(Standard)* | Follow-up To-Do Item | Automatically assigned to the event manager to resolve the unhappy attendee's Case within 24 hours. |

---

### Crucial Concept: Master-Detail vs. Lookup Relationships
*This is the #1 question Salesforce interviewers love to ask!*

1. **Master-Detail Relationship (Tight Coupling / Parent-Child):**
   * *Analogy:* An order and its line items. If you delete the order, the line items have no reason to exist.
   * **Rule 1:** Child cannot exist without the parent. If parent is deleted, all children are automatically deleted (Cascade Delete).
   * **Rule 2:** Security is inherited from parent.
   * **Rule 3 (The Superpower):** Enables **Roll-up Summary fields**. The parent can automatically calculate `SUM()`, `COUNT()`, or `MAX()` of child records without writing a single line of code!
   * *Where we used it:* `Ticket_Tier__c` &rarr; `Event_Project__c` (so the project can automatically sum up total allocated seats), and `Vendor_Contract__c` &rarr; `Event_Project__c` (so the project automatically calculates `Total_Contracted_Spend__c`).

2. **Lookup Relationship (Loose Association / Reference):**
   * *Analogy:* A student and a library book. If the book is returned or deleted, the student still exists.
   * Parent and child are independent. Deleting parent does *not* delete child.
   * *Where we used it:* `Booking_Order__c` &rarr; `Event_Project__c`.  
   * **Why did we use Lookup here instead of Master-Detail?**  
     *(Interview Gold)*: In Salesforce, when you insert records under a Master-Detail parent, Salesforce locks the parent record. If 1,000 fans buy tickets at the exact same second, a Master-Detail relationship would lock `Event_Project__c`, causing all other checkouts to crash! Making `Booking_Order__c` a Lookup prevents parent locking bottlenecks.

---

### Formula Fields vs. Roll-Up Summaries
* **Roll-up Summary:** Calculates math across *multiple child records* and saves the answer on the parent (e.g., `SUM(Contract_Amount__c)` on all vendor contracts).
* **Formula Field:** Calculates math dynamically on a *single record*, like an Excel formula. It never takes up database storage space and calculates on-the-fly when viewed.
  * *Example in our project:*  
    `Budget_Variance__c` = `Total_Budget_Allocated__c - Total_Contracted_Spend__c`  
    `Remaining_Budget_Health__c` = `IF(Budget_Variance__c >= 0, "Healthy", "Critical Overrun")`

---

## 4. Module 2: Frontend UI (Lightning Web Components - LWC)

### What is an LWC?
* **LWC (Lightning Web Component)** is Salesforce's modern frontend framework.
* It uses standard modern web technologies:
  * **HTML** for the skeleton/structure.
  * **CSS** (with Salesforce Lightning Design System / SLDS) for styling.
  * **JavaScript (ES6+)** for reactive state and user actions.
* Think of it exactly like **React** or **Vue**, but deeply integrated into Salesforce security and database APIs.

### The Two Core LWCs We Built:

#### 1. `eventExplorer` (Consumer Discovery Portal)
* **What it looks like:** An Airbnb or BookMyShow-style event catalog.
* **How it works:**
  * **Instant In-Memory Search:** When the user types or clicks filter pills (*"Tech Conference"*, *"Music Festival"*), JavaScript filters the displayed cards instantly without waiting for a server reload.
  * **Debounced SOSL:** If searching through thousands of records, it uses a 300ms debounce timer (waits until user stops typing) and sanitizes special characters to prevent search crashes.
  * **Dynamic Price Floor:** Calculates the lowest active ticket tier (`"Price From ₹1,500"`), automatically ignoring sold-out tiers.
  * **Sliding Drawer:** Clicking an event opens a smooth slide-out modal showing live seat inventory and venue specs.

#### 2. `checkinConsole` (Turnstile Door Scanner)
* **What it looks like:** An airport gate or concert turnstile scanner app.
* **How it works:**
  * Gate staff enter or scan the attendee's QR token (`PASS-TOKEN-DEMO-VIP-002`).
  * Calls backend Apex in real time.
  * **If valid:** Returns **Green Badge** with attendee name, VIP tier, and table/seat assignment.
  * **If scanned a second time:** Instantly returns **Red Refusal Badge**: *"Entry Refused: Ticket was already checked in at [Timestamp]. Duplicate entry prevented."*
  * **Live Audit Feed:** The right panel maintains a rolling live feed of the last 10 scans so guards can verify identity.

---

## 5. Module 3: The Backend Brains (Apex & Domain Services)

### What is Apex?
* **Apex** is Salesforce's backend programming language.
* It looks and feels almost identical to **Java** or **C#**.
* It runs directly on Salesforce servers (server-side) and has built-in database queries called **SOQL** (*Salesforce Object Query Language*).

### Separation of Concerns (SOC) Architecture
Instead of dumping code randomly inside triggers or buttons, we structured the backend into clean enterprise architectural layers:
```
[ Frontend: LWC UI ]
        ↓ (@AuraEnabled calls)
[ Adapter Layer: Controllers (EevCheckinController, EevEventExplorerController) ]
        ↓ (Input sanitation, exception handling)
[ Domain Service Layer: Pure Business Logic ]
   ├── EevInventoryService (Concurrency & Inventory)
   ├── EevCheckoutService (Money Ledger & Pass Issuance)
   ├── EevTicketService (Validation & Gate Refusal)
   └── EevFeedbackService (AI Sentiment & Autonomous Recovery)
        ↓ (DML & DB Transactions)
[ Database / Persistence: Custom & Standard Objects ]
```

---

### The 4 Core Engineering Patterns (Explain These with Pride!)

#### 1. Concurrency Control via Compare-and-Swap (CAS)
* **Class:** [`EevInventoryService.cls`](file:///force-app/main/default/classes/EevInventoryService.cls)
* **The Problem:** In a flash sale (e.g., 50 VIP tickets open to 10,000 fans), 1,000 people click "Buy" at the exact same millisecond. If your code reads `ticketsRemaining = 1` and sells to all of them, you have oversold 1,000 tickets!
* **Traditional bad solution:** `SELECT ... FOR UPDATE` (Pessimistic Locking). In Salesforce, locking a record for more than 5 seconds throws an uncatchable error (`UNABLE_TO_LOCK_ROW`) and crashes the app.
* **Our Solution (Optimistic Locking):**
  1. Read current inventory.
  2. Verify `capacity - sold >= requested`.
  3. Perform atomic conditional update: `tier.Sold_Count__c += qty`.
  4. If inventory was depleted mid-flight, throw an exception and rollback. No database locks held, sub-millisecond execution!

#### 2. Distributed Idempotency (Replay Protection)
* **Class:** [`EevCheckoutService.cls`](file:///force-app/main/default/classes/EevCheckoutService.cls)
* **The Problem:** An attendee clicks "Pay Now". The payment gateway captures their money, but the mobile network drops before the confirmation screen renders. The attendee taps "Pay Now" again. Did they just get charged twice?
* **Our Solution:** Every checkout sends a client-generated UUID called an **Idempotency Key** (`req.idempotencyKey`).
  * Before charging or deducting inventory, the system queries `Payment__c` for that key.
  * If found, it immediately stops, does not double-charge, and returns the previous successful order confirmation with `isReplay = true`.

#### 3. The Autonomous "Hero" Service Recovery Loop
* **Class:** [`EevFeedbackService.cls`](file:///force-app/main/default/classes/EevFeedbackService.cls)
* **The Problem:** An attendee has a terrible experience (microphone cuts out, 45-minute drink line) and gives a 1-star review. In most companies, this review sits in an unread database table for weeks while the attendee vents angrily on Twitter/LinkedIn.
* **Our Solution:**
  1. The moment a 1- or 2-star review is submitted, `EevFeedbackService` kicks in.
  2. Evaluates text sentiment heuristically (e.g., words like *"broken"*, *"terrible"*, *"queue"*, *"failed"*).
  3. Categorizes the issue (`Audio/Visual`, `Facilities`, `Catering`).
  4. **Instantly creates a High-Priority `Case`** in Salesforce.
  5. **Instantly assigns an executive `Task`** to the event manager due within 24 hours to contact and recover the customer.

#### 4. Zero-PII Structured Observability
* **Class:** [`EevLogger.cls`](file:///force-app/main/default/classes/EevLogger.cls)
* **The Problem:** GDPR, HIPAA, and SOC2 laws strictly forbid storing customer email addresses or personal passwords in diagnostic log tables.
* **Our Solution:** Every log message passes through an automated Regex sanitizer (`maskPII`) that converts `alex.riviera@example.com` into `a***a@example.com`. Every transaction also carries a random `Correlation_ID__c` so distinct events can be traced across asynchronous boundary contexts.

---

## 6. Module 4: Integrations & Headless API (Apex REST)

### What is an Apex REST API?
* **Class:** [`EevOrderRestResource.cls`](file:///force-app/main/default/classes/EevOrderRestResource.cls)
* What if a third-party mobile app, an external event website, or a Postman integration needs to book tickets into Salesforce without using the Salesforce UI?
* By annotating an Apex class with `@RestResource(urlMapping='/epiceventz/v1/orders/*')`, Salesforce automatically generates a public, secure REST API!
* **Method:** `POST /services/apexrest/epiceventz/v1/orders`
* It accepts JSON, creates or matches the buyer `Contact`, routes through `EevCheckoutService`, validates idempotency, issues tickets, and returns JSON with HTTP 200.

---

## 7. Module 5: Background Batch & Self-Healing (Batch Apex)

### What is Batch Apex?
* **Class:** [`EevInventoryReconciliationBatch.cls`](file:///force-app/main/default/classes/EevInventoryReconciliationBatch.cls)
* In Salesforce, you cannot update 50,000 records in one regular synchronous transaction because of multi-tenant **Governor Limits**.
* **Batch Apex** allows you to process millions of records asynchronously in small chunks (e.g., 200 records at a time) in the background.

### Why Do We Have It? (The Self-Healing Engine)
* Over weeks of production operations, manual admin edits, test records, or cancelled orders might cause the number on `Ticket_Tier__c.Sold_Count__c` to drift away from the true count of actual `Ticket_Pass__c` records.
* This batch runs automatically on a nightly schedule (implements `Schedulable`).
* It audits every ticket tier, counts the true issued passes, repairs any discrepancy back to ground truth, and writes an audit log in `Log__c`.

---

## 8. Module 6: Security, Roles & Governor Limits

### 1. What are Governor Limits?
* *Analogy:* Salesforce is like an apartment building where all tenants share the same water pipe and electricity. To prevent one noisy tenant from using all the water and starving everyone else, Salesforce enforces strict limits per transaction:
  * Maximum 100 SOQL database queries per transaction.
  * Maximum 150 DML statements (insert/update).
  * Maximum 10 seconds of CPU execution time.
* **Our Code Quality:** Every service in EpicEventz is bulkified, uses collections (`List`, `Map`), and runs in under 5 SOQL queries per transaction, safely using less than 5% of allowable limits.

### 2. User-Mode Security (`WITH USER_MODE`)
* When writing Apex queries or DML, running in system mode ignores user permissions.
* We enforce `WITH USER_MODE` and `AccessLevel.USER_MODE` across queries and updates.
* This guarantees that a standard attendee cannot view VIP vendor contracts or tamper with prices, strictly adhering to Salesforce's latest 2026 security standards.

### 3. Profiles vs. Permission Sets
* **Profile:** A user's baseline identity (e.g. `System Administrator`). Each user has exactly one profile.
* **Permission Set (`PS_Event_Admin`, `PS_Attendee`):** Add-on badges that grant specific object, field, or tab permissions without changing the user's main profile.

---

## 9. Module 7: How EpicEventz Connects to SAP / ERP Concepts

If the interviewer asks: **"How does this relate to SAP or Enterprise ERP systems?"**

You can explain how our Salesforce architecture directly mirrors standard SAP ERP enterprise modules:

| SAP ERP Module | What SAP Does | How EpicEventz 360 Handles It |
| :--- | :--- | :--- |
| **SAP SD** *(Sales & Distribution)* | Manages customer orders, product pricing, delivery fulfillment. | Handled by `Ticket_Tier__c`, `Booking_Order__c`, and `Ticket_Pass__c`. Employs dynamic price floors and automated order fulfillment. |
| **SAP MM** *(Materials Management)* | Manages inventory, stock levels, warehouse reservations, and purchasing. | Handled by `EevInventoryService`. Manages real-time ticket inventory and prevents overselling using Compare-and-Swap algorithms. |
| **SAP FI/CO** *(Financial Accounting & Controlling)* | Tracks accounts payable/receivable, ledgering, cost centers, budget variances. | Handled by `Payment__c` (ledger) and `Vendor_Contract__c`. Formula fields compute `Budget_Variance__c` and `Balance_Due__c` in real time. |
| **SAP PM / PP** *(Plant Maintenance / Production Planning)* | Production run-sheets, staging equipment setup, operational checklists. | Handled by `Operational_Task__c` and `Sub_Session__c` tracking run-of-show readiness. |
| **SAP QM** *(Quality Management)* | Inspects service failures, customer defect reports, corrective actions. | Handled by `Feedback_Intelligence__c` and the **Hero Recovery Loop** (auto-escalating defects into high-priority Cases). |

---

## 10. Cheat Sheet: "How Do I Answer If Asked About..." (Interview Scenarios)

### Scenario 1: "Why did you build this on Salesforce instead of MERN/Python?"
> *"Building on Salesforce gives us an enterprise-grade relational database, identity management, standard CRM objects like Cases and Accounts, and mobile accessibility out of the box. Instead of writing custom microservices for customer support, billing ledgers, and role-based access, we built natively on Salesforce Core, achieving zero integration lag and enterprise compliance."*

### Scenario 2: "What was the hardest technical challenge in this project?"
> *"Handling high concurrency and race conditions during flash ticket sales. In Salesforce, you can't use traditional table locks without risking `UNABLE_TO_LOCK_ROW` exceptions that crash transactions under load. We solved this by implementing an optimistic locking Compare-and-Swap pattern in `EevInventoryService` coupled with an idempotency key guard in `EevCheckoutService` to eliminate duplicate payment processing."*

### Scenario 3: "How do you prevent duplicate tickets at the gate?"
> *"Every ticket pass is minted with an unguessable 128-bit cryptographic MD5 token. When scanned in the `checkinConsole` LWC, `EevTicketService` verifies that `Status__c == 'Valid'`. The first scan atomically timestamps the record and changes the status to 'Checked In'. If the same barcode or a screenshot is scanned a second time, the check fails and immediately renders an operational refusal banner explaining the exact prior check-in time."*

### Scenario 4: "Tell me about a feature that demonstrates AI or automation."
> *"Our 'Hero' Autonomous Recovery Loop. In event management, unhappy attendees vent online before organizers can react. When a 1- or 2-star feedback is submitted, `EevFeedbackService` uses natural language heuristic scoring to classify sentiment as negative, tags the problem area (like Audio/Visual or Catering), auto-spawns a High-Priority Case, and schedules an executive action Task due within 24 hours. This transforms customer churn into immediate service recovery."*

### Scenario 5: "How did you test your project?"
> *"We wrote comprehensive unit tests in `EevComprehensiveTest` and `EevEventExplorerControllerTest` covering all services, controllers, and edge cases (concurrency limits, duplicate replay, check-in refusal, drift repair). The suite achieves a **100% pass rate across 17 tests** with **87% org-wide code coverage**, exceeding Salesforce's 75% production standard."*
