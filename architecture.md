# Architecture Model

> Explains the architecture shown in the **UML Component Diagram** (`component_diagram.pu`) and the reasons for the architectural patterns we chose. Consistent with the requirements and use cases of Submission 1 and with the indications given by TurbineH in the meetings.

## 1. Overview

The TurbineH Invoicing & Subscription System is a **responsive web application** (client-server) organised internally as a **layered architecture** with four layers, following the same structure as the course case study (Medical Appointment Management System):

```
 ┌───────────────────────────────────────────────────────────────┐
 │ Presentation layer   «boundary»  UIs + Payment Webhook        │
 ├───────────────────────────────────────────────────────────────┤
 │ Application layer    «control»   one control per functional   │
 │                                  area (use cases)             │
 ├───────────────────────────────────────────────────────────────┤
 │ Domain layer         entities + interfaces (contracts)        │
 ├───────────────────────────────────────────────────────────────┤
 │ Infrastructure layer adapters that implement the contracts    │
 └──────────────┬──────────────────┬──────────────────┬──────────┘
                ▼                  ▼                  ▼
         MySQL Database      Stripe (payments)   Email / WhatsApp
```

* Each layer only uses the layer directly below it. For example, a UI never accesses the database.
* The layers communicate through **interfaces** (the lollipops in the diagram): a component *provides* an interface and the components of the layer above *require* it.
* The **domain layer** defines the interfaces it needs from the outside world (`Payment Source`, `Message Sending`, `PDF Generation`, `Data Storage`). The **infrastructure layer** implements them. This way the dependencies point *inwards*, towards the domain (dependency inversion, as in the course example).

## 2. Components

| Layer | Component | Responsibility | Use cases / requirements |
| --- | --- | --- | --- |
| Presentation | Login UI | Sign-in screen. | UC-18 |
| Presentation | Employee Workspace UI | Daily inbox, invoices, subscriptions, payment tracking and message deliveries. | UC-01 – UC-05 |
| Presentation | Administration UI | Global view of clients and invoices, assignments, CSV import, dashboard and export. | UC-06 – UC-10 |
| Presentation | Superadministrator Settings UI | Global parameters, user roles and modification log. | UC-11 – UC-13 |
| Presentation | Payment Webhook Endpoint | Receives the payment events sent by Stripe. It is a boundary, but for an external system instead of a person. | UC-16 |
| Application | Authentication | Sign-in and permission checks. Every other control calls it first. | UC-18, FR-01, FR-02 |
| Application | Inbox Management | Lists and resolves the pending tasks of an employee. | UC-01, FR-15 |
| Application | Invoicing | One-off invoices, monthly invoices and subscription changes. | UC-02, UC-03, UC-14, FR-06, FR-07, FR-09 |
| Application | Payment Tracking | Payment statuses, matching payments to invoices and overdue invoices. | UC-04, UC-16, FR-10, FR-14 |
| Application | Message Management | Sending invoices and reminders, rescheduling and cancelling reminders. | UC-05, UC-15, FR-12, FR-13 |
| Application | Client Administration | Global view, assignments and CSV import. | UC-06 – UC-08, FR-04, FR-05 |
| Application | Financial Dashboard | Figures per period and export. | UC-09, UC-10 |
| Application | System Settings | Parameters, roles and audit log consultation. | UC-11 – UC-13 |
| Application | Scheduled Jobs | Runs the automatic processes every day: monthly invoices, due reminders and overdue check. | FR-06, FR-13, UC-16 (ext. 4a) |
| Domain | Users & Sessions, Clients & Assignments, Subscriptions & Invoices, Payments, Reminders & Deliveries, Inbox Tasks, System Parameters, Audit Log | The business entities of the domain class diagram (`class_diagram.pu`), each group offered through an API. | All |
| Domain | Interfaces `Payment Source`, `Message Sending`, `PDF Generation`, `Data Storage` | Contracts that the domain needs from the outside. | FR-11, FR-12, FR-14 |
| Infrastructure | Stripe Payment Adapter | Implements `Payment Source` with the Stripe API (simulated for the exercise). | UC-16, FR-14 |
| Infrastructure | Email Adapter, WhatsApp Adapter | Implement `Message Sending`. WhatsApp is only used with consent. | UC-15, FR-12 |
| Infrastructure | Corporate PDF Adapter | Implements `PDF Generation` with the approved corporate template. | UC-14, FR-11, NFR-03 |
| Infrastructure | MySQL Database Adapter | Implements `Data Storage`. The only component that runs SQL. | All (see physical ER diagram) |

