---
marp: true
theme: default
paginate: true
title: TurbineH - Submission 2 - System Design
---

<!-- Slides in Marp format. To export them to PDF or PPTX:
     VS Code + "Marp for VS Code" extension -> "Export slide deck",
     or with the CLI:  npx @marp-team/marp-cli presentation_submission2.md --pdf -->

# TurbineH Invoicing & Subscription System
## Submission 2: System Design

Álvaro Navas · Javier Pérez · Juan Miguel Reyes · Antonio Doblás · Daniel Ortega (Scrum Master)

---

# Starting point (Submission 1)

* 2 business, 12 user, 15 functional and 4 non-functional requirements
* 18 use cases for 3 roles: **Employee → Administrator → Superadministrator**
* External actors: **Payment Service (Stripe)** and **Messaging Services (email, WhatsApp)**

**Goal of Submission 2:** turn those requirements into a design: data, structure, architecture and interactions.

---

# How we worked (Scrum)

* 2 sprints in GitHub Projects ("Submission 2")
  * **Sprint 1** (29/10 – 08/11): ER diagram + class diagrams
  * **Sprint 2** (09/11 – 18/11): component diagram + sequence diagrams + delivery
* Meetings every **Sunday at 11:00** (~1 h): 01/11, 08/11, 15/11
* Every diagram made in **pairs** and reviewed by a third member
* Shared **glossary** so that names are the same in every model

---

# Physical ER diagram

* **14 tables** in MySQL 8 (`users`, `clients`, `subscriptions`, `invoices`, `payments`, `audit_log`...)
* Key decisions:
  * `client_assignments` keeps the **assignment history** (UC-07)
  * `invoice_number` is NULL in drafts + `invoice_sequences` → numbering with **no gaps**
  * `payments.external_reference` UNIQUE → a Stripe event is never processed twice
  * `audit_log` is **append-only** (triggers block UPDATE / DELETE) → FR-03
  * `system_parameters` versioned with `effective_from` (UC-11)

<!-- Show physical_entity_relationship_diagram.png -->

---

# UML class diagram: domain model

* `Invoice` (abstract) ← `RecurringInvoice`, `OneOffInvoice` (**generalization**)
* `Invoice` ◆ `InvoiceLine` (**composition**), `Invoice` ◇ `Reminder` / `MessageDelivery` (**aggregation**)
* `User` with a `Role` enum instead of subclasses → the role can change (UC-12)
* `AuditLogEntry` is **immutable**: constructor only, no setters

<!-- Show class_diagram.png -->

---

# UML class diagram: application layers

* **Controllers** → **Services** → **Repositories** → database
* One service per functional area (`InvoiceService`, `MessagingService`, `AuthService`...)
* `MessageChannelGateway` interface with `EmailGateway` and `WhatsAppGateway` → **Adapter / Strategy**
* `AuditLogRepository` has no `update()` / `delete()`

<!-- Show class_diagram_application.png -->

---

# Architecture: component diagram

**Layered architecture** + client-server + adapters

| Layer | Components |
| --- | --- |
| Presentation | REST API, Webhook endpoints |
| Business | Auth, Invoicing, Subscriptions, Clients, Payments, Messaging, Reminders, Inbox, Dashboard, Config, PDF, Audit, Scheduler |
| Data access | Repositories → MySQL |
| Integration | Email, WhatsApp, Stripe adapters |

**Why:** separation of concerns, security (every request goes through UC-18), teamwork, testability.

---

# Sequence diagrams

* **UC-18 Authenticate & Check Permissions**: included by every use case. Session, sign-in and role / client-scope check
* **UC-03 Create or Issue One-Off Invoice**: main flow of the employee. Includes UC-14 (PDF), UC-15 (send) and UC-17 (audit)
* **UC-15 Send Invoices & Reminders**: integration with external services. Consent check and delivery log per channel

Messages = methods of the class diagrams (checked in the consistency review)

---

# Consistency and traceability

* Matrix **use case → tables → classes → services → sequence diagram**
* 5 inconsistencies found and fixed (e.g. task status, method names, assignment history)
* Open point: **FR-08 annual review campaign** has no use case → decided in Submission 3

---

# Retrospective

* ✅ Working in pairs and holding fixed Sunday meetings
* ⚠️ ER and class diagrams were first developed in parallel → glossary from day 1
* ➡️ Next submission: update the board during the week, mid-week check-in, rotate the Scrum Master

**Thank you! Questions?**
