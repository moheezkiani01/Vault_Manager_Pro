from flask import Flask, render_template, request, redirect, url_for, session, flash
import pyodbc

app = Flask(__name__)
app.secret_key = 'supersecretkey'

DB_CONFIG = {
    'DRIVER': '{ODBC Driver 18 for SQL Server}',
    'SERVER': 'localhost\\SQLEXPRESS',
    'DATABASE': 'Vault_Pro'
}

def get_connection_string():
    return (
        f"DRIVER={DB_CONFIG['DRIVER']};"
        f"SERVER={DB_CONFIG['SERVER']};"
        f"DATABASE={DB_CONFIG['DATABASE']};"
        "Trusted_Connection=yes;"
        "TrustServerCertificate=yes;"
    )

def get_db_connection():
    try:
        return pyodbc.connect(get_connection_string(), autocommit=True)
    except Exception as e:
        print(f"DB Error: {e}")
        return None


# ================= LOGIN =================
@app.route('/', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            try:
                cursor.execute("EXEC dbo.LoginSystem ?, ?", (username, password))
                res = cursor.fetchone()

                if res and res[0] == 'Login Successfull':
                    session['username'] = username
                    session['role'] = res[1]
                    flash('Login successful!', 'success')

                    if res[1] == 'Admin':
                        return redirect(url_for('admin_dashboard'))
                    elif res[1] == 'Manager':
                        return redirect(url_for('manager_dashboard'))
                    else:
                        flash('Role not recognized. Contact administrator.', 'danger')
                else:
                    flash('Invalid username or password.', 'danger')

            except Exception as e:
                flash(f"Error: {e}", 'danger')
            finally:
                cursor.close()
                conn.close()

    return render_template('login.html')


# ================= ADMIN DASHBOARD =================
@app.route('/admin_dashboard')
def admin_dashboard():
    if 'username' not in session or session.get('role') != 'Admin':
        flash('Access denied. Admins only.', 'danger')
        return redirect(url_for('login'))

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM dbo.AdminOverview")
    overview = cursor.fetchone()

    cursor.execute("SELECT * FROM ViewAllTransactions ORDER BY transaction_time DESC")
    transactions = cursor.fetchall()

    cursor.execute("""
        SELECT a.account_id, c.name, a.balance, a.account_type, a.status
        FROM dbo.accounts a
        JOIN dbo.customers c ON a.customer_id = c.customer_id
    """)
    accounts = cursor.fetchall()

    cursor.execute("SELECT * FROM dbo.ViewAllLoans ORDER BY created_at DESC")
    loans = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template(
        'admin_dashboard.html',
        overview=overview,
        transactions=transactions,
        accounts=accounts,
        loans=loans
    )


# ================= MANAGER DASHBOARD =================
@app.route('/manager_dashboard')
def manager_dashboard():
    if 'username' not in session or session.get('role') != 'Manager':
        flash('Access denied. Managers only.', 'danger')
        return redirect(url_for('login'))

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) FROM dbo.customers")
    total_customers = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM dbo.accounts")
    total_accounts = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM dbo.loans WHERE status = 'Pending'")
    pending_loans = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM dbo.transactions")
    total_transactions = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM dbo.accounts WHERE status = 'Inactive'")
    inactive_accounts = cursor.fetchone()[0]

    cursor.close()
    conn.close()

    return render_template(
        'manager_dashboard.html',
        total_customers=total_customers,
        total_accounts=total_accounts,
        pending_loans=pending_loans,
        total_transactions=total_transactions,
        inactive_accounts=inactive_accounts
    )


