-- ============================================================
--  NexaVault_Pro  --  Full Schema + Business Logic (T-SQL)
-- ============================================================

CREATE DATABASE Vault_Pro;
GO
USE Vault_Pro;
GO

-- ==================== TABLES ====================

CREATE TABLE customers (
    customer_id  INT           IDENTITY(1,1) PRIMARY KEY,
    name         VARCHAR(100),
    email        VARCHAR(150)  UNIQUE,
    phone        VARCHAR(20)   UNIQUE
);

CREATE TABLE accounts (
    account_id   INT            IDENTITY(1,1) PRIMARY KEY,
    customer_id  INT            NULL,
    balance      DECIMAL(10,2)  DEFAULT 0,
    account_type VARCHAR(20),
    status       VARCHAR(10)    DEFAULT 'Active',
    FOREIGN KEY (customer_id) REFERENCES dbo.customers(customer_id)
);

CREATE TABLE transactions (
    transaction_id   INT            IDENTITY(1,1) PRIMARY KEY,
    account_id       INT            NULL,
    amount           DECIMAL(10,2),
    type             VARCHAR(20),
    transaction_time DATETIME       DEFAULT GETDATE(),
    FOREIGN KEY (account_id) REFERENCES dbo.accounts(account_id)
);

CREATE TABLE users (
    user_id  INT          IDENTITY(1,1) PRIMARY KEY,
    username VARCHAR(100) UNIQUE,
    password VARCHAR(200),
    role     VARCHAR(20)
);

CREATE TABLE loans (
    loan_id        INT            IDENTITY(1,1) PRIMARY KEY,
    customer_id    INT            NULL,
    loan_amount    DECIMAL(10,2),
    interest_rate  DECIMAL(5,2),
    duration_months INT,
    status         VARCHAR(30)    DEFAULT 'Pending',
    created_at     DATETIME       DEFAULT GETDATE(),
    FOREIGN KEY (customer_id) REFERENCES dbo.customers(customer_id)
);

-- ==================== SEED DATA ====================

INSERT INTO users (username, password, role) VALUES
('Moheez123', '123abc',   'Manager'),
('Admin001',  'admin123', 'Admin'),
('zabii',     '123',      'customer');
GO

-- ==================== FUNCTION: getBalance ====================

CREATE FUNCTION dbo.getBalance(@acc_id INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @bal DECIMAL(10,2);
    SELECT @bal = balance FROM accounts WHERE account_id = @acc_id;
    RETURN ISNULL(@bal, 0.00);
END;
GO

-- ==================== PROCEDURES ====================

-- ----- InsertCustomer -----
CREATE PROCEDURE dbo.InsertCustomer
    @cust_name    VARCHAR(100),
    @e_mail       VARCHAR(150),
    @phone_number VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.customers WHERE name = @cust_name)
    BEGIN
        SELECT 'A customer with this name already exists.' AS STATUS;
        RETURN;
    END

    IF @e_mail NOT LIKE '%@%.%'
    BEGIN
        SELECT 'Invalid email address. Must contain @ and a domain.' AS STATUS;
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.customers (name, email, phone)
        VALUES (@cust_name, @e_mail, @phone_number);
        SELECT 'Customer added successfully' AS STATUS;
    END TRY
    BEGIN CATCH
        SELECT 'This email or phone number is already in use.' AS STATUS;
    END CATCH
END;
GO

-- ----- InsertAccount -----
CREATE PROCEDURE dbo.InsertAccount
    @cust_id INT,
    @bal     DECIMAL(18,2),
    @type    VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO accounts (customer_id, balance, account_type)
        VALUES (@cust_id, @bal, @type);
        SELECT 'Account added successfully' AS STATUS;
    END TRY
    BEGIN CATCH
        SELECT 'Invalid customer ID, balance or type' AS STATUS;
    END CATCH
END;
GO

-- ----- InsertTransactions -----
CREATE PROCEDURE dbo.InsertTransactions
    @acc_id INT,
    @amo    DECIMAL(18,2),
    @t_type VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @bal DECIMAL(18,2);

    BEGIN TRY
        IF EXISTS (
            SELECT 1 FROM accounts
            WHERE account_id = @acc_id AND status IN ('Frozen','Inactive')
        )
        BEGIN
            SELECT 'Account is frozen or inactive. Transaction not allowed.' AS STATUS;
            RETURN;
        END

        SET @bal = dbo.getBalance(@acc_id);

        IF (@t_type = 'Deposit'    AND @amo > 0)
        OR (@t_type = 'Withdrawal' AND @amo <= @bal AND @amo > 0)
        BEGIN
            INSERT INTO transactions (account_id, amount, type)
            VALUES (@acc_id, @amo, @t_type);
            SELECT 'Transaction completed successfully' AS STATUS;
        END
        ELSE
        BEGIN
            SELECT 'Enter a valid amount' AS STATUS;
        END
    END TRY
    BEGIN CATCH
        SELECT 'Invalid account ID, amount or type' AS STATUS;
    END CATCH
