# Data Dictionary

> Complements the **Physical Entity-Relationship Diagram** (`physical_entity_relationship_diagram.pu`) and the SQL script (`database_schema.sql`). Target DBMS: **MySQL 8.0**, `utf8mb4` charset.

## 1. Design decisions

| Decision | Reason | Related requirement / use case |
| --- | --- | --- |
| A single `users` table with a `role` column instead of one table per role | A user's role can change (UC-12). With one table, a role change is a single `UPDATE`. `role` can be `NULL` for accounts that have no role yet. | FR-02, UC-12, UC-18 (ext. 5b) |
| `client_assignments` stores the assignment history | It lets us know who managed a client at any moment, and moving a client to another employee does not lose information. The active assignment is the row with `unassigned_at IS NULL`. | UC-07, FR-02 |
| A client has **at most one** subscription (`subscriptions.client_id` is `UNIQUE`) | Clients subscribe to a single product (Brain OS). Changing the terms modifies the same row. | UC-02, FR-07 |
| One `invoices` table for recurring and one-off invoices | Both share almost all their attributes. `type` and `subscription_id` tell them apart (`CHECK chk_invoice_type`). In the class diagram they are modelled with a generalization. | FR-06, FR-09 |
| `invoice_number` is `NULL` while the invoice is a draft | Drafts do not consume numbers, so numbering has no gaps (UC-03, ext. 7a). | UC-03 |
| `invoice_sequences` table | It keeps the last number used per year. The number is taken inside the same transaction as the issue with `SELECT ... FOR UPDATE`, which prevents duplicates and gaps. | UC-03 (minimal guarantee) |
| `payments.invoice_id` can be `NULL` | Payments that cannot be matched to an invoice are stored as `UNMATCHED` and a reconciliation task is created. | UC-16 (ext. 3a) |
| `payments.external_reference` is `UNIQUE` | The same Stripe event is never processed twice. | UC-16 (ext. 2b) |
| `system_parameters` stores **one row per version** of each parameter | New values apply from `effective_from`. Invoices that were already issued keep their own terms. | UC-11, FR-06, FR-13 |
| `audit_log` is append-only | Two triggers block `UPDATE` and `DELETE`, and the application user only has `INSERT`/`SELECT` on this table. | FR-03, UC-17, UC-13 |
| Logical delete of clients (`clients.active`) | Cancelled clients keep their invoicing history and can be reactivated. | UC-08 (ext. 7c) |
| Indexes on the most-searched columns | Searches across 10,000+ records must return in under 1.5 s. | NFR-01 |

## 2. Tables

Notation: **PK** primary key, **FK** foreign key, **UQ** unique, **NN** not null.

### users
Staff members of TurbineH who can use the application.

| Column | Type | Constraints | Description |
| --- | --- | --- | --- |
| user_id | INT | PK, AUTO_INCREMENT | Identifier |
| email | VARCHAR(100) | NN, UQ, CHECK `@turbineh.com` | Company email used to sign in (FR-01) |
| password_hash | VARCHAR(255) | NN | Password hash (bcrypt). The password is never stored in plain text |
| full_name | VARCHAR(100) | NN | Full name |
| role | ENUM | NULL allowed | `EMPLOYEE`, `ADMINISTRATOR`, `SUPERADMINISTRATOR` |
| active | BOOLEAN | NN, default TRUE | Deactivated accounts cannot sign in |
| failed_attempts | INT | NN, default 0 | Failed sign-in counter (UC-18, ext. 5a) |
| created_at | DATETIME | NN | Creation date |

### sessions
Open sessions of the users (UC-18).

| Column | Type | Constraints | Description |
| --- | --- | --- | --- |
| session_id | INT | PK | Identifier |
| user_id | INT | FK → users, NN | Owner of the session |
| token | VARCHAR(255) | NN, UQ | Random session token |
| created_at | DATETIME | NN | Sign-in time |
| expires_at | DATETIME | NN | Expiry time |

### clients
Client companies subscribed to Brain OS (FR-04).

