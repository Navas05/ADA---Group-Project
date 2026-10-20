# Use Case Specification

> Fully dressed specification of every use case in `use_case_diagram.pu`, for TurbineH's internal invoicing, subscription and payment tracking application. Each use case traces back to the requirements in `requirements.md`: User Requirements (UR) map to use cases, Functional Requirements (FR) appear as steps in the flows, and Non-Functional Requirements (NFR) appear as quality constraints on those steps.

## Conventions

- **Scope (all use cases):** TurbineH Invoicing & Subscription System (internal application, independent from Brain OS).
- **Actor inheritance:** `Administrator` inherits every use case of `Employee`, and `Superadministrator` inherits every use case of `Administrator`. When an Administrator runs an Employee use case, the scope is all clients, not only the assigned ones (FR-02).
- **External actors:** `External Payment Service` (Stripe, simulated in this project) and `External Messaging Services` (email and WhatsApp).
- **Authentication and permissions:** As the diagram notes, **UC-18: Authenticate & Check User Permissions** is included in every use case. It is the first step of every use case started by a human actor. The subfunctions UC-14, UC-15 and UC-17 run inside the use case that calls them, so they rely on the check that use case has already made.
- **Writing rules:** Steps are written in active voice as a dialogue between the actor and the system, and do not mention any specific interface.
  - An `«include»` is written as a step where the system executes the included use case.
  - An `«extend»` is written as an extension of the base use case, in which the extending use case is executed.
  - Preconditions are only conditions that the system assumes and does not check at runtime. Anything that the system checks while the use case runs is an extension.
- **Invoice statuses (FR-10):** `Draft`, `Scheduled`, `Issued`, `Overdue`, `Paid`, `Void`.
- **Subscription statuses (FR-07):** `Active`, `Paused`, `Cancellation Pending Settlement`, `Cancelled`.

---

## UC-01: Access Daily Work Inbox

- **ID / Code:** UC-01
- **Use Case Name:** Access Daily Work Inbox
- **Description:** Shows the employee a list of the most important pending tasks that require their attention. 
- **Primary Actor:** Employee
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** User Goal
- **Stakeholders & Interests:**
  - _Employee:_ Wants to know the important information quickly without being saturated with too many information.
  - _TurbineH (management):_ Wants information to reach the right person, so that no payment or event goes unnoticed (BR-01, BR-02).
  - _Clients:_ Want problems with their invoices to be handled quickly.
- **Preconditions:** The application is online and reachable from the employee's device (NFR-02).
- **Success Guarantee:** The employee sees an up-to-date list of pending tasks, ordered by priority and limited to their assigned clients. Each task leads straight to the use case that resolves it.
- **Minimal Guarantee:** The inbox never shows tasks or data for clients outside the employee's permitted scope (FR-02).
- **Trigger:** The employee opens the application.
- **Main Success Scenario:**
  1. **Employee:** Opens the application.
  2. **System:** Executes **UC-18: Authenticate & Check User Permissions** to verify the employee's identity and load their role and assigned clients (FR-01, FR-02).
  3. **System:** Collects the pending tasks for the employee's assigned clients (FR-15):
    - invoices due to be issued in the coming days (FR-06);
    - reminders scheduled for today (FR-13);
    - invoices past their due date;
    - payments confirmed since the last visit (FR-14);
    - message deliveries that failed (FR-12).
  4. **System:** Shows the tasks.
  5. **Employee:** Selects a task.
  6. **System:** Shows the task details (client, invoice, amount, dates, history) and offers the actions that apply to it: track the payment (UC-04), manage its messages (UC-05), create a one-off invoice (UC-03) or manage the subscription (UC-02).
  7. **Employee:** Chooses one action and completes it in the corresponding use case.
  8. **System:** Marks the task as resolved and removes it from the pending list.
- **Extensions:**
  - **3a. No pending tasks:**
    - 3a1. System informs the employee that there are no pending tasks for today. The use case ends.
  - **5a. The task is no longer valid when it is selected (for example, the invoice was paid in the meantime):**
    - 5a1. System informs the employee that the task has already been resolved.
    - 5a2. System refreshes the inbox. The flow continues at step 4.
  - **7a. The employee closes the task without acting on it:**

---

## UC-02: Modify / Cancel Subscriptions

- **ID / Code:** UC-02
- **Use Case Name:** Manage Client Subscription
- **Description:** Lets an employee modify or cancel the subscription of an assigned client. Cancelling stops new monthly invoices from being generated, but every unpaid invoice stays in the collection flow until it is settled.
- **Primary Actor:** Employee
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** User Goal
- **Stakeholders & Interests:**
  - _Employee:_ Wants to apply a client's change of status in a few steps, without manually tracking pending invoices.
  - _TurbineH (management):_ Wants no outstanding debt to be lost when a client cancels; collection must continue until payment (BR-01).
  - _Clients:_ Want to stop being invoiced from the moment their cancellation is processed.
- **Preconditions:** The client and its subscription are stored in the system (FR-04).
- **Success Guarantee:** The new subscription status or terms are stored and applied from the next billing cycle. Future invoice generation follows the new status (FR-06, FR-07), every unpaid invoice stays in the collection flow, and the change is recorded in the audit log (FR-03).
- **Minimal Guarantee:** Invoices that have already been issued are never changed or removed by a subscription change. Unpaid invoices are never taken out of the collection and reminder flow (FR-07).
- **Trigger:** The employee selects the subscription of an assigned client in order to change it (from UC-01, UC-04 or the client record).
- **Main Success Scenario:**
  1. **Employee:** Selects the subscription of a client.
  2. **System:** Executes **UC-18: Authenticate & Check User Permissions** to verify that the employee may manage this client's subscription (FR-02).
  3. **System:** Shows the subscription's status, monthly fee, next billing date and the list of unpaid invoices.
  4. **Employee:** Chooses the action to perform: modify the terms or cancel.
  5. **System:** Applies the action (FR-07):
    - **modify:** stores the new terms, which apply from the next generated invoice;
    - **cancel:** stops new monthly invoices and sets the status to cancelled.
  6. **System:** Keeps every unpaid invoice of the client in the active collection and reminder flow (FR-07, FR-13).
  7. **System:** Executes **UC-17: Record Uneditable Audit Log** with the previous and new subscription state (FR-03).
  8. **System:** Confirms the change and shows the updated subscription.