# ================= ADD CUSTOMER =================
@app.route('/add_customer', methods=['GET', 'POST'])
def add_customer():
    if 'username' not in session or session.get('role') != 'Manager':
        flash('Access denied.', 'danger')
        return redirect(url_for('login'))

    new_customer_id = None

    if request.method == 'POST':
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            try:
                cursor.execute(
                    "EXEC dbo.InsertCustomer ?, ?, ?",
                    (request.form['name'], request.form['email'], request.form['phone'])
                )
                result = cursor.fetchone()
                msg = result[0] if result else 'Operation completed.'

                if 'successfully' in msg.lower():
                    cursor.execute(
                        "SELECT customer_id FROM dbo.customers WHERE name = ? AND email = ?",
                        (request.form['name'], request.form['email'])
                    )
                    id_row = cursor.fetchone()
                    if id_row:
                        new_customer_id = id_row[0]
                        session['last_customer_id'] = new_customer_id
                        flash(f"Customer added successfully! Assigned Customer ID: {new_customer_id}", 'success')
                    else:
                        flash(msg, 'success')
                else:
                    flash(msg, 'danger')
            except Exception as e:
                flash(str(e), 'danger')
            finally:
                cursor.close()
                conn.close()

    return render_template('add_customer.html', new_customer_id=new_customer_id)


# ================= ADD ACCOUNT =================
@app.route('/add_account', methods=['GET', 'POST'])
def add_account():
    if 'username' not in session or session.get('role') != 'Manager':
        flash('Access denied.', 'danger')
        return redirect(url_for('login'))

    customers = []
    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        try:
            cursor.execute("SELECT customer_id, name FROM dbo.customers ORDER BY name")
            customers = cursor.fetchall()
        except Exception as e:
            flash(f"Could not load customers: {e}", 'danger')
        finally:
            cursor.close()
            conn.close()

    preselected_id = session.get('last_customer_id')

    if request.method == 'POST':
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            try:
                cursor.execute(
                    "EXEC dbo.InsertAccount ?, ?, ?",
                    (request.form['customer_id'], request.form['balance'], request.form['account_type'])
                )
                result = cursor.fetchone()
                msg = result[0] if result else 'Operation completed.'
                if 'successfully' in msg.lower():
                    session.pop('last_customer_id', None)
                    flash(msg, 'success')
                else:
                    flash(msg, 'danger')
            except Exception as e:
                flash(str(e), 'danger')
            finally:
                cursor.close()
                conn.close()

    return render_template('add_account.html', customers=customers, preselected_id=preselected_id)


# ================= TRANSACTION =================
# Feature 2: The fraud-detection trigger raises a SQL error on suspicious
# withdrawals. pyodbc surfaces this as an exception, which we catch and
# display via flash() so the user sees the freeze notification.
@app.route('/transaction', methods=['GET', 'POST'])
def transaction():
    if 'username' not in session or session.get('role') != 'Manager':
        flash('Access denied.', 'danger')
        return redirect(url_for('login'))

    if request.method == 'POST':
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            try:
                cursor.execute(
                    "EXEC dbo.InsertTransactions ?, ?, ?",
                    (request.form['account_id'], request.form['amount'], request.form['type'])
                )
                result = cursor.fetchone()
                msg = result[0] if result else 'Done'
                flash(msg, 'success' if 'successfully' in msg.lower() else 'danger')
            except pyodbc.Error as e:
                # Catches the RAISERROR from tr_fraud_detection
                # The SQL error message is in e.args[1]
                err_msg = str(e.args[1]) if len(e.args) > 1 else str(e)
                if 'suspicious activity' in err_msg.lower():
                    flash(f"🚨 FRAUD ALERT: {err_msg}", 'danger')
                else:
                    flash(f"Transaction error: {err_msg}", 'danger')
            except Exception as e:
                flash(str(e), 'danger')
            finally:
                cursor.close()
                conn.close()

    return render_template('transaction.html')