## 3. Architectural patterns and rationale

### 3.1 Layered architecture (main pattern)

**What it is:** the system is split into stacked layers, each with one responsibility (presentation, application logic, domain, infrastructure). Each layer only depends on the services of the layer below (Session 2.1, *Layered Architecture*).

**Why we chose it:**

1. **It fits the type of system.** The course presents the layered architecture as the recommended pattern for *financial operations that need security, consistency and strict auditing* (Example 1, banking). Our system manages invoices, payments and an uneditable audit log, so it has the same needs.
2. **Security (NFR-04, FR-02).** Every request enters through the presentation layer and every control calls *Authentication* (UC-18) before doing anything. Only the database adapter accesses the data, so the permission checks cannot be skipped.
3. **Maintainability.** TurbineH asked for *"code and architecture that another team can continue"* and said that *"there is no need for microservices because they sound modern. If a well-designed modular monolith solves this, perfect."* A layered monolith split into clear components is exactly that.
4. **It matches our use cases.** Each control component groups the use cases of one functional area, so the use case diagram of Submission 1 maps directly onto the application layer.
5. **Consistency with the other models.** The packages of the application class diagram (`class_diagram_application.pu`) are these four layers, and the sequence diagrams always follow the path *View → Controller → Entity / Interface → Adapter*.

**Drawbacks we accept:** a request has to cross several layers, which adds a small overhead. For an internal application of this size it does not affect the 1.5 s search limit (NFR-01), which depends mostly on the database indexes.

### 3.2 Client-server with a responsive web client

TurbineH asked for a *"responsive web application"* that works on *"current Android and iOS browsers"*. A single web client used from the browser of any device covers NFR-02 without developing native apps. The client only presents data; all the rules stay on the server, so they are the same for every device.

### 3.3 Boundary-Control-Entity (BCE)

Inside the layers we used the BCE analysis method from the course: **boundaries** in the presentation layer (UIs and the payment webhook), **controls** in the application layer (one per functional area) and **entities** in the domain layer. This makes it easy to go from each use case to the components and classes that implement it.

### 3.4 Interfaces and adapters for external services (dependency inversion)

The external services are not used directly by the domain. The domain defines an interface and an adapter in the infrastructure layer implements it, as the course example does with the legacy scheduling system:

* **Payment Source → Stripe Payment Adapter.** TurbineH said: *"if tomorrow we change Stripe for another provider, it should not force us to rewrite the invoice model"* and *"not everything will be Stripe… Revolut or a bank account"*. Adding a new payment source only means adding a new adapter.
* **Message Sending → Email Adapter / WhatsApp Adapter.** Both implement the same interface, so *Message Management* treats all the channels in the same way and only uses the ones the client consented to.
* **PDF Generation → Corporate PDF Adapter** and **Data Storage → MySQL Database Adapter**, for the same reason: the technology can change without touching the business rules.

### 3.5 Receiving payment events

TurbineH wants the system to *"query payments and also receive a simulated notification"*. Both are covered: *Payment Tracking* queries Stripe through the `Payment Source` interface (UC-04 step 3), and Stripe sends events to the *Payment Webhook Endpoint* (UC-16).

## 4. Constraints

* The presentation layer cannot access the domain or the database directly; it always goes through a control.
* Only the *MySQL Database Adapter* runs SQL, and the audit log can only be inserted and read (FR-03).
* No external service is used without its adapter.
* API keys (for example the Stripe secret) are configuration of the adapters and are not stored in the repository.

## 5. Traceability with other artifacts

| Artifact | Relationship with the architecture |
| --- | --- |
| Physical ER diagram | Implemented in the *MySQL Database*, accessed only by the *MySQL Database Adapter*. |
| Domain class diagram | Entities of the domain layer components. |
| Application class diagram | One package per layer. Each component corresponds to one or more classes (e.g. *Invoicing* → `InvoiceController`, `SubscriptionController`; *Employee Workspace UI* → `InboxView`, `InvoiceView`, `SubscriptionView`, `PaymentTrackingView`, `MessageView`). |
| Sequence diagrams (UC-03, UC-15, UC-18) | Show the interaction between the boundaries, controls, entities, interfaces and adapters for those use cases. |