- **Extensions:**
  - **2a. The employee has no permission over this client:**
    - 2a1. UC-18 denies the operation and records the denied access (FR-02, NFR-04). The use case ends.
  - **4a. The chosen action does not apply to the current status: **
    - 4a1. System informs the employee and offers only the actions that apply.
  - **6a. The employee does not confirm:**
    - 6a1. System discards the action without changing anything. The use case ends.
  - **7a. Cancellation with unpaid invoices:**
    - 7a1. System sets the status to Cancellation Pending Settlement instead of Cancelled, and stops generating new invoices.
    - 7a2. System informs the employee that the cancellation will be completed once every pending invoice has been paid.
    - 7a3. When UC-16 detects that the last pending invoice is paid, the system changes the status to cancelled.

---

## UC-03: Create or Issue One-Off Invoices

- **ID / Code:** UC-03
- **Use Case Name:** Create or Issue One-Off Invoice
- **Description:** Lets an employee create a one-off invoice for an assigned client. The employee can issue it with a sequential number and VAT, which generates its branded PDF and sends it to the client.
- **Primary Actor:** Employee
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** User Goal
- **Stakeholders & Interests:**
  - _Employee:_ Wants to issue an invoice with very few steps (NFR-01).
  - _TurbineH (management):_ Wants legally valid invoices that are delivered and tracked without manual follow-up (BR-01, BR-02).
  - _Clients:_ Want a correct invoice that follows TurbineH's corporate identity and arrives through their consented channels.
- **Preconditions:** The client is stored in the system (FR-04).
- **Success Guarantee:** The invoice is stored with a definitive sequential number (FR-09, FR-10). Its corporate PDF is generated and stored (FR-11), it is delivered to the client and the delivery status is logged (FR-12), payment reminders are scheduled (FR-13), and the operation is recorded in the audit log (FR-03).
- **Minimal Guarantee:** Invoice numbering stays sequential with no gaps or duplicates. No invoice is ever sent to a client without a stored PDF that matches the stored invoice data.
- **Trigger:** The employee requests to create a one-off invoice for a client (from UC-01 or the client record).
- **Main Success Scenario:**
  1. **Employee:** Requests to create a one-off invoice for a client.
  2. **System:** Executes **UC-18: Authenticate & Check User Permissions** to verify that the employee may invoice this client (FR-02).
  3. **System:** Shows a new invoice already filled in with the client's tax data, today's issue date and a due date calculated from the default payment terms (UC-11).
  4. **Employee:** Enters the invoice lines (concept, quantity, unit price) and, if needed, changes the dates.
  5. **System:** Checks the data and calculates the taxable base, VAT and total amount.
  6. **System:** Shows a summary of the invoice for review.
  7. **Employee:** Confirms the issue.
  8. **System:** Executes **UC-14: Generate Corporate-Branded PDF** for the invoice (FR-11, NFR-03).
  9. **System:** Executes **UC-15: Send Invoices & Reminders** to deliver the invoice to the client (FR-12).
  10. **System:** Schedules the payment reminders according to the configured reminder schedule (FR-13).
  11. **System:** Executes **UC-17: Record Uneditable Audit Log** to record the invoice issue (FR-03).
  12. **System:** Confirms the issue to the employee and shows the invoice with its delivery status.
- **Extensions:**
  - **2a. The employee has no permission over this client:**
    - 2a1. UC-18 denies the operation and records the denied access (FR-02, NFR-04). The use case ends.
  - **3a. The client's billing data is incomplete (for example, a missing tax ID or address):**
    - 3a1. System blocks the creation of the invoice and states which data is missing. The use case ends.
  - **5a. Invalid invoice data (for example, an empty line, a negative amount, or a due date before the issue date):**
    - 5a1. System flags the incorrect fields.
    - 5a2. System asks the employee to correct them and keeps the valid data. The flow continues at step 4.
  - **7a. The employee saves the invoice without issuing it:**
    - 7a1. System stores the invoice as a draft, without a number and without sending it.
    - 7a2. System executes **UC-17** to record that the draft was created. The use case ends.
  - **7b. The employee sets a future issue date:**
    - 7b1. System stores the invoice and will run steps 8–12 automatically on that date. The use case ends.
  - **9a. The PDF cannot be generated:**
    - 9a1. System does not send the invoice. It keeps the assigned number and marks the invoice as pending delivery.
    - 9a2. System creates a task in the employee's inbox (FR-15) to retry the delivery. The flow continues at step 12.
  - **10a. Delivery fails on every channel:**
    - 10a1. System keeps the invoice and logs the failure (FR-12).
    - 10a2. System creates a task in the employee's inbox to resend the invoice through UC-05.

---

## UC-04: Track Assigned Client Payment Statuses

- **ID / Code:** UC-04
- **Use Case Name:** Track Assigned Client Payment Statuses
- **Description:** Lets an employee see the up-to-date payment status of the invoices of their assigned clients, filter them, and open the full history of any invoice (payments, deliveries and reminders).
- **Primary Actor:** Employee
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** User Goal
- **Stakeholders & Interests:**
  - _Employee:_ Wants to know at a glance which invoices are paid, pending or overdue, without checking manually.
  - _TurbineH (management):_ Wants every payment to be checked against its invoice automatically, so that collection status is always reliable.
  - _Clients:_ Want their payments to be recognised promptly, so they do not receive reminders for invoices they have already paid.
- **Preconditions:** The application is online and reachable from the employee's device.
- **Success Guarantee:** The employee sees the payment status of every invoice of their assigned clients, updated with the latest information from the payment service, and can open any invoice's history.
- **Minimal Guarantee:** Invoice data of clients outside the employee's scope is never shown. The system always shows when it was last updated.
- **Trigger:** The employee requests the payment tracking overview (from UC-01 or directly).
- **Main Success Scenario:**
  1. **Employee:** Requests the payment status of their assigned clients' invoices.
  2. **System:** Executes **UC-18: Authenticate & Check User Permissions** to verify the employee and load their assigned clients (FR-02).
  3. **System:** Executes **UC-16: Sync & Update Invoice Payment Status** to get the latest payment information (FR-14).
  4. **System:** Lists the invoices of the assigned clients with their status, amount, issue date, due date, days overdue and number of reminders sent (FR-10).
  5. **Employee:** Filters or searches the list (by status, recurring or one-off, date range, client, location or business area).
  6. **System:** Shows the matching invoices in under 1.5 seconds (NFR-01).
  7. **Employee:** Selects an invoice.
  8. **System:** Shows the invoice details: payment events, delivery log per channel, reminders sent and scheduled, and access to the stored PDF.
