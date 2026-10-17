# Software Requirements

> High-level specification outlining business goals, user needs, and technical behavior for TurbineH's internal invoicing, subscription, and payment tracking application.

## Definitions

- **Subscription/recurrent invoice**: A monthly payment given to clients using the Brain subcription.
- **One-off invoice**: A one-time payment to be fulfilled at a certain date.
- **Client**: Company subscribed to Brain OS.

## Business Requirements

> Answering the "What for?" or "Why?" of the business (commercial, financial, or strategic goals).

- **BR-01:** Facilitate invoice tracking and charges of the company's clients.

- **BR-02:** Improve efficiency of the financial team, minimizing manual intervention and clicks.

## User Requirements

> Answering "What does the user want to achieve?" (Customer or actor goals).

### Employee

- **UR-01:** The employee must be able to access a daily work inbox with upcoming invoices and notifications.

- **UR-02:** The employee must be able to modify/cancel their assigned clients' subscriptions.

- **UR-03:** The employee must be able to create and issue one-off invoices.

- **UR-04:** The employee must be able to track payment statuses of their assigned clients.

- **UR-05:** The employee must be able to resend and reschedule their assigned clients' message deliveries.

### Administrator

- **UR-06:** The administrator must be able to view all clients and invoices globally.

- **UR-07:** The administrator must be able to (un)assign clients to employees.

- **UR-08:** The administrator must be able to import client records in bulk via CSV.

- **UR-09:** The administrator must be able to consult the financial dashboard (weekly, monthly, quarterly, and annual) and export this data.

### Superadministrator

- **UR-10:** The superadministrator must be able to configure global system parameters (must include: default payment terms, monthly payment dates)

- **UR-11:** The superadministrator must be able to assign roles (employee / administrator) to users.

- **UR-12:** The superadministrator must be able to access a system log of modifications.

## System Requirements

> Technical translation of user and business goals into executable functional capabilities and quality constraints.

### Functional Requirements

> Answering "What the system does to fulfill user requirements?" or "How does the software react?" (Inputs, outputs, calculations, and technical behavior to fulfill UR-01).

- **FR-01:** The system must authenticate employees via company email (with domain `@turbineh.com`) and password.

- **FR-02:** The system must enforce permsissions across three roles (`Employee`, `Administrator`, `Superadministrator`).

- **FR-03:** The system must record an uneditable audit log of all sensitive operations.

- **FR-04:** The system must store client company records.

- **FR-05:** The system must allow importing clients via CSV.

- **FR-06:** The system must generate monthly invoices on a configurable day.

- **FR-07:** The system must allow pausing and cancelling active subscriptions, suspending new monthly invoice generation, while keeping existing unpaid invoices in the active collection flow until settled.

- **FR-08:** The system must support an annual review campaign to check client revenue against rate tiers, and propose price adjustments.

- **FR-09:** The system must support creating and issuing one-off invoices.

- **FR-10:** The system must update invoice status.

- **FR-11:** The system must generate corporate-branded PDF documents upon issuance.

- **FR-12:** The system must send issued invoices and reminders via email and WhatsApp, if consented, and log delivery statuses.

- **FR-13:** The system must allow reminder schedule configuration.

- **FR-14:** The system must integrate with payment sources and update its corresponding invoice status.

- **FR-15:** The system must provide an operational task inbox for all employees.

### Non-Functional Requirements

> Answering "How well?" or "Under what quality standards/restrictions does the system operate?" (Performance, security, usability).

- **NFR-01:** Operational Speed and Click Minimization
  - **Description:** Administrative operations must require minimal navigation and execute rapidly.
  - **Dependencies:** FR-04, FR-06, FR-09, FR-15
  - **Metric:** A trained user must complete standard client registration or invoice creation in less than 60 seconds and in 4 clicks or fewer from the main workspace. Standard search queries across 10,000+ records must return results in under 1.5 seconds.

- **NFR-02:** Multi-Device Compatibility
  - **Description:** The application must be accessible from desktop, tablet, and mobile.
  - **Dependencies:** None.
  - **Metric:** The application must execute on iOS, Android, Windows, macOS and Linux with a consistent and working layout.

- **NFR-03:** Corporate Identity on Generated Documents
  - **Description:** All generated invoice PDFs and client communications must strictly adhere to TurbineH's visual identity.
  - **Dependencies:** FR-11, FR-12
  - **Metric:** A designer must validate all templates of issued documents and client messages.

- **NFR-04:** Data Security
  - **Description:** Sensitive tax and financial documents must be protected against unauthorized access.
  - **Dependencies:** FR-01, FR-02, FR-03
  - **Metric:** 100% of unauthenticated or out-of-scope accesses must be blocked and logged.