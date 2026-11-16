# Design Glossary

> Shared vocabulary for the Submission 2 models. Every concept has **one** name in the use cases, **one** class in the class diagrams and **one** table in the physical ER diagram. Naming rules:
>
> * **Classes:** `PascalCase`, singular (`Invoice`).
> * **Attributes and methods:** `camelCase` (`dueDate`, `calculateTotals()`).
> * **Tables:** `snake_case`, plural (`invoices`). **Columns:** `snake_case` (`due_date`).
> * **Enumerations:** `PascalCase` for the type, `UPPER_CASE` for the values.

## 1. Domain concepts

| Concept (use cases) | Class | Table | Definition |
| --- | --- | --- | --- |
| User / staff member | `User` | `users` | TurbineH employee who can sign in with a `@turbineh.com` email. |
| Role | `Role` (enum) | `users.role` | `EMPLOYEE`, `ADMINISTRATOR`, `SUPERADMINISTRATOR`. Each role includes the permissions of the previous one. |
| Session | `Session` | `sessions` | Authenticated period of a user, identified by a token with an expiry date. |
| Client | `Client` | `clients` | Company subscribed to Brain OS. |
| Client assignment | `ClientAssignment` | `client_assignments` | Relationship between a client and the employee responsible for it during a period of time. |
| Subscription | `Subscription` | `subscriptions` | Monthly Brain OS contract of a client. Generates recurring invoices. |
| Subscription status | `SubscriptionStatus` (enum) | `subscriptions.status` | `ACTIVE`, `PAUSED`, `CANCELLATION_PENDING_SETTLEMENT`, `CANCELLED`. |
| Invoice | `Invoice` (abstract) | `invoices` | Payment document sent to a client. |
| Recurring invoice | `RecurringInvoice` | `invoices` (`type = 'RECURRING'`) | Monthly invoice generated from a subscription (FR-06). |
| One-off invoice | `OneOffInvoice` | `invoices` (`type = 'ONE_OFF'`) | Invoice created manually by an employee (FR-09, UC-03). |
| Invoice line | `InvoiceLine` | `invoice_lines` | Concept, quantity and unit price inside an invoice. |
| Invoice status | `InvoiceStatus` (enum) | `invoices.status` | `DRAFT`, `SCHEDULED`, `ISSUED`, `PENDING_DELIVERY`, `PAID`, `OVERDUE`, `CANCELLED`. |
| Invoice number | `Invoice.number` | `invoices.invoice_number` | Sequential number per year with no gaps, format `YYYY-NNNNNN`. Assigned only when the invoice is issued. |
| Payment | `Payment` | `payments` | Payment event received from the External Payment Service (Stripe). |
| Payment status | `PaymentStatus` (enum) | `payments.status` | `MATCHED`, `UNMATCHED`, `AMOUNT_MISMATCH`. |
| Reminder | `Reminder` | `reminders` | Payment reminder scheduled for a date and a set of channels. |
| Message delivery | `MessageDelivery` | `message_deliveries` | One attempt to send an invoice or reminder through one channel, with its result. |
| Channel | `Channel` (enum) | `message_deliveries.channel` | `EMAIL`, `WHATSAPP`. WhatsApp only if the client has consented. |
| Delivery status | `DeliveryStatus` (enum) | `message_deliveries.status` | `PENDING_CONFIRMATION`, `DELIVERED`, `FAILED`. |
| Inbox task | `InboxTask` | `inbox_tasks` | Pending item shown in the operational inbox of an employee (FR-15, UC-01). |
| Task type / status | `TaskType`, `TaskStatus` (enums) | `inbox_tasks.task_type`, `inbox_tasks.status` | Kind of task (`OVERDUE`, `DELIVERY_FAILED`...) and `PENDING` / `RESOLVED`. |
| System parameter | `SystemParameter` | `system_parameters` | Global configuration value with the date from which it applies (UC-11). |
| Audit log entry | `AuditLogEntry` | `audit_log` | Uneditable record of who did what, when and on which data (FR-03, UC-17). |

## 2. Application-layer elements

| Element | Layer | Responsibility | Main use cases |
| --- | --- | --- | --- |
| `*View` (e.g. `InvoiceView`, `LoginView`) | Presentation | Screens of the web / mobile client. They only show data and forward user actions. | All |
| `*Controller` (e.g. `InvoiceController`) | Presentation (API) | Receives HTTP requests, calls UC-18 through `AuthService` and delegates to the services. | All |
| `AuthService` | Business | Authentication, sessions and permission checks. | UC-18 |
| `InvoiceService` | Business | Creation, validation, numbering and issue of invoices. | UC-03 |
| `PdfService` | Business | Corporate-branded PDF generation. | UC-14 |
| `MessagingService` | Business | Sending invoices and reminders through the external channels. | UC-15, UC-05 |
| `ReminderService` | Business | Scheduling and cancelling reminders. | UC-03, UC-05, UC-16 |
| `AuditService` | Business | Writing audit log entries. | UC-17 |
| `InboxService` | Business | Creating and listing inbox tasks. | UC-01 |
| `*Repository` (e.g. `InvoiceRepository`) | Data access | Reads and writes one table / aggregate in the database. | All |
| `MessageChannelGateway` | Integration | Common interface of the external messaging services (`EmailGateway`, `WhatsAppGateway`). | UC-15 |
| `PaymentGateway` | Integration | Connection with the External Payment Service (Stripe). | UC-16 |

## 3. Operation names in the audit log

| `operation_type` | Use case |
| --- | --- |
| `LOGIN_SUCCESS`, `LOGIN_FAILED`, `LOGIN_BLOCKED_DOMAIN`, `ACCESS_DENIED` | UC-18 |
| `SUBSCRIPTION_MODIFIED`, `SUBSCRIPTION_CANCELLED` | UC-02 |
| `INVOICE_DRAFT_CREATED`, `INVOICE_ISSUED` | UC-03 |
| `CLIENT_ASSIGNED`, `CLIENT_UNASSIGNED` | UC-07 |
| `CLIENTS_IMPORTED` | UC-08 |
| `PARAMETERS_UPDATED` | UC-11 |
| `ROLE_CHANGED` | UC-12 |
| `INVOICE_PAID`, `INVOICE_OVERDUE` | UC-16 |