- **Extensions:**
  - **3a. The External Payment Service is unavailable:**
    - 3a1. System shows the last known statuses, together with the date and time of the last successful update.
    - 3a2. System warns the employee that the statuses may be outdated. The flow continues at step 4.
  - **6a. No invoice matches the filters:**
    - 6a1. System informs the employee and keeps the filters so they can be adjusted. The flow continues at step 5.

---

## UC-05: Manage Message Deliveries

- **ID / Code:** UC-05
- **Use Case Name:** Manage Message Deliveries
- **Description:** Lets an employee review the messages sent and scheduled for an invoice of an assigned client, and reschedule or cancel pending reminders. When the employee asks to resend a message straight away, the use case is extended by UC-15.
- **Primary Actor:** Employee
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** User Goal
- **Stakeholders & Interests:**
  - _Employee:_ Wants to fix failed deliveries, or adjust the reminder schedule agreed with a client, in a few steps.
  - _TurbineH (management):_ Wants no invoice or reminder to be lost, and all communication to be traceable (FR-12).
  - _Clients:_ Want to receive messages only through channels they have consented to.
- **Preconditions:** The selected invoice has been issued (UC-03 or the monthly recurring invoicing, 06).
- **Success Guarantee:** The reminder schedule of the invoice reflects the employee's change (FR-13), or the message has been resent through UC-15. Every action is logged with its result (FR-12).
- **Minimal Guarantee:** No message is ever sent through a channel the client has not consented to. Every delivery attempt and schedule change is logged.
- **Trigger:** The employee selects an invoice or one of its messages in order to review it (from UC-01 or UC-04).
- **Main Success Scenario:**
  1. **Employee:** Selects an issued invoice of a client.
  2. **System:** Executes **UC-18: Authenticate & Check User Permissions** to verify that the employee may manage this client's messages (FR-02).
  3. **System:** Shows the delivery history of the invoice (message type, channel, date, delivery status) and its pending scheduled reminders.
  4. **Employee:** Selects a pending reminder and chooses a new date and time, and the channels to use (from those the client has consented to).
  5. **System:** Checks that the new date is in the future and that the channels are consented to.
  6. **System:** Stores the new date in the reminder schedule of the invoice (FR-13).
  7. **System:** Logs the schedule change (FR-12).
  8. **System:** Confirms the change to the employee.
- **Extensions:**
  - **2a. The employee has no permission over this client:**
    - 2a1. UC-18 denies the operation and records the denied access (FR-02, NFR-04). The use case ends.
  - **3a. The invoice is already paid:**
    - 3a1. System informs the employee that no reminders apply. Only the resend of a copy of the invoice is available (extension 4a).
  - **4a. Extension point "Resend now": the employee asks to resend the invoice or a reminder straight away:**
    - 4a1. Employee selects the message and the channels.
    - 4a2. System executes **UC-15: Send Invoices & Reminders** for the selected message (FR-12).
    - 4a3. System shows the delivery result of each channel. The flow continues at step 8.
  - **4b. The employee cancels a pending reminder:**
    - 4b1. System removes it from the schedule and logs the cancellation. The flow continues at step 8.
  - **5a. The client has not consented to the selected channel (for example, WhatsApp):**
    - 5a1. System removes that channel and informs the employee. The flow continues at step 4.
  - **5b. The new date is not valid:**
    - 5b1. System asks for a future date. The flow continues at step 4.

---

## UC-06: View All Clients & Invoices Globally

- **ID / Code:** UC-06
- **Use Case Name:** View All Clients & Invoices Globally
- **Description:** Lets an administrator see every client and invoice in the system, whoever it is assigned to, with search and filters.
- **Primary Actor:** Administrator
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** User Goal
- **Stakeholders & Interests:**
  - _Administrator:_ Wants a complete view of the client portfolio and its collection status, to supervise the team and detect problems.
  - _TurbineH (management):_ Wants no client or invoice to stay unnoticed because it is not assigned to anyone.
  - _Employees:_ Want the administrator to be able to back them up on clients assigned to them.
- **Preconditions:** The application is online and reachable from the administrator's device (NFR-02).
- **Success Guarantee:** The administrator sees every client and invoice, together with the employee assigned to each client and the current invoice statuses.
- **Minimal Guarantee:** The global view is never shown to users without the Administrator or Superadministrator role (FR-02). Viewing never changes any data.
- **Trigger:** The administrator requests the global view of clients or invoices.
- **Main Success Scenario:**
  1. **Administrator:** Requests the global view of clients and invoices.
  2. **System:** Executes **UC-18: Authenticate & Check User Permissions** to verify that the user has the Administrator role (FR-02).
  3. **System:** Retrieves all clients and invoices in record.
  4. **System:** Shows clients with their assigned employee, subscription status and outstanding balance, and invoices with their status, amount and dates.
  5. **Administrator:** Searches or filters (by client, assigned employee, location, business area, invoice status, recurring or one-off, date range).
  6. **System:** Shows the matching results in under 1.5 seconds, even with more than 10,000 records (NFR-01).
  7. **Administrator:** Selects a client or an invoice.
  8. **System:** Shows its full details and offers the actions the administrator can perform on it (UC-02 to UC-05, or UC-07).
- **Extensions:**
  - **2a. The user does not have the Administrator role:**
    - 2a1. UC-18 denies access and records the attempt (NFR-04). The use case ends.
  - **4a. Some clients have no assigned employee:**
    - 4a1. System highlights them, so that they can be assigned through UC-07.
  - **6a. No result matches the filters:**
    - 6a1. System informs the administrator and keeps the filters. The flow continues at step 5.

---

## UC-07: Assign / Unassign Clients to Employees