END;
GO

-- ----- Transfermoney -----
CREATE PROCEDURE dbo.Transfermoney
    @from_acc INT,
    @to_acc   INT,
    @amo      DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @from_bal DECIMAL(18,2);

    BEGIN TRY
        SET @from_bal = dbo.getBalance(@from_acc);

        IF @amo <= @from_bal AND @amo > 0
        BEGIN
            EXEC dbo.InsertTransactions @from_acc, @amo, 'Withdrawal';
            EXEC dbo.InsertTransactions @to_acc,   @amo, 'Deposit';
            SELECT 'Money transferred successfully' AS STATUS;
        END
        ELSE
        BEGIN
            SELECT 'Enter a valid amount' AS STATUS;
        END
    END TRY
    BEGIN CATCH
        SELECT 'Enter valid account number or amount' AS STATUS;
    END CATCH
END;
GO

-- ----- InsertUser -----
CREATE PROCEDURE dbo.InsertUser
    @user_name VARCHAR(100),
    @pass      VARCHAR(200),
    @rol       VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO users (username, password, role)
        VALUES (@user_name, @pass, @rol);
        SELECT 'User inserted successfully' AS STATUS;
    END TRY
    BEGIN CATCH
        SELECT 'An error occurred during insertion' AS STATUS;
    END CATCH
END;
GO

-- ----- LoginSystem -----
CREATE PROCEDURE dbo.LoginSystem
    @user_name VARCHAR(100),
    @pass      VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @user_role VARCHAR(20);

    BEGIN TRY
        SELECT @user_role = role
        FROM users
        WHERE username = @user_name AND password = @pass;

        IF @user_role IS NOT NULL
            SELECT 'Login Successfull' AS STATUS, @user_role AS ROLE;
        ELSE
            SELECT 'Login Failed. Invalid username or password' AS STATUS, NULL AS ROLE;
    END TRY
    BEGIN CATCH
        SELECT 'Enter username of 100 characters and password of 200 characters' AS STATUS, NULL AS ROLE;
    END CATCH
END;
GO

-- ----- FreezeAccount -----
CREATE PROCEDURE dbo.FreezeAccount
    @acc_id     INT,
    @new_status VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE accounts SET status = @new_status WHERE account_id = @acc_id;

    IF @@ROWCOUNT > 0
        SELECT 'Account status updated successfully' AS STATUS;
    ELSE
        SELECT 'Invalid account ID' AS STATUS;
END;
GO

-- ----- DeactivateAccount -----
CREATE PROCEDURE dbo.DeactivateAccount
    @acc_id INT,
    @action VARCHAR(12)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @new_status VARCHAR(20);

    IF @action = 'deactivate'
        SET @new_status = 'Inactive';
    ELSE IF @action = 'reactivate'
        SET @new_status = 'Active';
    ELSE
    BEGIN
        SELECT 'Invalid action. Use deactivate or reactivate.' AS STATUS;
        RETURN;
    END

    BEGIN TRY
        UPDATE dbo.accounts SET status = @new_status WHERE account_id = @acc_id;

        IF @@ROWCOUNT > 0
            SELECT 'Account ' + @new_status + ' successfully' AS STATUS;
        ELSE
            SELECT 'Invalid account ID' AS STATUS;
    END TRY
    BEGIN CATCH
        SELECT 'An error occurred while updating account status' AS STATUS;
    END CATCH
END;
GO

-- ----- DeleteAccount -----
CREATE PROCEDURE dbo.DeleteAccount
    @acc_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM dbo.transactions WHERE account_id = @acc_id)
        BEGIN
            SELECT 'Cannot delete: account has transaction history. Deactivate it instead.' AS STATUS;
            RETURN;
        END

        DELETE FROM dbo.accounts WHERE account_id = @acc_id;

        IF @@ROWCOUNT > 0
            SELECT 'Account deleted successfully' AS STATUS;
        ELSE
            SELECT 'Invalid account ID' AS STATUS;
    END TRY
    BEGIN CATCH
        SELECT 'Error deleting account' AS STATUS;
    END CATCH
END;
GO

-- ============================================================
--  FEATURE 1: Automated Loan Approval (Algorithmic Risk Assessment)
--  The procedure auto-calculates interest_rate and status based
--  on the customer's total Active account balance vs loan amount.
--  The manager only supplies: customer_id, loan_amount, duration.
-- ============================================================