| Column | Type | Constraints | Description |
| --- | --- | --- | --- |
| client_id | INT | PK | Identifier |
| company_name | VARCHAR(150) | NN | Company name |
| tax_id | VARCHAR(20) | NN, UQ | Tax ID (CIF). Used to detect duplicates in the CSV import |
| address, city | VARCHAR | — | Billing address. Required to issue an invoice (UC-03, ext. 3a) |
| business_area | VARCHAR(80) | — | Used for filtering (UC-04, UC-06) |
| email | VARCHAR(100) | NN | Contact email |
| phone | VARCHAR(20) | — | Phone for WhatsApp |
| email_consent / whatsapp_consent | BOOLEAN | NN | Consented channels (FR-12) |
| active | BOOLEAN | NN | Logical delete |
| created_at | DATETIME | NN | Creation date |

### client_assignments
History of client ↔ employee assignments (UC-07).

| Column | Type | Constraints | Description |
| --- | --- | --- | --- |
| assignment_id | INT | PK | Identifier |
| client_id | INT | FK → clients, NN | Client |
| employee_id | INT | FK → users, NN | Assigned employee |
| assigned_by | INT | FK → users, NN | Administrator who made the assignment |
| assigned_at | DATETIME | NN | Start of the assignment |
| unassigned_at | DATETIME | NULL | End of the assignment. `NULL` = active |

> The rule "at most one active assignment per client" is checked by the business layer (`ClientService`) before inserting a new row.

### subscriptions
Brain OS subscription of a client (FR-06, FR-07).

| Column | Type | Constraints | Description |
| --- | --- | --- | --- |
| subscription_id | INT | PK | Identifier |
| client_id | INT | FK → clients, NN, UQ | Client (one subscription per client) |
| monthly_fee | DECIMAL(10,2) | NN, > 0 | Monthly fee |
| status | ENUM | NN | `ACTIVE`, `PAUSED`, `CANCELLATION_PENDING_SETTLEMENT`, `CANCELLED` |
| start_date | DATE | NN | Start date |
| next_billing_date | DATE | — | Next monthly invoice date |
| end_date | DATE | — | Date of the cancellation |

### invoices
Recurring and one-off invoices (FR-06, FR-09, FR-10, FR-11).

| Column | Type | Constraints | Description |
| --- | --- | --- | --- |
| invoice_id | INT | PK | Identifier |
| invoice_number | VARCHAR(20) | UQ, NULL | Sequential number, e.g. `2026-000154`. `NULL` for drafts |
| client_id | INT | FK → clients, NN | Invoiced client |
| subscription_id | INT | FK → subscriptions, NULL | Only for recurring invoices |
| created_by | INT | FK → users, NN | Employee who created it (or the system user for monthly invoices) |
| type | ENUM | NN | `RECURRING`, `ONE_OFF` |
| status | ENUM | NN | `DRAFT`, `SCHEDULED`, `ISSUED`, `PENDING_DELIVERY`, `PAID`, `OVERDUE`, `CANCELLED` |
| issue_date / due_date | DATE | due_date NN | `due_date >= issue_date` |
| taxable_base, vat_amount, total_amount | DECIMAL(10,2) | NN | Calculated amounts |
| vat_rate | DECIMAL(5,2) | NN, default 21.00 | VAT percentage |
| pdf_path | VARCHAR(255) | — | Path of the generated corporate PDF (UC-14) |
| created_at | DATETIME | NN | Creation date |

### invoice_lines
Lines (concepts) of an invoice.

| Column | Type | Constraints | Description |
| --- | --- | --- | --- |
| line_id | INT | PK | Identifier |
| invoice_id | INT | FK → invoices, NN, ON DELETE CASCADE | Invoice |
| concept | VARCHAR(200) | NN | Description |
| quantity | DECIMAL(10,2) | NN, > 0 | Quantity |
| unit_price | DECIMAL(10,2) | NN, >= 0 | Unit price |
| line_total | DECIMAL(10,2) | NN | `quantity * unit_price` |

### invoice_sequences

| Column | Type | Constraints | Description |
| --- | --- | --- | --- |
| year | INT | PK | Year of the series |
| last_number | INT | NN | Last number used in that year |

### payments
Payments received from the External Payment Service (FR-14, UC-16).