- **ID / Code:** UC-07
- **Use Case Name:** Assign / Unassign Clients to Employees
- **Description:** Lets an administrator assign one or more clients to an employee, or remove an assignment.
- **Primary Actor:** Administrator
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** User Goal
- **Stakeholders & Interests:**
  - _Administrator:_ Wants to share out the client portfolio quickly, even several clients at once.
  - _Employees:_ Want to see exactly the clients they are responsible for, and receive their notifications.
  - _Clients:_ Want their data to be seen only by the staff who manage their account (NFR-04).
  - _TurbineH (management):_ Wants to increase efficiency by effectively splitting work amongst its employees (BR-02).
- **Preconditions:** The clients to assign are stored in the system (FR-04).
- **Success Guarantee:** The new assignments are stored and take effect on the employees' permissions straight away (FR-02). The pending tasks of the affected clients move to the new assignee's inbox (FR-15), and the change is recorded in the audit log (FR-03).
- **Minimal Guarantee:** Client data is never left visible to an employee who is no longer assigned to that client. No pending task is lost because a client changed assignment.
- **Trigger:** The administrator requests to change the assignment of one or more clients (from UC-06 or the client record).
- **Main Success Scenario:**
  1. **Administrator:** Selects one or more clients.
  2. **System:** Executes **UC-18: Authenticate & Check User Permissions** to verify that the user has the Administrator role (FR-02).
  3. **System:** Shows the current assignment of each selected client.
  4. **Administrator:** Chooses the target employee and the action (assign or unassign).
  5. **System:** Updates the assignments and the access scope of the employees involved (FR-02).
  6. **System:** Moves the pending inbox tasks of the affected clients to the new assignee (FR-15).
  7. **System:** Executes **UC-17: Record Uneditable Audit Log** with the previous and new assignments (FR-03).
  8. **System:** Shows a message confirming the change.
- **Extensions:**
  - **2a. The user does not have the Administrator role:**
    - 2a1. UC-18 denies the operation and records the attempt (NFR-04). The use case ends.
  - **4a. The administrator unassigns a client without choosing a new employee:**
    - 4a1. System warns that the client will have no responsible employee.
    - 4a2. Administrator confirms. System sends the client's pending tasks and notifications to the administrators' inbox. The flow continues at step 7.

---

## UC-08: Import Clients in Bulk via CSV

- **ID / Code:** UC-08
- **Use Case Name:** Import Clients in Bulk via CSV
- **Description:** Lets an administrator register many clients at once from a CSV file exported from another client database. Every row is checked, and the administrator reviews the result before anything is stored.
- **Primary Actor:** Administrator
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** User Goal
- **Stakeholders & Interests:**
  - _Administrator:_ Wants to load the existing client base without typing it in by hand (BR-02).
  - _TurbineH (management):_ Wants imported data to be valid and free of duplicates, so that invoices can be generated from it.
- **Preconditions:** The application is online and reachable from the administrator's device (NFR-02).
- **Success Guarantee:** Every valid row the administrator confirmed is stored as a client record (FR-04, FR-05). Recurring subscriptions are scheduled for invoicing (FR-06), and the import is recorded in the audit log with the number of records created (FR-03).
- **Minimal Guarantee:** There is no partially imported record and no record duplicated by tax ID is ever stored.
- **Trigger:** The administrator requests to import clients from a file.
- **Main Success Scenario:**
  1. **Administrator:** Requests to import clients from a CSV file.
  2. **System:** Executes **UC-18: Authenticate & Check User Permissions** to verify that the user has the Administrator role (FR-02).
  3. **System:** Describes the expected columns and their format.
  4. **Administrator:** Provides the CSV file.
  5. **System:** Checks the file structure (format, encoding, mandatory columns).
  6. **System:** Checks each row (mandatory fields, tax ID and email formats) and looks for duplicates, both inside the file and against existing clients.
  7. **System:** Shows a preview with the number of valid rows, the rows with errors, and the duplicates found.
  8. **Administrator:** Confirms the import of the valid rows.
  9. **System:** Stores the client records and assigns them to the chosen employee, if one was given (FR-04, FR-05).
  10. **System:** Schedules monthly invoicing for the clients with recurring subscriptions (FR-06).
  11. **System:** Executes **UC-17: Record Uneditable Audit Log** to record the import and its result (FR-03).
  12. **System:** Shows a final report of the clients created and the rows skipped.
- **Extensions:**
  - **2a. The user does not have the Administrator role:**
    - 2a1. UC-18 denies the operation and records the attempt (NFR-04). The use case ends.
  - **5a. The file is not a valid CSV, or mandatory columns are missing:**
    - 5a1. System rejects the file, names the problem, and stores nothing. The flow continues at step 4.
  - **7a. Some rows have errors:**
    - 7a1. System lists each incorrect row with its reason and offers a downloadable error report.
    - 7a2. Administrator chooses to import only the valid rows (the flow continues at step 8) or to cancel and fix the file (the flow continues at step 4).
  - **7b. Duplicates against existing clients:**
    - 7b1. System lets the administrator skip them or update the existing records with the data from the file.
  - **7c. A duplicate matches a client that was cancelled (logically deleted):**
    - 7c1. System offers to reactivate the existing record and keep its invoicing history.
  - **8a. The administrator cancels the import:**
    - 8a1. System discards the file and stores nothing. The use case ends.

---

## UC-09: Consult Financial Dashboard

- **ID / Code:** UC-09
- **Use Case Name:** Consult Financial Dashboard
- **Description:** Lets an administrator see the main invoicing and collection figures for a weekly, monthly, quarterly or annual period. The use case can be extended by UC-10 to export the figures shown.
- **Primary Actor:** Administrator
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** User Goal
- **Stakeholders & Interests:**
  - _Administrator:_ Wants to know how invoicing with clients is going at an accounting level, without building reports by hand.
  - _TurbineH (management):_ Wants financial information to be visible only to administrators (FR-02).
- **Preconditions:** The application is online and reachable from the administrator's device (NFR-02).
- **Success Guarantee:** The dashboard shows the figures for the chosen period, calculated from the stored invoice and payment data (FR-10, FR-14).
- **Minimal Guarantee:** Financial figures are never shown to users without the Administrator or Superadministrator role (FR-02). The dashboard never changes any invoice or payment data.
- **Trigger:** The administrator requests the financial dashboard.
- **Main Success Scenario:**
  1. **Administrator:** Requests the financial dashboard.
  2. **System:** Executes **UC-18: Authenticate & Check User Permissions** to verify that the user has the Administrator role (FR-02).
  3. **System:** Asks for the period type (weekly, monthly, quarterly or annual), and suggests the current month by default.
  4. **Administrator:** Selects the period type and the period.
  5. **System:** Calculates the figures for the period: amount invoiced, collected, outstanding, overdue, number of active subscriptions, and comparison with the previous period of the same type.
  6. **System:** Shows the figures and their evolution over time.
