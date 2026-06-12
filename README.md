# VaultManager Pro

VaultManager Pro is a Flask-based banking management system connected to Microsoft SQL Server. It provides separate dashboards for Admin and Manager users, with tools for managing customers, accounts, transactions, loans, account status, fraud-related transaction blocking, and end-of-month repayment processing.

---

## Features

### Authentication & Roles

- Login system using SQL Server stored procedure authentication
- Session-based access control
- Separate dashboards for:
  - **Admin**
  - **Manager**

### Admin Module

- View system overview statistics
- View recent transactions
- View and manage accounts
- Freeze and unfreeze accounts
- View loan records
- Update loan status
- Run end-of-month loan repayment processing

### Manager Module

- Add new customers
- Auto-display generated customer ID after customer creation
- Open new bank accounts for existing customers
- Deposit and withdraw funds
- Transfer money between accounts
- Apply for loans
- View customers, accounts, and loans
- Deactivate, reactivate, or delete accounts
- Run end-of-month processing

### Loan Automation

The system includes automated loan risk assessment. When a manager submits a loan application, the SQL procedure automatically assigns the loan decision and interest rate based on the customer's active account balance.

| Customer Balance vs Loan Amount | Decision | Interest Rate |
|---|---:|---:|
| Balance >= 50% of loan amount | Auto-Approved | 4.5% |
| Balance between 10% and 49% | Auto-Approved | 8.5% |
| Balance < 10% | Rejected - High Risk | 0% |

### Fraud Detection

The transaction workflow includes SQL trigger-based fraud detection for suspicious withdrawals. The app catches SQL errors raised by the fraud trigger and displays a fraud alert message in the dashboard.

Suspicious withdrawal conditions include:

- Withdrawal amount greater than 10,000
- Withdrawal that empties the account balance

### End-of-Month Processing

The system can process monthly repayments for auto-approved loans.

It performs the following steps:

1. Finds all loans with `Auto-Approved` status.
2. Calculates installment as:

   ```text
   Loan Amount / Duration Months
   ```

3. Deducts the installment from the customer's oldest active account with enough balance.
4. Marks the loan as `Defaulted` if no active account can cover the installment.
5. Returns a summary of processed and defaulted loans.

---

## Tech Stack

- **Backend:** Python, Flask
- **Database:** Microsoft SQL Server
- **Database Driver:** pyodbc
- **Frontend:** HTML, CSS, Jinja2 templates
- **Authentication:** SQL Server stored procedure + Flask sessions

---

## Project Structure

```text
VaultManager-Pro/
│
├── app.py
├── sql_file.sql
├── README.md
│
└── templates/
    ├── login.html
    ├── admin_dashboard.html
    ├── manager_dashboard.html
    ├── add_customer.html
    ├── add_account.html
    ├── transaction.html
    ├── transfer.html
    ├── add_loan.html
    ├── update_loan.html
    ├── view_accounts.html
    ├── view_customers.html
    ├── view_loans.html
    ├── deactivate_account.html
    └── eom_processing.html
```

> Flask expects all HTML files to be inside a folder named `templates`.

---

## Database Setup

The database script creates the database, tables, seed users, stored procedures, triggers, and views.

### Database Name

```text
Vault_Pro
```

### Main Tables

- `customers`
- `accounts`
- `transactions`
- `users`
- `loans`

### Main Stored Procedures

- `LoginSystem`
- `InsertCustomer`
- `InsertAccount`
- `InsertTransactions`
- `Transfermoney`
- `InsertLoan`
- `UpdateLoanStatus`
- `FreezeAccount`
- `DeactivateAccount`
- `DeleteAccount`
- `ProcessMonthlyRepayments`

### Main Triggers

- `tr_update_account`
- `tr_fraud_detection`

### Main Views

- `AdminOverview`
- `ViewAllTransactions`
- `AccountSummary`
- `View_Total_Accounts_Customer`
- `ViewAllLoans`

---

## Installation & Setup

### 1. Clone the repository

```bash
git clone https://github.com/your-username/VaultManager-Pro.git
cd VaultManager-Pro
```

### 2. Create a virtual environment

```bash
python -m venv venv
```

Activate it:

**Windows:**

```bash
venv\Scripts\activate
```

**macOS/Linux:**

```bash
source venv/bin/activate
```

### 3. Install dependencies

```bash
pip install flask pyodbc
```

Optional: create a `requirements.txt` file:

```bash
pip freeze > requirements.txt
```

### 4. Install SQL Server ODBC Driver

Install **ODBC Driver 18 for SQL Server** before running the Flask app.

### 5. Create the database

Open `sql_file.sql` in SQL Server Management Studio and execute the full script.

Or run it with `sqlcmd`:

```bash
sqlcmd -S localhost\SQLEXPRESS -E -C -i sql_file.sql
```

### 6. Check database connection settings

In `app.py`, update the connection settings if your SQL Server instance is different:

```python
DB_CONFIG = {
    'DRIVER': '{ODBC Driver 18 for SQL Server}',
    'SERVER': 'localhost\\SQLEXPRESS',
    'DATABASE': 'Vault_Pro'
}
```

The current configuration uses Windows Authentication:

```text
Trusted_Connection=yes
```

---

## Run the Application

```bash
python app.py
```

Then open your browser:

```text
http://127.0.0.1:5000/
```

---

## Demo Login Credentials

These users are inserted by the SQL seed data. Change them before using the project in a real environment.

| Role | Username | Password |
|---|---|---|
| Admin | `Admin001` | `admin123` |
| Manager | `Moheez123` | `123abc` |

---

## Routes Overview

| Route | Description | Access |
|---|---|---|
| `/` | Login page | Public |
| `/admin_dashboard` | Admin overview dashboard | Admin |
| `/manager_dashboard` | Manager operations dashboard | Manager |
| `/add_customer` | Add a new customer | Manager |
| `/add_account` | Open a new bank account | Manager |
| `/transaction` | Deposit or withdraw money | Manager |
| `/transfer` | Transfer money between accounts | Manager |
| `/add_loan` | Submit loan application | Manager |
| `/update_loan` | Update loan status | Admin / Manager |
| `/run_eom_processing` | Run monthly loan repayment processing | Admin / Manager |
| `/view_accounts` | View account records | Logged-in users |
| `/view_customers` | View customer records | Logged-in users |
| `/view_loans` | View loan records | Logged-in users |
| `/freeze_account/<account_id>/<action>` | Freeze or unfreeze account | Admin |
| `/deactivate_account` | Deactivate, reactivate, or delete account | Manager |
| `/logout` | End user session | Logged-in users |

---

## Security Notes

This project is suitable for learning, demos, and academic submissions. Before using it in production, improve the following:

- Move `secret_key` and database settings to environment variables
- Hash passwords instead of storing plain text passwords
- Add stronger form validation
- Add CSRF protection
- Restrict debug mode in production
- Use role permissions consistently across all routes
- Use parameterized queries everywhere, as already done in the main database calls

---

## Future Improvements

- Add customer dashboard
- Add password hashing with Werkzeug
- Add export reports as CSV/PDF
- Add search and filters for transactions and loans
- Add pagination for large tables
- Add charts for admin and manager analytics
- Add audit logs for sensitive actions

---

## Author

**Moheez Azam Kiani**

---

## License

This project is for educational purposes.
