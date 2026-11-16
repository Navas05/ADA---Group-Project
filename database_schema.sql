-- ============================================================
--  TurbineH Invoicing & Subscription System
--  Physical database schema (MySQL 8.0)
--  Submission 2 - Issue #13 / #25
--  Matches physical_entity_relationship_diagram.pu
-- ============================================================

CREATE DATABASE IF NOT EXISTS turbineh_invoicing
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE turbineh_invoicing;

-- ------------------------------------------------------------
-- Users and security (FR-01, FR-02, UC-12, UC-18)
-- ------------------------------------------------------------

CREATE TABLE users (
  user_id          INT AUTO_INCREMENT PRIMARY KEY,
  email            VARCHAR(100) NOT NULL UNIQUE,
  password_hash    VARCHAR(255) NOT NULL,
  full_name        VARCHAR(100) NOT NULL,
  role             ENUM('EMPLOYEE','ADMINISTRATOR','SUPERADMINISTRATOR') NULL,
  active           BOOLEAN NOT NULL DEFAULT TRUE,
  failed_attempts  INT NOT NULL DEFAULT 0,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_users_email_domain CHECK (email LIKE '%@turbineh.com'),
  CONSTRAINT chk_users_failed_attempts CHECK (failed_attempts >= 0)
);

CREATE TABLE sessions (
  session_id  INT AUTO_INCREMENT PRIMARY KEY,
  user_id     INT NOT NULL,
  token       VARCHAR(255) NOT NULL UNIQUE,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at  DATETIME NOT NULL,
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id)
    REFERENCES users(user_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- Clients (FR-04, FR-05, UC-06, UC-07, UC-08)
-- ------------------------------------------------------------

CREATE TABLE clients (
  client_id         INT AUTO_INCREMENT PRIMARY KEY,
  company_name      VARCHAR(150) NOT NULL,
  tax_id            VARCHAR(20) NOT NULL UNIQUE,
  address           VARCHAR(200),
  city              VARCHAR(80),
  business_area     VARCHAR(80),
  email             VARCHAR(100) NOT NULL,
  phone             VARCHAR(20),
  email_consent     BOOLEAN NOT NULL DEFAULT TRUE,
  whatsapp_consent  BOOLEAN NOT NULL DEFAULT FALSE,
  active            BOOLEAN NOT NULL DEFAULT TRUE,   -- logical delete (UC-08 ext. 7c)
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_clients_company_name ON clients(company_name);
CREATE INDEX idx_clients_city_area    ON clients(city, business_area);

CREATE TABLE client_assignments (
  assignment_id  INT AUTO_INCREMENT PRIMARY KEY,
  client_id      INT NOT NULL,
  employee_id    INT NOT NULL,
  assigned_by    INT NOT NULL,
  assigned_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  unassigned_at  DATETIME NULL,                     -- NULL = active assignment
  CONSTRAINT fk_assign_client   FOREIGN KEY (client_id)   REFERENCES clients(client_id),
  CONSTRAINT fk_assign_employee FOREIGN KEY (employee_id) REFERENCES users(user_id),
  CONSTRAINT fk_assign_admin    FOREIGN KEY (assigned_by) REFERENCES users(user_id),
  CONSTRAINT chk_assign_dates CHECK (unassigned_at IS NULL OR unassigned_at >= assigned_at)
);

CREATE INDEX idx_assign_employee ON client_assignments(employee_id, unassigned_at);

-- ------------------------------------------------------------
-- Subscriptions and invoices (FR-06, FR-07, FR-09, FR-10, FR-11)
-- ------------------------------------------------------------

CREATE TABLE subscriptions (
  subscription_id    INT AUTO_INCREMENT PRIMARY KEY,
  client_id          INT NOT NULL UNIQUE,
  monthly_fee        DECIMAL(10,2) NOT NULL,
  status             ENUM('ACTIVE','PAUSED','CANCELLATION_PENDING_SETTLEMENT','CANCELLED')
                     NOT NULL DEFAULT 'ACTIVE',
  start_date         DATE NOT NULL,
  next_billing_date  DATE,
  end_date           DATE,
  CONSTRAINT fk_subscription_client FOREIGN KEY (client_id) REFERENCES clients(client_id),
  CONSTRAINT chk_subscription_fee CHECK (monthly_fee > 0)
);

CREATE TABLE invoices (
  invoice_id       INT AUTO_INCREMENT PRIMARY KEY,
  invoice_number   VARCHAR(20) NULL UNIQUE,          -- NULL while it is a draft
  client_id        INT NOT NULL,
  subscription_id  INT NULL,                         -- NULL = one-off invoice
  created_by       INT NOT NULL,
  type             ENUM('RECURRING','ONE_OFF') NOT NULL,
  status           ENUM('DRAFT','SCHEDULED','ISSUED','PENDING_DELIVERY','PAID','OVERDUE','CANCELLED')
                   NOT NULL DEFAULT 'DRAFT',
  issue_date       DATE,
  due_date         DATE NOT NULL,
  taxable_base     DECIMAL(10,2) NOT NULL DEFAULT 0,
  vat_rate         DECIMAL(5,2)  NOT NULL DEFAULT 21.00,
  vat_amount       DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_amount     DECIMAL(10,2) NOT NULL DEFAULT 0,
  pdf_path         VARCHAR(255),
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_invoice_client       FOREIGN KEY (client_id)       REFERENCES clients(client_id),
  CONSTRAINT fk_invoice_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions(subscription_id),
  CONSTRAINT fk_invoice_creator      FOREIGN KEY (created_by)      REFERENCES users(user_id),
  CONSTRAINT chk_invoice_dates  CHECK (issue_date IS NULL OR due_date >= issue_date),
  CONSTRAINT chk_invoice_amount CHECK (total_amount >= 0),
  CONSTRAINT chk_invoice_type   CHECK (
    (type = 'ONE_OFF'   AND subscription_id IS NULL) OR
    (type = 'RECURRING' AND subscription_id IS NOT NULL)
  )
);

CREATE INDEX idx_invoices_status   ON invoices(status);
CREATE INDEX idx_invoices_due_date ON invoices(due_date);
CREATE INDEX idx_invoices_client   ON invoices(client_id, status);

CREATE TABLE invoice_lines (
  line_id     INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id  INT NOT NULL,
  concept     VARCHAR(200) NOT NULL,
  quantity    DECIMAL(10,2) NOT NULL,
  unit_price  DECIMAL(10,2) NOT NULL,
  line_total  DECIMAL(10,2) NOT NULL,
  CONSTRAINT fk_line_invoice FOREIGN KEY (invoice_id)
    REFERENCES invoices(invoice_id) ON DELETE CASCADE,
  CONSTRAINT chk_line_values CHECK (quantity > 0 AND unit_price >= 0)
);

-- Gap-free sequential numbering per year (UC-03 minimal guarantee).
-- The number is taken with SELECT ... FOR UPDATE inside the same
-- transaction that issues the invoice.
CREATE TABLE invoice_sequences (
  year         INT PRIMARY KEY,
  last_number  INT NOT NULL DEFAULT 0
);

-- ------------------------------------------------------------
-- Payments (FR-14, UC-16)
-- ------------------------------------------------------------

CREATE TABLE payments (
  payment_id          INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id          INT NULL,                      -- NULL = unmatched payment
  external_reference  VARCHAR(100) NOT NULL UNIQUE,  -- avoids processing an event twice
  amount              DECIMAL(10,2) NOT NULL,
  payment_date        DATETIME NOT NULL,
  status              ENUM('MATCHED','UNMATCHED','AMOUNT_MISMATCH') NOT NULL,
  received_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_payment_invoice FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
);

-- ------------------------------------------------------------
-- Communications (FR-12, FR-13, UC-05, UC-15)
-- ------------------------------------------------------------

CREATE TABLE reminders (
  reminder_id    INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id     INT NOT NULL,
  scheduled_at   DATETIME NOT NULL,
  send_email     BOOLEAN NOT NULL DEFAULT TRUE,
  send_whatsapp  BOOLEAN NOT NULL DEFAULT FALSE,
  status         ENUM('PENDING','SENT','CANCELLED') NOT NULL DEFAULT 'PENDING',
  CONSTRAINT fk_reminder_invoice FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
);

CREATE INDEX idx_reminders_pending ON reminders(status, scheduled_at);

CREATE TABLE message_deliveries (
  delivery_id          INT AUTO_INCREMENT PRIMARY KEY,
  invoice_id           INT NOT NULL,
  reminder_id          INT NULL,                     -- NULL = invoice delivery
  message_type         ENUM('INVOICE','REMINDER') NOT NULL,
  channel              ENUM('EMAIL','WHATSAPP') NOT NULL,
  status               ENUM('PENDING_CONFIRMATION','DELIVERED','FAILED') NOT NULL,
  sent_at              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  external_message_id  VARCHAR(100),
  error_message        VARCHAR(255),
  CONSTRAINT fk_delivery_invoice  FOREIGN KEY (invoice_id)  REFERENCES invoices(invoice_id),
  CONSTRAINT fk_delivery_reminder FOREIGN KEY (reminder_id) REFERENCES reminders(reminder_id)
);

-- ------------------------------------------------------------
-- Inbox, configuration and audit (FR-15, UC-11, FR-03, UC-17)
-- ------------------------------------------------------------

CREATE TABLE inbox_tasks (
  task_id           INT AUTO_INCREMENT PRIMARY KEY,
  assigned_user_id  INT NULL,                        -- NULL = administrators' inbox
  client_id         INT NOT NULL,
  invoice_id        INT NULL,
  task_type         ENUM('INVOICE_DUE','REMINDER_TODAY','OVERDUE','PAYMENT_CONFIRMED',
                         'DELIVERY_FAILED','RECONCILIATION','AMOUNT_MISMATCH') NOT NULL,
  priority          TINYINT NOT NULL DEFAULT 3,      -- 1 = highest, 5 = lowest
  status            ENUM('PENDING','RESOLVED') NOT NULL DEFAULT 'PENDING',
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_at       DATETIME NULL,
  CONSTRAINT fk_task_user    FOREIGN KEY (assigned_user_id) REFERENCES users(user_id),
  CONSTRAINT fk_task_client  FOREIGN KEY (client_id)        REFERENCES clients(client_id),
  CONSTRAINT fk_task_invoice FOREIGN KEY (invoice_id)       REFERENCES invoices(invoice_id),
  CONSTRAINT chk_task_priority CHECK (priority BETWEEN 1 AND 5)
);

CREATE INDEX idx_tasks_inbox ON inbox_tasks(assigned_user_id, status, priority);

CREATE TABLE system_parameters (
  parameter_id    INT AUTO_INCREMENT PRIMARY KEY,
  param_key       VARCHAR(50) NOT NULL,
  param_value     VARCHAR(255) NOT NULL,
  effective_from  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by      INT NOT NULL,
  CONSTRAINT fk_param_user FOREIGN KEY (updated_by) REFERENCES users(user_id),
  CONSTRAINT uq_param_version UNIQUE (param_key, effective_from)
);

CREATE TABLE audit_log (
  log_id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id             INT NULL,                      -- NULL for unknown users (failed sign-in)
  user_role           VARCHAR(30),
  operation_type      VARCHAR(50) NOT NULL,
  affected_table      VARCHAR(50),
  affected_record_id  INT,
  previous_value      TEXT,
  new_value           TEXT,
  outcome             ENUM('SUCCESS','DENIED','FAILED') NOT NULL,
  ip_address          VARCHAR(45),
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE INDEX idx_audit_created ON audit_log(created_at);

-- The audit log can never be modified or deleted (FR-03, UC-17)
DELIMITER //

CREATE TRIGGER trg_audit_log_no_update
BEFORE UPDATE ON audit_log
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_log entries cannot be modified';
END//

CREATE TRIGGER trg_audit_log_no_delete
BEFORE DELETE ON audit_log
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_log entries cannot be deleted';
END//

DELIMITER ;

-- ------------------------------------------------------------
-- Application database user: only the permissions it needs.
-- On audit_log it can only INSERT and SELECT.
-- ------------------------------------------------------------
-- CREATE USER 'turbineh_app'@'%' IDENTIFIED BY '<password>';
-- Permissions are granted table by table, for example:
-- GRANT SELECT, INSERT, UPDATE, DELETE ON turbineh_invoicing.invoices TO 'turbineh_app'@'%';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON turbineh_invoicing.clients  TO 'turbineh_app'@'%';
-- ... (same for the rest of the tables)
-- GRANT SELECT, INSERT ON turbineh_invoicing.audit_log TO 'turbineh_app'@'%';  -- no UPDATE/DELETE

-- ------------------------------------------------------------
-- Default global parameters (UC-11, step 3)
-- user_id 1 is the initial superadministrator
-- ------------------------------------------------------------
INSERT INTO users (email, password_hash, full_name, role)
VALUES ('superadmin@turbineh.com', '<bcrypt-hash>', 'Initial Superadministrator', 'SUPERADMINISTRATOR');

INSERT INTO system_parameters (param_key, param_value, updated_by) VALUES
  ('DEFAULT_PAYMENT_TERMS_DAYS', '5',      1),
  ('MONTHLY_INVOICE_DAY',        '1',      1),
  ('REMINDER_SCHEDULE_DAYS',     '3,5',    1),
  ('OVERDUE_REMINDER_INTERVAL',  '2',      1),
  ('DEFAULT_VAT_RATE',           '21.00',  1);