- **Extensions:**
  - **2a. The user does not have the Administrator role:**
    - 2a1. UC-18 denies access and records the attempt (NFR-04). The use case ends.
  - **5a. There is no invoicing data for the selected period:**
    - 5a1. System shows the figures as zero and informs the administrator. The flow continues at step 4.
  - **6a. Extension point "Export": the administrator asks to export the figures shown:**
    - 6a1. System executes **UC-10: Export Financial Dashboard** for the selected period.

---

## UC-10: Export Financial Dashboard

- **ID / Code:** UC-10
- **Use Case Name:** Export Financial Dashboard
- **Description:** Extends UC-09. It generates a downloadable file with the figures of the dashboard period the administrator is looking at.
- **Primary Actor:** Administrator
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** User Goal
- **Stakeholders & Interests:**
  - _Administrator:_ Wants to share or archive the financial figures outside the application.
  - _TurbineH's external accountant:_ Wants exported data that is consistent with the issued invoices.
  - _TurbineH (management):_ Wants exported financial data to be produced only by administrators (NFR-04).
- **Preconditions:** The administrator is viewing the dashboard for a period in UC-09, which has already checked their permissions through UC-18.
- **Success Guarantee:** A file with exactly the figures and period shown in the dashboard is generated and made available to the administrator.
- **Minimal Guarantee:** The exported figures always match the figures shown in the dashboard for the same period. No invoice or payment data is changed.
- **Trigger:** The administrator asks to export the dashboard (UC-09, extension point "Export").
- **Main Success Scenario:**
  1. **Administrator:** Requests to export the dashboard figures.
  2. **System:** Asks for the export format (CSV or PDF).
  3. **Administrator:** Selects the format.
  4. **System:** Generates the export file with the period, the figures and the date the file was generated.
  5. **System:** Makes the file available for download.
  6. **System:** Returns control to UC-09.
- **Extensions:**
  - **3a. The administrator cancels the export:**
    - 3a1. System returns to UC-09 without generating any file.
  - **4a. The export file cannot be generated:**
    - 4a1. System informs the administrator and lets them try again. The dashboard stays available.

---

## UC-11: Configure Global System Parameters

- **ID / Code:** UC-11
- **Use Case Name:** Configure Global System Parameters
- **Description:** Lets the superadministrator set the global parameters that control invoicing and collection: default payment terms, the monthly invoicing date, and the reminder schedule.
- **Primary Actor:** Superadministrator
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** User Goal
- **Stakeholders & Interests:**
  - _Superadministrator:_ Wants to adjust the business rules without technical help, being the only person allowed to do so.
  - _Employees and Administrators:_ Want rules that are consistent and predictable for every client.
  - _Clients:_ Want payment terms and reminders that are clear and stable.