# ================= TRANSFER =================
# Feature 2: Same fraud-detection error handling applied to transfers.
@app.route('/transfer', methods=['GET', 'POST'])
def transfer():
    if 'username' not in session or session.get('role') != 'Manager':
        flash('Access denied.', 'danger')
        return redirect(url_for('login'))

    if request.method == 'POST':
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            try:
                cursor.execute(
                    "EXEC dbo.Transfermoney ?, ?, ?",
                    (request.form['from_account'], request.form['to_account'], request.form['amount'])
                )
                result = cursor.fetchone()
                msg = result[0] if result else 'Done'
                flash(msg, 'success' if 'successfully' in msg.lower() else 'danger')
            except pyodbc.Error as e:
                err_msg = str(e.args[1]) if len(e.args) > 1 else str(e)
                if 'suspicious activity' in err_msg.lower():
                    flash(f"🚨 FRAUD ALERT: {err_msg}", 'danger')
                else:
                    flash(f"Transfer error: {err_msg}", 'danger')
            except Exception as e:
                flash(str(e), 'danger')
            finally:
                cursor.close()
                conn.close()

    return render_template('transfer.html')


# ================= LOANS =================
# Feature 1: The updated InsertLoan procedure now handles interest_rate
# and loan_status automatically. We only send customer_id, loan_amount,
# and loan_term. The procedure returns a 4-column result we display.
@app.route('/add_loan', methods=['GET', 'POST'])
def add_loan():
    if 'username' not in session or session.get('role') != 'Manager':
        flash('Access denied.', 'danger')
        return redirect(url_for('login'))

    customers = []
    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        try:
            cursor.execute("SELECT customer_id, name FROM dbo.customers ORDER BY name")
            customers = cursor.fetchall()
        except Exception:
            pass
        finally:
            cursor.close()
            conn.close()

    if request.method == 'POST':
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            try:
                # Only 3 parameters now — no interest_rate or loan_status from the form
                cursor.execute(
                    "EXEC dbo.InsertLoan ?, ?, ?",
                    (
                        request.form['customer_id'],
                        request.form['loan_amount'],
                        request.form['loan_term'],
                    )
                )
                result = cursor.fetchone()
                if result:
                    status_msg  = result[0]   # "Loan processed successfully" or error
                    decision    = result[1]   # e.g. "Auto-Approved" / "Rejected - High Risk"
                    rate        = result[2]   # assigned interest rate
                    note        = result[3]   # human-readable decision explanation

                    if 'successfully' in status_msg.lower():
                        flash(
                            f"✅ {decision} | Rate: {rate}% | {note}",
                            'success' if 'approved' in decision.lower() else 'warning'
                        )
                    else:
                        flash(status_msg, 'danger')
                else:
                    flash('No response from server.', 'danger')
            except Exception as e:
                flash(str(e), 'danger')
            finally:
                cursor.close()
                conn.close()

    return render_template('add_loan.html', customers=customers)


@app.route('/update_loan', methods=['GET', 'POST'])
def update_loan():
    if 'username' not in session or session.get('role') not in ['Admin', 'Manager']:
        flash('Access denied.', 'danger')
        return redirect(url_for('login'))

    loans = []
    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        try:
            cursor.execute("SELECT loan_id, customer_name, loan_amount, status FROM dbo.ViewAllLoans ORDER BY loan_id")
            loans = cursor.fetchall()
        except Exception:
            pass
        finally:
            cursor.close()
            conn.close()

    if request.method == 'POST':
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            try:
                cursor.execute(
                    "EXEC dbo.UpdateLoanStatus ?, ?",
                    (request.form['loan_id'], request.form['new_status'])
                )
                result = cursor.fetchone()
                msg = result[0] if result else 'Done'
                flash(msg, 'success' if 'successfully' in msg.lower() else 'danger')
            except Exception as e:
                flash(str(e), 'danger')
            finally:
                cursor.close()
                conn.close()

    return render_template('update_loan.html', loans=loans)