CREATE PROCEDURE dbo.InsertLoan
    @cust_id       INT,
    @loan_amount   DECIMAL(10,2),
    @loan_term     INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @total_balance  DECIMAL(10,2);
    DECLARE @interest_rate  DECIMAL(5,2);
    DECLARE @loan_status    VARCHAR(30);
    DECLARE @decision_note  VARCHAR(200);

    -- Sum all Active account balances for this customer
    SELECT @total_balance = ISNULL(SUM(balance), 0)
    FROM   dbo.accounts
    WHERE  customer_id = @cust_id
      AND  status = 'Active';

    -- Risk assessment logic
    IF @total_balance < (@loan_amount * 0.10)
    BEGIN
        -- High risk: balance covers less than 10% of loan
        SET @loan_status   = 'Rejected - High Risk';
        SET @interest_rate = 0.00;
        SET @decision_note = 'Auto-rejected: total balance is less than 10% of the requested loan amount.';
    END
    ELSE IF @total_balance >= (@loan_amount * 0.50)
    BEGIN
        -- Low risk: balance covers 50%+ of loan
        SET @loan_status   = 'Auto-Approved';
        SET @interest_rate = 4.50;
        SET @decision_note = 'Auto-approved at preferential rate (4.5%): strong collateral balance detected.';
    END
    ELSE
    BEGIN
        -- Standard risk: between 10% and 50%
        SET @loan_status   = 'Auto-Approved';
        SET @interest_rate = 8.50;
        SET @decision_note = 'Auto-approved at standard rate (8.5%): moderate collateral balance detected.';
    END

    BEGIN TRY
        INSERT INTO dbo.loans
            (customer_id, loan_amount, interest_rate, duration_months, status)
        VALUES
            (@cust_id, @loan_amount, @interest_rate, @loan_term, @loan_status);

        -- Return both a STATUS and the AI decision note so the UI can display them
        SELECT
            'Loan processed successfully' AS STATUS,
            @loan_status                  AS DECISION,
            @interest_rate                AS ASSIGNED_RATE,
            @decision_note                AS NOTE;
    END TRY
    BEGIN CATCH
        SELECT
            'Invalid loan details or customer ID' AS STATUS,
            NULL AS DECISION,
            NULL AS ASSIGNED_RATE,
            NULL AS NOTE;
    END CATCH
END;
GO

-- ----- UpdateLoanStatus (unchanged) -----
CREATE PROCEDURE dbo.UpdateLoanStatus
    @p_loan_id INT,
    @p_status  VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE dbo.loans SET status = @p_status WHERE loan_id = @p_loan_id;

        IF @@ROWCOUNT > 0
            SELECT 'Loan status updated successfully' AS STATUS;
        ELSE
            SELECT 'Loan ID not found' AS STATUS;
    END TRY
    BEGIN CATCH
        SELECT 'Invalid loan ID or status' AS STATUS;
    END CATCH
END;
GO

-- ============================================================
--  FEATURE 3: Automated Monthly Loan Repayments
--  Finds all Auto-Approved loans, calculates the monthly
--  installment, and deducts it from the customer's oldest
--  Active account. Marks the loan 'Defaulted' if insufficient.
-- ============================================================

CREATE PROCEDURE dbo.ProcessMonthlyRepayments
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @loan_id         INT;
    DECLARE @cust_id         INT;
    DECLARE @loan_amount     DECIMAL(10,2);
    DECLARE @duration_months INT;
    DECLARE @installment     DECIMAL(10,2);
    DECLARE @acc_id          INT;
    DECLARE @acc_balance     DECIMAL(10,2);

    DECLARE @processed_count INT = 0;
    DECLARE @defaulted_count INT = 0;

    -- Cursor over all currently Auto-Approved loans
    DECLARE loan_cursor CURSOR FOR
        SELECT loan_id, customer_id, loan_amount, duration_months
        FROM   dbo.loans
        WHERE  status = 'Auto-Approved';

    OPEN loan_cursor;
    FETCH NEXT FROM loan_cursor INTO @loan_id, @cust_id, @loan_amount, @duration_months;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Basic installment: principal divided by term (no compounding for simplicity)
        SET @installment = ROUND(@loan_amount / @duration_months, 2);

        -- Find the customer's oldest Active account with enough balance
        SELECT TOP 1
            @acc_id      = account_id,
            @acc_balance = balance
        FROM  dbo.accounts
        WHERE customer_id = @cust_id
          AND status      = 'Active'
          AND balance     >= @installment
        ORDER BY account_id ASC;   -- oldest account first

        IF @acc_id IS NOT NULL
        BEGIN
            -- Deduct the installment via the existing transaction procedure
            -- (this also fires tr_update_account to update the balance)
            INSERT INTO dbo.transactions (account_id, amount, type)
            VALUES (@acc_id, @installment, 'Withdrawal');

            SET @processed_count += 1;
        END
        ELSE
        BEGIN
            -- Customer cannot cover installment — mark as Defaulted
            UPDATE dbo.loans SET status = 'Defaulted' WHERE loan_id = @loan_id;
            SET @defaulted_count += 1;
        END

        -- Reset for next row
        SET @acc_id = NULL;

        FETCH NEXT FROM loan_cursor INTO @loan_id, @cust_id, @loan_amount, @duration_months;
    END

    CLOSE loan_cursor;
    DEALLOCATE loan_cursor;

    -- Return summary row that Python will read
    SELECT
        @processed_count AS PROCESSED,
        @defaulted_count AS DEFAULTED;