- **Preconditions:** The application is online and reachable from the superadministrator's device (NFR-02).
- **Success Guarantee:** The new parameter values are stored with their effective date and are used by every later invoice (FR-06) and reminder (FR-13). The change is recorded in the audit log (FR-03).
- **Minimal Guarantee:** Global parameters can only be changed by the Superadministrator (FR-02). Invoices that have already been issued keep the terms they were issued with.
- **Trigger:** The superadministrator requests to review or change the system configuration.
- **Main Success Scenario:**
  1. **Superadministrator:** Requests the global system configuration.
  2. **System:** Executes **UC-18: Authenticate & Check User Permissions** to verify that the user has the Superadministrator role (FR-02).
  3. **System:** Shows the current values: default payment terms (5 days), monthly invoice date (day 1), and reminder schedule (day 3, day 5, then every 2–3 days while overdue).
  4. **Superadministrator:** Changes one or more parameters.
  5. **System:** Checks the new values (for example, the monthly date is between 1 and the specified month's days, payment terms are positive, and reminder days do not conflict).
  6. **System:** Shows a summary of the changes and their effect: they apply to invoices and reminders generated from now on.
  7. **Superadministrator:** Confirms the changes.
  8. **System:** Stores the new values with their effective date (FR-06, FR-13).
  9. **System:** Executes **UC-17: Record Uneditable Audit Log** with the previous and new values (FR-03).
  10. **System:** Confirms that the configuration has been updated.
- **Extensions:**
  - **2a. The user does not have the Superadministrator role:**
    - 2a1. UC-18 denies access and records the attempt (NFR-04). The use case ends.
  - **5a. Invalid values:**
    - 5a1. System flags the incorrect parameters and the reason, and keeps the valid changes. The flow continues at step 4.
  - **6a. The reminder schedule changed and there are reminders already scheduled:**
    - 6a1. System asks whether the pending reminders should be moved to the new schedule or keep their current dates.
    - 6a2. Superadministrator chooses. System applies the choice at step 8.
  - **7a. The superadministrator does not confirm:**
    - 7a1. System discards the changes. The use case ends.

---

## UC-12: Assign User Roles

- **ID / Code:** UC-12
- **Use Case Name:** Assign User Roles
- **Description:** Allows the superadministrator to assign or modify the roles of registered users, controlling their access permissions within the application.
- **Primary Actor:** Superadministrator
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** User Goal
- **Stakeholders & Interests:**
  - _Superadministrator:_ Wants to control user permissions and ensure that employees have access to the functionality required for their responsibilities.
  - _Employees and Administrators:_ Want their assigned roles to provide the appropriate system permissions.
  - _TurbineH:_ Wants to prevent unauthorized access to sensitive financial information.
- **Preconditions:**
  - The superadministrator is authenticated.
  - The superadministrator has permission to manage user roles.
  - The user whose role will be modified exists in the system.
- **Success Guarantee:** The selected user's role is updated, the corresponding permissions are enforced, and the modification is recorded in the audit log.
- **Minimal Guarantee:** If the operation fails, the user's previous role and permissions remain unchanged.
- **Trigger:** The superadministrator requests to modify a user's role.
- **Main Success Scenario:**
  1. **Superadministrator:** Accesses the user management section.
  2. **System:** Displays the list of registered users and their assigned roles.
  3. **Superadministrator:** Selects a user.
  4. **System:** Displays the user's current role and available roles.
  5. **Superadministrator:** Selects a new role (`Employee` or `Administrator`).
  6. **Superadministrator:** Confirms the modification.
  7. **System:** Validates the requested role assignment.
  8. **System:** Updates the user's role and corresponding permissions.
  9. **System:** Records the modification in the audit log (FR-03).
  10. **System:** Confirms that the role has been updated successfully.
- **Extensions:**
  - **3a. The selected user no longer exists:**
    - 3a1. System informs the superadministrator that the user cannot be found.
    - 3a2. System returns to the user list.
  - **7a. The requested role assignment is invalid:**
    - 7a1. System rejects the modification.
    - 7a2. System displays an error message.
    - 7a3. Use case resumes at step 5.
  - **8a. The system cannot save the modification:**
    - 8a1. System preserves the user's previous role.
    - 8a2. System informs the superadministrator that the operation failed.
    - 8a3. Use case ends.

---

## UC-13: Access System Modification Log

- **ID / Code:** UC-13
- **Use Case Name:** Access System Modification Log
- **Description:** Allows the superadministrator to consult the history of sensitive operations performed within the application.
- **Primary Actor:** Superadministrator
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** User Goal
- **Stakeholders & Interests:**
  - _Superadministrator:_ Wants to review modifications made to the system and identify the users responsible.
  - _TurbineH:_ Wants to maintain traceability of sensitive operations.
  - _Employees and Administrators:_ Want modifications to be accurately attributed to the responsible users.
- **Preconditions:**
  - The superadministrator is authenticated.
  - The superadministrator has permission to access the audit log.
- **Success Guarantee:** The superadministrator can consult the recorded history of sensitive system operations without modifying the stored entries.
- **Minimal Guarantee:** The audit log remains unchanged regardless of whether the consultation succeeds or fails.
- **Trigger:** The superadministrator requests access to the system modification log.
- **Main Success Scenario:**
  1. **Superadministrator:** Accesses the audit log section.
  2. **System:** Retrieves the recorded sensitive operations.
  3. **System:** Displays the available log entries, ordered from most recent to oldest.
  4. **Superadministrator:** Selects a log entry.
  5. **System:** Displays the details of the selected operation.
  6. **Superadministrator:** Reviews the information.
- **Extensions:**
  - **2a. The system cannot retrieve the audit log:**
    - 2a1. System informs the superadministrator that the log is temporarily unavailable.
    - 2a2. Use case ends.
  - **3a. No audit entries exist:**
    - 3a1. System informs the superadministrator that no operations have been recorded.
    - 3a2. Use case ends.
  - **4a. The selected entry is no longer available:**
    - 4a1. System informs the superadministrator that the entry cannot be retrieved.
    - 4a2. System returns to the log overview.

---

## UC-14: Generate Corporate-Branded PDF

- **ID / Code:** UC-14
- **Use Case Name:** Generate Corporate-Branded PDF
- **Description:** Generates an invoice PDF using TurbineH's approved corporate identity and the corresponding invoice information.
- **Primary Actor:** None directly; invoked by another use case.
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** Subfunction
- **Stakeholders & Interests:**
  - _TurbineH:_ Wants all generated invoices to follow the company's corporate identity.
  - _Employees:_ Want invoice documents to be generated automatically without manual formatting.
  - _Clients:_ Want to receive clear, consistent invoice documents.
- **Preconditions:**
  - An invoice has been issued.
  - The required invoice information is available.
  - An approved corporate PDF template is available.
- **Success Guarantee:** A PDF document containing the invoice information and following TurbineH's approved corporate identity is successfully generated.
- **Minimal Guarantee:** If PDF generation fails, the system does not return an incomplete document as a successfully generated invoice.
- **Trigger:** A calling use case requests the generation of a PDF document for an issued invoice.
- **Main Success Scenario:**
  1. **System:** Receives a PDF generation request containing the invoice identifier.
  2. **System:** Retrieves the corresponding invoice information.
  3. **System:** Retrieves the approved corporate PDF template.
  4. **System:** Populates the template with the invoice information.
  5. **System:** Generates the PDF document.
  6. **System:** Makes the generated PDF available to the calling use case.
  7. **System:** Returns control to the calling use case.
- **Extensions:**
  - **2a. The invoice cannot be retrieved:**
    - 2a1. System reports that the requested invoice is unavailable.
    - 2a2. System returns a failure result to the calling use case.
    - 2a3. Use case ends.
  - **4a. Required invoice information is missing:**
    - 4a1. System identifies the missing information.
    - 4a2. System cancels PDF generation.
    - 4a3. System returns a failure result to the calling use case.
    - 4a4. Use case ends.
  - **5a. PDF generation fails:**
    - 5a1. System discards the incomplete document.
    - 5a2. System returns a failure result to the calling use case.
    - 5a3. Use case ends.

---

## UC-15: Send Invoices & Reminders

- **ID / Code:** UC-15
- **Use Case Name:** Send Invoices & Reminders
- **Description:** Sends issued invoices and payment reminders to clients through email and, when consented to, WhatsApp, recording the corresponding delivery statuses.
- **Primary Actor:** None directly; invoked by another use case or a configured reminder schedule.
- **Secondary Actor:** External Messaging Services
- **Scope:** TurbineH Invoicing & Subscription System
- **Level:** Subfunction
- **Stakeholders & Interests:**
  - _TurbineH:_ Wants invoices and payment reminders to be delivered efficiently.
  - _Employees:_ Want to track message delivery without manually contacting clients.
  - _Clients:_ Want to receive relevant financial communications through authorized channels.
- **Preconditions:**
  - An issued invoice exists.
  - The corresponding client has valid contact information for at least one permitted communication channel.
  - The system has received a request to send an invoice or reminder.
- **Success Guarantee:** The system submits the message through the applicable communication channels and records the delivery status reported by each external messaging service.
- **Minimal Guarantee:** If delivery fails, the system records the failure without incorrectly marking the message as delivered. The system does not send WhatsApp messages to clients who have not consented to that channel.
- **Trigger:** One of the following events occurs:
  - An invoice is issued.
  - A configured reminder becomes due.
  - An employee requests to resend a message.
- **Main Success Scenario:**
  1. **System:** Receives a request to send an invoice or payment reminder.
  2. **System:** Retrieves the corresponding invoice and client information.
  3. **System:** Verifies that the message is applicable to the invoice's current payment status.
  4. **System:** Identifies the client's permitted communication channels.
  5. **System:** Prepares the message using the approved corporate template.
  6. **System:** Sends the message through the External Messaging Services using the applicable channels.
  7. **External Messaging Services:** Return the available delivery information.
  8. **System:** Records the delivery status of each channel.
  9. **System:** Returns the operation result to the calling use case or scheduled process.
- **Extensions:**
  - **2a. The invoice cannot be retrieved:**
    - 2a1. System cancels the sending operation.
    - 2a2. System reports the failure to the calling process.
    - 2a3. Use case ends.
  - **3a. A scheduled payment reminder is no longer applicable because the invoice has been paid:**
    - 3a1. System cancels the reminder.
    - 3a2. Use case ends.
  - **4a. The client has not consented to WhatsApp communications:**
    - 4a1. System excludes WhatsApp from the permitted channels.
    - 4a2. Use case continues at step 5.
  - **4b. No permitted communication channel is available:**
    - 4b1. System cancels the sending operation.
    - 4b2. System reports that no permitted channel is available.
    - 4b3. Use case ends.
  - **6a. An external messaging service rejects the delivery request:**
    - 6a1. System records the failed attempt.
    - 6a2. System reports the failure to the calling process.
    - 6a3. Use case ends if no other channel remains available.
  - **7a. The external service has not yet confirmed delivery:**
    - 7a1. System records the message as pending delivery confirmation.
    - 7a2. System updates the recorded status when the external service provides further information.

---

## UC-16: Sync & Update Invoice Payment Status

- **ID / Code:** UC-16
- **Use Case Name:** Synchronize Payment Status
- **Description:** Receives or retrieves payment information from the External Payment Service (Stripe, simulated in this project), matches each payment to its invoice, and updates the invoice status automatically. It also marks invoices as overdue when they pass their due date unpaid.
- **Primary Actor:** **External Payment Service**. It is also executed through `«include»` by UC-04.
- **Scope:** TurbineH Invoicing & Subscription System (Payment Integration)
- **Level:** Subfunction
- **Stakeholders & Interests:**
  - _Employees:_ Want to be told as soon as a client of theirs has paid, and to stop chasing paid invoices.
  - _TurbineH (management):_ Wants payment tracking to be automatic, with no manual checking of Stripe or the bank account (BR-01, BR-02).
  - _Clients:_ Want their payment to be recognised straight away, so they stop receiving reminders.
- **Preconditions:** The integration with the External Payment Service is configured.
- **Success Guarantee:** Each payment received is matched to its invoice, and the invoice is marked `Paid` (FR-10, FR-14). Its pending reminders are cancelled (FR-13), and the assigned employee is notified (FR-15).
- **Minimal Guarantee:** An invoice is never marked as paid without a payment event that matches it. A payment event that has already been processed never changes any data.
- **Trigger:** The External Payment Service sends a payment event, the periodic synchronisation runs, or UC-04 (step 3) requests an update.
- **Main Success Scenario:**

1. **External Payment Service:** Reports one or more payment events (reference, amount, date).
2. **System:** Checks that each event really comes from the External Payment Service and has not already been processed.
3. **System:** Matches each payment to its invoice by payment reference and amount (FR-14).
4. **System:** Changes the invoice status to `Paid` and records the payment date and amount (FR-10).
5. **System:** Cancels the pending reminders of the invoice (FR-13).
6. **System:** Notifies the employee assigned to the client through their inbox (FR-15).
7. **System:** If the client's subscription is `Cancellation Pending Settlement` and no unpaid invoices remain, changes its status to `Cancelled` (FR-07).
8. **System:** Records the status change in the audit log (FR-03).

- **Extensions:**
  - **1a. The External Payment Service cannot be reached during the synchronisation:**
    - 1a1. System keeps the current statuses, logs the failed synchronisation, and tries again in the next cycle.
    - 1a2. System returns the time of the last successful synchronisation to the calling use case (UC-04 3a).
  - **2a. The event cannot be verified as coming from the External Payment Service:**
    - 2a1. System rejects the event without changing any data, and records the attempt (NFR-04).
  - **2b. The event has already been processed:**
    - 2b1. System ignores it without changing any data.
  - **3a. The payment cannot be matched to any invoice:**
    - 3a1. System stores the payment as unmatched and creates a reconciliation task in the administrators' inbox (FR-15). The flow continues with the next event.
  - **3b. The amount paid is different from the invoice amount:**
    - 3b1. System does not mark the invoice as `Paid`. It records the payment received and creates a task for the assigned employee to review the difference (FR-15).
  - **4a. An invoice reaches its due date with no matching payment:**
    - 4a1. System changes its status to `Overdue` (FR-10).
    - 4a2. System starts the periodic overdue reminder flow for it (FR-13) and adds it to the assigned employee's inbox (FR-15).

---

## UC-17: Record Uneditable Audit Log

- **ID / Code:** UC-17
- **Use Case Name:** Record Audit Entry
- **Description:** Adds an entry to the audit log for every sensitive operation. The entry records who did what, when, and on which data. Once written, an entry can never be changed or deleted.
- **Primary Actor:** None directly. It is executed through `«include»` by UC-02, UC-03, UC-07, UC-08, UC-11 and UC-12.
- **Scope:** TurbineH Invoicing & Subscription System (Audit Layer)
- **Level:** Subfunction
- **Stakeholders & Interests:**
  - _Superadministrator:_ Wants a complete and reliable history of sensitive operations (UR-12).
  - _TurbineH (management):_ Wants traceability for internal control and legal purposes, and protection of client tax data (NFR-04).
  - _Employees:_ Want their actions to be attributed to them correctly.
- **Preconditions:** The calling use case has completed a sensitive operation and provides its details.
- **Success Guarantee:** A new entry with the operation details is permanently added to the audit log (FR-03) and can be consulted through UC-13.
- **Minimal Guarantee:** No existing entry is ever changed or deleted. No sensitive operation is ever confirmed to the user without its audit entry.
- **Trigger:** Executed by a calling use case after a sensitive operation (see Primary Actor).
- **Main Success Scenario:**

1. **System:** Receives the operation details from the calling use case: user, role, operation type, affected record, previous and new values, and outcome.
2. **System:** Adds the timestamp of the operation.
3. **System:** Adds the entry to the audit log so that it can never be modified, and so that any change to it would be detected (FR-03).
4. **System:** Returns control to the calling use case.

- **Extensions:**
  - **3a. The audit log cannot be written:**
    - 3a1. System reverts the sensitive operation of the calling use case, so that no operation goes unrecorded.
    - 3a2. System informs the user that the operation could not be completed and should be tried again later.
    - 3a3. System records a technical failure for the Superadministrator.

---

## UC-18: Authenticate & Check User Permissions

- **ID / Code:** UC-18
- **Use Case Name:** Authenticate and Authorize User
- **Description:** Checks that the person using the application is a signed-in TurbineH staff member, signing them in with their `@turbineh.com` email and password if needed. It then checks that their role and assigned clients allow the operation they are attempting.
- **Primary Actor:** None directly. It is executed through `«include»` by every use case, on behalf of the Employee, Administrator or Superadministrator who started it.
- **Scope:** TurbineH Invoicing & Subscription System (Security Layer)
- **Level:** Subfunction
- **Stakeholders & Interests:**
  - _Employees, Administrators and Superadministrator:_ Want to sign in quickly from any device (NFR-02), without extra authentication steps.
  - _TurbineH (management):_ Wants only TurbineH staff to reach client tax and financial data, and each person only for their own role and clients (NFR-04).
  - _Clients:_ Want their data to be seen only by the staff who manage their account.
- **Preconditions:** The application is online and reachable from the user's device (NFR-02).
- **Success Guarantee:** The user has an authenticated session (FR-01), and the requested operation is allowed by their role and assigned clients (FR-02). Control returns to the calling use case.
- **Minimal Guarantee:** No operation is ever allowed for a user who is not authenticated, whose email is outside the `@turbineh.com` domain, or whose role or client scope does not permit it. Every failed or denied access is logged (NFR-04).
- **Trigger:** Any use case starts (see Primary Actor).
- **Main Success Scenario:**

1. **System:** Checks whether the user has an active, unexpired session.
2. **System:** Requests the company email address and the password, because no active session exists.
3. **User:** Enters the credentials and submits them.
4. **System:** Checks that the email address belongs to the `@turbineh.com` domain (FR-01).
5. **System:** Checks the password against the stored credentials of that account (FR-01).
6. **System:** Opens an authenticated session and loads the user's role (`Employee`, `Administrator` or `Superadministrator`) and assigned clients (FR-02).
7. **System:** Records the sign-in in the audit log (FR-03).
8. **System:** Checks that the user's role allows the requested operation and, for client-specific operations, that the client is within the user's scope (FR-02).
9. **System:** Returns control to the calling use case, which then continues.

- **Extensions:**
  - **1a. The user already has an active session:**
    - 1a1. System skips steps 2–7. The flow continues at step 8.
  - **3a. Missing mandatory fields:**
    - 3a1. System flags the empty fields and asks the user to complete them, keeping the data already entered. The flow continues at step 3.
  - **4a. Email outside the `@turbineh.com` domain:**
    - 4a1. System rejects the attempt without checking the password.
    - 4a2. System informs the user that only TurbineH company accounts can sign in.
    - 4a3. System records the blocked attempt in the audit log (NFR-04). The calling use case ends.
  - **5a. Invalid credentials:**
    - 5a1. System shows a generic message, "Invalid email or password", without revealing which of the two was wrong.
    - 5a2. System increases the failed-attempt counter of the account and records the attempt (NFR-04). The flow continues at step 2.
  - **5b. Account deactivated or without an assigned role:**
    - 5b1. System refuses to open a session, informs the user that they should contact the Superadministrator, and records the attempt (NFR-04). The calling use case ends.
  - **8a. The user's role or client scope does not allow the operation:**
    - 8a1. System denies the operation and informs the user that they do not have permission.
    - 8a2. System records the denied access in the audit log (NFR-04). The calling use case ends.

---

## Traceability Matrix

| Use Case | User Requirements | Functional Requirements | Non-Functional Requirements |
| -------- | ----------------- | ----------------------- | --------------------------- |
| UC-01 | UR-01 | FR-02, FR-06, FR-12, FR-13, FR-14, FR-15 | NFR-01, NFR-02 |
| UC-02 | UR-02 | FR-02, FR-03, FR-06, FR-07, FR-13 | NFR-04 |
| UC-03 | UR-03 | FR-02, FR-03, FR-09, FR-10, FR-11, FR-12, FR-13, FR-15 | NFR-01, NFR-03 |
| UC-04 | UR-04 | FR-02, FR-03, FR-10, FR-14 | NFR-01 |
| UC-05 | UR-05 | FR-02, FR-12, FR-13, FR-15 | NFR-04 |
| UC-06 | UR-06 | FR-02 | NFR-01, NFR-04 |
| UC-07 | UR-07 | FR-02, FR-03, FR-15 | NFR-04 |
| UC-08 | UR-08 | FR-03, FR-04, FR-05, FR-06 | NFR-02 |
| UC-09 | UR-09 | FR-02, FR-10, FR-14 | NFR-02, NFR-04 |
| UC-10 | UR-09 | — | NFR-04 |
| UC-11 | UR-10 | FR-02, FR-03, FR-06, FR-13 | NFR-04 |
| UC-12 | UR-11 | FR-01, FR-02, FR-03 | NFR-04 |
| UC-13 | UR-12 | FR-02, FR-03 | NFR-01, NFR-04 |
| UC-14 | — | FR-11 | NFR-03 |
| UC-15 | — | FR-12, FR-13, FR-15 | NFR-03 |
| UC-16 | — | FR-03, FR-07, FR-10, FR-13, FR-14, FR-15 | NFR-04 |
| UC-17 | UR-12 | FR-03 | NFR-04 |
| UC-18 | — | FR-01, FR-02, FR-03 | NFR-02, NFR-04 |
