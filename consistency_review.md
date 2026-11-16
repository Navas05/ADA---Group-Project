# Consistency Review of the Submission 2 Models

> Check of the design models against the requirements (`requirements.md`) and use cases (`use_case_especification.md`) of Submission 1, as the Operations Guide asks (section 2.2, *Consistency and Traceability*).

## 1. Reviewed artifacts

| Artifact | File |
| --- | --- |
| Physical ER diagram | `physical_entity_relationship_diagram.pu` |
| Data dictionary and SQL | `data_dictionary.md`, `database_schema.sql` |
| Glossary | `glossary.md` |
| Domain class diagram | `class_diagram.pu` |
| Application class diagram | `class_diagram_application.pu` |
| Component diagram and rationale | `component_diagram.pu`, `architecture.md` |
| Sequence diagrams | `sequence_diagram_uc03.pu`, `sequence_diagram_uc15.pu`, `sequence_diagram_uc18.pu` |

## 2. Traceability matrix: use cases → design

| Use case | Tables (ER) | Domain classes | Services / components | Sequence diagram |
| --- | --- | --- | --- | --- |
| UC-01 Access Daily Work Inbox | `inbox_tasks`, `client_assignments` | `InboxTask`, `ClientAssignment` | `InboxService` / Inbox | — |
| UC-02 Modify / Cancel Subscriptions | `subscriptions`, `invoices` | `Subscription`, `Invoice` | `SubscriptionService` / Subscriptions | — |
| UC-03 Create or Issue One-Off Invoices | `invoices`, `invoice_lines`, `invoice_sequences` | `OneOffInvoice`, `InvoiceLine` | `InvoiceService` / Invoicing | **UC-03** |
| UC-04 Track Payment Statuses | `invoices`, `payments`, `message_deliveries`, `reminders` | `Invoice`, `Payment` | `PaymentSyncService` / Payments Sync | — |
| UC-05 Manage Message Deliveries | `reminders`, `message_deliveries` | `Reminder`, `MessageDelivery` | `ReminderService`, `MessagingService` | (uses UC-15) |
| UC-06 View All Clients & Invoices | `clients`, `invoices`, `client_assignments` | `Client`, `Invoice` | `ClientService` / Clients | — |
| UC-07 Assign / Unassign Clients | `client_assignments`, `inbox_tasks` | `ClientAssignment`, `InboxTask` | `ClientService`, `InboxService` | — |
| UC-08 Import Clients via CSV | `clients`, `subscriptions` | `Client` | `ClientService` / Clients | — |
| UC-09 / UC-10 Financial Dashboard & Export | `invoices`, `payments`, `subscriptions` | `Invoice`, `Payment` | `DashboardService` / Dashboard & Export | — |
| UC-11 Configure Global Parameters | `system_parameters` | `SystemParameter` | `ConfigurationService` / Configuration | — |
| UC-12 Assign User Roles | `users` | `User`, `Role` | `AuthService` / Auth & Permissions | — |
| UC-13 Access Modification Log | `audit_log` | `AuditLogEntry` | `AuditService` / Audit Log | — |
| UC-14 Generate Corporate PDF | `invoices.pdf_path` | `Invoice` | `PdfService` / PDF Generator | `ref` in UC-03 |
| UC-15 Send Invoices & Reminders | `message_deliveries`, `reminders` | `MessageDelivery`, `Reminder`, `Client` | `MessagingService`, adapters | **UC-15** |
| UC-16 Sync Payment Status | `payments`, `invoices`, `reminders`, `inbox_tasks` | `Payment`, `Invoice` | `PaymentSyncService`, Stripe adapter, webhooks | — |
| UC-17 Record Audit Log | `audit_log` (append-only) | `AuditLogEntry` | `AuditService`, `AuditLogRepository` | `ref` in UC-03 and UC-18 |
| UC-18 Authenticate & Check Permissions | `users`, `sessions`, `client_assignments` | `User`, `Session` | `AuthService` / Auth & Permissions | **UC-18** |

**Why these three sequence diagrams:** UC-18 is included by every use case. UC-03 is the main flow of the employee and includes UC-14, UC-15 and UC-17. UC-15 is the main integration with external systems. Together they cover all the layers and the three external interactions (user, messaging services, persistence).

## 3. Functional requirements coverage

| Requirement | Covered by |
| --- | --- |
| FR-01 Authentication with `@turbineh.com` | `users.email` CHECK, `AuthService.isCompanyEmail()`, UC-18 sequence |
| FR-02 Three roles | `users.role`, `Role`, `AuthService.authorize()` |
| FR-03 Uneditable audit log | `audit_log` + triggers, `AuditLogEntry` without setters, `AuditLogRepository` without update/delete |
| FR-04 / FR-05 Clients and CSV import | `clients`, `ClientService.importCsv()` |
| FR-06 Monthly invoices on a configurable day | `Subscription.generateMonthlyInvoice()`, `Scheduler`, `MONTHLY_INVOICE_DAY` parameter |
| FR-07 Pause / cancel subscriptions | `SubscriptionStatus`, `Subscription.cancel()` |
| FR-08 Annual review campaign | **Not modelled** (see section 5) |
| FR-09 / FR-10 One-off invoices and status | `OneOffInvoice`, `InvoiceStatus`, UC-03 sequence |
| FR-11 Corporate PDF | `PdfService`, `invoices.pdf_path` |
| FR-12 Email / WhatsApp with consent and delivery log | `Client.getConsentedChannels()`, `message_deliveries`, UC-15 sequence |
| FR-13 Reminder schedule | `reminders`, `ReminderService`, `REMINDER_SCHEDULE_DAYS` parameter |
| FR-14 Payment integration | `payments`, `PaymentSyncService`, Stripe adapter |
| FR-15 Operational inbox | `inbox_tasks`, `InboxService` |

## 4. Inconsistencies found and fixed

| # | Inconsistency | Models involved | Fix |
| --- | --- | --- | --- |
| 1 | The inbox task status was a `boolean resolved` in the class diagram but an `ENUM('PENDING','RESOLVED')` in the ER diagram. | Class diagram / ER | New enum `TaskStatus` in the class diagram. |
| 2 | The UC-15 sequence diagram called `invoice.getClient()`, which did not exist in `Invoice`. | Sequence UC-15 / class diagram | Method added to `Invoice`. |
| 3 | The delivery status callback had a different name in the sequence diagram and in `MessagingWebhookController`. | Sequence UC-15 / application class diagram | Both use `receiveDeliveryStatus(externalMessageId, status)`. |
| 4 | Several different names were used for the same concept ("bill", "charge", "invoice"; "assignment", "allocation"). | All | Shared glossary (`glossary.md`). |
| 5 | The client–employee assignment was first modelled as a simple `employee_id` column in `clients`, which loses the history needed by UC-07 and the audit log. | ER / UC-07 | Intermediate table `client_assignments`. |

## 5. Open points

* **FR-08 (annual review campaign)** is a functional requirement, but no use case was defined for it in Submission 1. It has been left out of the design for now. The team will decide in Submission 3 whether to add a use case (e.g. a `RateTier` table and a `ReviewCampaignService`).
* Only three use cases have sequence diagrams. The rest follow the same *Controller → Service → Repository* pattern and can be added later if needed.