END;
GO

-- ==================== TRIGGERS ====================

-- ----- tr_update_account (balance sync — unchanged) -----
CREATE TRIGGER tr_update_account
ON transactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE a
    SET a.balance = a.balance +
        CASE WHEN i.type = 'Deposit' THEN i.amount ELSE -i.amount END
    FROM accounts a
    JOIN inserted i ON a.account_id = i.account_id;
END;
GO

-- ============================================================
--  FEATURE 2: Fraud Detection & Security Trigger
--  Fires AFTER INSERT on transactions.
--  Blocks and rolls back if:
--    (a) A withdrawal exceeds $10,000, OR
--    (b) A withdrawal exactly empties the account (balance would reach 0).
--  In both cases the account is immediately frozen.
-- ============================================================

CREATE TRIGGER tr_fraud_detection
ON transactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @acc_id     INT;
    DECLARE @amount     DECIMAL(10,2);
    DECLARE @t_type     VARCHAR(20);
    DECLARE @new_balance DECIMAL(10,2);

    SELECT
        @acc_id  = account_id,
        @amount  = amount,
        @t_type  = type
    FROM inserted;

    -- Only evaluate withdrawals
    IF @t_type = 'Withdrawal'
    BEGIN
        -- Current balance AFTER tr_update_account has already fired
        SELECT @new_balance = balance
        FROM   dbo.accounts
        WHERE  account_id = @acc_id;

        IF @amount > 10000 OR @new_balance = 0
        BEGIN
            -- Freeze the account immediately
            UPDATE dbo.accounts
            SET    status = 'Frozen'
            WHERE  account_id = @acc_id;

            -- Roll back the transaction and surface the error to the caller
            ROLLBACK TRANSACTION;

            RAISERROR(
                'Transaction blocked due to suspicious activity. Account frozen.',
                16, 1
            );
        END
    END
END;
GO

-- ==================== VIEWS ====================

CREATE VIEW dbo.ViewAllTransactions AS
SELECT
    t.transaction_id,
    t.account_id,
    c.name   AS customer_name,
    t.amount,
    t.type,
    t.transaction_time
FROM transactions t
JOIN accounts  a ON t.account_id  = a.account_id
JOIN customers c ON a.customer_id = c.customer_id;
GO

CREATE VIEW dbo.AccountSummary AS
SELECT a.account_id, c.name, a.balance, a.account_type, a.status
FROM   dbo.customers c
INNER JOIN dbo.accounts a ON c.customer_id = a.customer_id;
GO

CREATE VIEW dbo.View_Total_Accounts_Customer AS
SELECT c.name, c.email, COUNT(a.account_id) AS Total_Accounts
FROM   dbo.customers c
LEFT JOIN dbo.accounts a ON c.customer_id = a.customer_id
GROUP BY c.name, c.email;
GO

CREATE VIEW dbo.AdminOverview AS
SELECT
    (SELECT COUNT(*)               FROM dbo.customers)                         AS Total_Customers,
    (SELECT COUNT(*)               FROM dbo.accounts)                          AS Total_Accounts,
    (SELECT ISNULL(SUM(balance),0) FROM dbo.accounts)                          AS Total_Balance,
    (SELECT COUNT(*)               FROM dbo.transactions)                      AS Total_Transactions,
    (SELECT COUNT(*)               FROM dbo.accounts WHERE status='Inactive')  AS Inactive_Accounts;
GO

CREATE VIEW dbo.ViewAllLoans AS
SELECT
    l.loan_id,
    c.name           AS customer_name,
    l.loan_amount,
    l.interest_rate,
    l.duration_months,
    l.status,
    l.created_at
FROM dbo.loans     l
JOIN dbo.customers c ON l.customer_id = c.customer_id;
GO