| Column | Type | Constraints | Description |
| --- | --- | --- | --- |
| payment_id | INT | PK | Identifier |
| invoice_id | INT | FK → invoices, NULL | Matched invoice. `NULL` if unmatched |
| external_reference | VARCHAR(100) | NN, UQ | Stripe reference of the event |
| amount | DECIMAL(10,2) | NN | Amount paid |
| payment_date | DATETIME | NN | Date of the payment |
| status | ENUM | NN | `MATCHED`, `UNMATCHED`, `AMOUNT_MISMATCH` |
| received_at | DATETIME | NN | When the system received the event |

### reminders
Scheduled payment reminders (FR-13, UC-05).

| Column | Type | Constraints | Description |
| --- | --- | --- | --- |
| reminder_id | INT | PK | Identifier |
| invoice_id | INT | FK → invoices, NN | Invoice |
| scheduled_at | DATETIME | NN | When it must be sent |
| send_email / send_whatsapp | BOOLEAN | NN | Channels to use |
| status | ENUM | NN | `PENDING`, `SENT`, `CANCELLED` |

### message_deliveries
Log of every delivery attempt per channel (FR-12, UC-15).

| Column | Type | Constraints | Description |
| --- | --- | --- | --- |
| delivery_id | INT | PK | Identifier |
| invoice_id | INT | FK → invoices, NN | Invoice |
| reminder_id | INT | FK → reminders, NULL | Reminder that produced it. `NULL` = invoice delivery |
| message_type | ENUM | NN | `INVOICE`, `REMINDER` |
| channel | ENUM | NN | `EMAIL`, `WHATSAPP` |
| status | ENUM | NN | `PENDING_CONFIRMATION`, `DELIVERED`, `FAILED` |
| sent_at | DATETIME | NN | Attempt time |
| external_message_id | VARCHAR(100) | — | Identifier returned by the external service |
| error_message | VARCHAR(255) | — | Reason for the failure |

### inbox_tasks
Tasks of the operational inbox (FR-15, UC-01).

| Column | Type | Constraints | Description |
| --- | --- | --- | --- |
| task_id | INT | PK | Identifier |
| assigned_user_id | INT | FK → users, NULL | Employee. `NULL` = administrators' inbox |
| client_id | INT | FK → clients, NN | Related client |
| invoice_id | INT | FK → invoices, NULL | Related invoice, if any |
| task_type | ENUM | NN | `INVOICE_DUE`, `REMINDER_TODAY`, `OVERDUE`, `PAYMENT_CONFIRMED`, `DELIVERY_FAILED`, `RECONCILIATION`, `AMOUNT_MISMATCH` |
| priority | TINYINT | NN, 1–5 | 1 = highest |
| status | ENUM | NN | `PENDING`, `RESOLVED` |
| created_at / resolved_at | DATETIME | — | Dates |

### system_parameters
Versioned global parameters (UC-11).

| Column | Type | Constraints | Description |
| --- | --- | --- | --- |
| parameter_id | INT | PK | Identifier |
| param_key | VARCHAR(50) | NN, UQ with effective_from | e.g. `DEFAULT_PAYMENT_TERMS_DAYS` |
| param_value | VARCHAR(255) | NN | Value |
| effective_from | DATETIME | NN | Date from which it applies |
| updated_by | INT | FK → users, NN | Superadministrator who changed it |

Initial values: payment terms 5 days, monthly invoice day 1, reminders on days 3 and 5 and then every 2 days while overdue, VAT 21 %.

### audit_log
Uneditable record of sensitive operations (FR-03, UC-17, UC-13).

| Column | Type | Constraints | Description |
| --- | --- | --- | --- |
| log_id | BIGINT | PK | Identifier |
| user_id | INT | FK → users, NULL | User. `NULL` if the user could not be identified |
| user_role | VARCHAR(30) | — | Role at the time of the operation |
| operation_type | VARCHAR(50) | NN | e.g. `ISSUE_INVOICE`, `LOGIN_FAILED`, `ASSIGN_CLIENT` |
| affected_table / affected_record_id | — | — | Affected record |
| previous_value / new_value | TEXT | — | Values in JSON format |
| outcome | ENUM | NN | `SUCCESS`, `DENIED`, `FAILED` |
| ip_address | VARCHAR(45) | — | Origin IP (IPv4 or IPv6) |
| created_at | DATETIME | NN | Timestamp |