# ================= FEATURE 3: End-of-Month Processing =================
# Accessible to Admin and Manager only. Calls ProcessMonthlyRepayments
# and flashes a summary of how many loans were collected vs defaulted.
@app.route('/run_eom_processing', methods=['GET', 'POST'])
def run_eom_processing():
    if 'username' not in session or session.get('role') not in ['Admin', 'Manager']:
        flash('Access denied. Admin or Manager role required.', 'danger')
        return redirect(url_for('login'))

    if request.method == 'POST':
        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            try:
                cursor.execute("EXEC dbo.ProcessMonthlyRepayments")
                result = cursor.fetchone()

                if result:
                    processed = result[0]
                    defaulted = result[1]
                    flash(
                        f"✅ End-of-Month Processing complete. "
                        f"Payments collected: {processed} | Loans defaulted: {defaulted}",
                        'success'
                    )
                else:
                    flash("Processing ran but returned no summary.", 'warning')

            except Exception as e:
                flash(f"EOM Processing error: {e}", 'danger')
            finally:
                cursor.close()
                conn.close()

    # GET request — just render the confirmation page
    return render_template('eom_processing.html')


# ================= VIEWS =================
@app.route('/view_accounts')
def view_accounts():
    if 'username' not in session:
        return redirect(url_for('login'))
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM dbo.AccountSummary")
    data = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('view_accounts.html', accounts=data)


@app.route('/view_customers')
def view_customers():
    if 'username' not in session:
        return redirect(url_for('login'))
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM dbo.View_Total_Accounts_Customer")
    data = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('view_customers.html', customers=data)


@app.route('/view_loans')
def view_loans():
    if 'username' not in session:
        return redirect(url_for('login'))
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM dbo.ViewAllLoans ORDER BY created_at DESC")
        loans = cursor.fetchall()
        return render_template('view_loans.html', loans=loans)
    except Exception as e:
        flash(f"Error: {e}", 'danger')
        return redirect(url_for('manager_dashboard'))
    finally:
        cursor.close()
        conn.close()


# ================= FREEZE ACCOUNT (Admin only) =================
@app.route('/freeze_account/<int:account_id>/<string:action>')
def freeze_account(account_id, action):
    if 'username' not in session or session.get('role') != 'Admin':
        flash('Access denied. Admins only.', 'danger')
        return redirect(url_for('login'))

    conn = get_db_connection()
    cursor = conn.cursor()
    status = 'Frozen' if action == 'freeze' else 'Active'
    cursor.execute("EXEC dbo.FreezeAccount ?, ?", (account_id, status))
    cursor.close()
    conn.close()
    return redirect(url_for('admin_dashboard'))


# ================= DEACTIVATE / DELETE ACCOUNT (Manager) =================
@app.route('/deactivate_account', methods=['GET', 'POST'])
def deactivate_account():
    if 'username' not in session or session.get('role') != 'Manager':
        flash('Access denied. Managers only.', 'danger')
        return redirect(url_for('login'))

    accounts = []
    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        try:
            cursor.execute("""
                SELECT a.account_id, c.name, a.account_type, a.balance, a.status
                FROM dbo.accounts a
                JOIN dbo.customers c ON a.customer_id = c.customer_id
                ORDER BY a.account_id
            """)
            accounts = cursor.fetchall()
        except Exception as e:
            flash(f"Could not load accounts: {e}", 'danger')
        finally:
            cursor.close()
            conn.close()

    if request.method == 'POST':
        action     = request.form.get('action')
        account_id = request.form.get('account_id')

        conn = get_db_connection()
        if conn:
            cursor = conn.cursor()
            try:
                if action == 'delete':
                    cursor.execute("EXEC dbo.DeleteAccount ?", (account_id,))
                else:
                    cursor.execute("EXEC dbo.DeactivateAccount ?, ?", (account_id, action))

                result = cursor.fetchone()
                msg = result[0] if result else 'Done'
                flash(msg, 'success' if 'successfully' in msg.lower() else 'danger')
            except Exception as e:
                flash(str(e), 'danger')
            finally:
                cursor.close()
                conn.close()

        return redirect(url_for('deactivate_account'))

    return render_template('deactivate_account.html', accounts=accounts)


# ================= LOGOUT =================
@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))


if __name__ == '__main__':
    app.run(debug=True)
