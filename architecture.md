# Architecture Model

> Explains the architecture shown in the **UML Component Diagram** (`component_diagram.pu`) and the reasons for the architectural patterns we chose. Consistent with the requirements and use cases of Submission 1.

## 1. Overview

The TurbineH Invoicing & Subscription System follows a **client-server** model with a **layered (N-tier) architecture** on the server:

```
 User device         ┌──────────────────────────────────────────────┐
 (web / mobile) ───► │ Presentation layer   REST API + Webhooks     │
                     ├──────────────────────────────────────────────┤
                     │ Business layer       Services (use cases)    │
                     ├──────────────────────────────────────────────┤
                     │ Data access layer    Repositories            │
                     ├──────────────────────────────────────────────┤
                     │ Integration layer    Adapters (Email,        │
                     │                      WhatsApp, Stripe)       │
                     └───────────┬───────────────────┬──────────────┘
                                 ▼                   ▼
                          MySQL database      External services
```

Each layer only uses the layer directly below it (or the integration layer, for the services that talk to external systems). For example, a controller never accesses the database directly.

## 2. Components

| Layer | Component | Responsibility | Use cases / requirements |
| --- | --- | --- | --- |
| Client | Web Client (responsive SPA) | User interface for Employee, Administrator and Superadministrator. One responsive application for desktop, tablet and mobile. | NFR-02, NFR-01 |
| Presentation | REST API (Controllers) | Receives HTTPS/JSON requests, calls `IAuthorization` (UC-18) on every request and delegates to the business layer. | All |
| Presentation | Webhook Endpoints | Receives events from Stripe (payments) and from the messaging providers (delivery status). | UC-16, UC-15 |
| Business | Auth & Permissions | Sign-in, sessions and role / client-scope checks. | UC-18, FR-01, FR-02 |
| Business | Invoicing | One-off invoices, monthly invoice generation, numbering and VAT. | UC-03, FR-06, FR-09, FR-10 |
| Business | Subscriptions | Modify, pause and cancel subscriptions. | UC-02, FR-07 |
| Business | Clients | Global view, assignments and CSV import. | UC-06, UC-07, UC-08, FR-04, FR-05 |
| Business | Payments Sync | Matching payments to invoices and marking invoices as overdue. | UC-16, UC-04, FR-14 |
| Business | Messaging | Sending invoices and reminders through the consented channels. | UC-15, UC-05, FR-12 |
| Business | Reminders | Reminder scheduling, rescheduling and cancelling. | UC-05, FR-13 |
| Business | Inbox | Operational task inbox. | UC-01, FR-15 |
| Business | Dashboard & Export | Financial figures and CSV / PDF export. | UC-09, UC-10 |
| Business | Configuration | Global parameters with effective date. | UC-11 |
| Business | PDF Generator | Corporate-branded invoice PDFs. | UC-14, FR-11, NFR-03 |
| Business | Audit Log | Writing uneditable audit entries. | UC-17, UC-13, FR-03 |
| Business | Scheduler | Daily / hourly jobs: monthly invoices, due reminders and overdue check. | FR-06, FR-13, UC-16 (ext. 4a) |
| Data access | Repositories | The only components that run SQL against the database. | All |
| Integration | Email / WhatsApp / Payment Adapters | Translate our interfaces (`IMessageChannel`, `IPaymentGateway`) into the API of each provider. | UC-15, UC-16 |
| Data tier | MySQL 8 Database, PDF storage | Persistent data (see the physical ER diagram) and the generated PDF files. | — |

## 3. Architectural patterns and rationale

### 3.1 Layered architecture (main pattern)

**What it is:** the system is split into horizontal layers with a single responsibility each (presentation, business logic, data access). Each layer only depends on the layer below.

**Why we chose it:**

1. **Separation of concerns.** The use cases from Submission 1 map directly onto business services (one service per functional area). The UI and the database can change without touching the business rules.
2. **Security (NFR-04, FR-02).** All requests go through the presentation layer, which always calls the authorization component before anything else. Since only the repositories access the database, nobody can skip the permission checks.
3. **Maintainability and teamwork.** Each member of the team can work on one layer or one service without conflicts. It is also the architecture we know best from other courses, which reduces risk.
4. **Testability.** Services can be tested with fake repositories and fake gateways.
5. **Consistency with the other models.** The packages of the application class diagram (`class_diagram_application.pu`) are exactly these layers, and the sequence diagrams always follow the path *View → Controller → Service → Repository*.

**Drawbacks we accept:** a request has to cross several layers, which adds a small overhead. For an internal application of this size it does not affect the 1.5 s search limit (NFR-01), which depends mostly on the database indexes.

### 3.2 Client-server with a responsive web client

A single responsive web application (SPA) used from the browser of any device covers Windows, macOS, Linux, iOS and Android (NFR-02) without developing native apps. The client only presents data. All the logic stays on the server, so the rules are the same for every device.

### 3.3 Adapter pattern for external services

The messaging providers (email, WhatsApp) and the payment service (Stripe) are accessed through our own interfaces (`IMessageChannel`, `IPaymentGateway`), each implemented by an adapter.

* If TurbineH changes provider (for example from Stripe to a bank API), only the adapter changes. The business layer stays the same.
* `MessagingService` keeps a list of `MessageChannelGateway` objects and sends through each channel the client has consented to. Adding a new channel (for example SMS) only means adding a new adapter. This is also an example of the **Strategy** pattern.

### 3.4 Repository pattern

Each repository hides the SQL of one table or group of tables. Business services work with domain objects (`Invoice`, `Client`...) and do not know about SQL. The `AuditLogRepository` only offers `insert()` and `findAll()`, which supports the immutability of the audit log (FR-03) at code level as well as with the database triggers.

### 3.5 Event-driven integration (webhooks) and scheduled jobs

* **Webhooks:** Stripe and the messaging providers notify the system when a payment arrives or a delivery is confirmed (UC-16, UC-15 ext. 7a). This avoids constantly asking the external services.
* **Scheduler:** the automatic processes of the system (monthly invoice generation on the configured day, due reminders, overdue detection) run as scheduled jobs inside the business layer, reusing the same services as the users.

## 4. Traceability with other artifacts

| Artifact | Relationship with the architecture |
| --- | --- |
| Physical ER diagram | Implemented in the *MySQL 8 Database* component, accessed only by *Repositories*. |
| Domain class diagram | Domain objects used by the business layer. |
| Application class diagram | One package per layer. Each component corresponds to one or more classes. |
| Sequence diagrams (UC-03, UC-15, UC-18) | Show the interactions between the components of the different layers for those use cases. |
