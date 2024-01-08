import os
import functions_framework
import psycopg

sql_user = os.environ['SQL_USER']
sql_pass = os.environ['SQL_PASSWORD']
sql_connection_name = os.environ['SQL_CONNECTION']
unix_socket = f'/cloudsql/{sql_connection_name}'


@functions_framework.http
def hello_http(request):
    with psycopg.connect(f"dbname=defaultdb user={sql_user} password={sql_pass} host={unix_socket}") as conn:
        # Open a cursor to perform database operations
        with conn.cursor() as cur:
            # Execute a command: this creates a new table
            cur.execute("""
                   CREATE TABLE IF NOT EXISTS test (
                       id serial PRIMARY KEY,
                       num integer,
                       data text)
                   """)

            # Pass data to fill a query placeholders and let Psycopg perform
            # the correct conversion (no SQL injections!)
            cur.execute(
                "INSERT INTO test (num, data) VALUES (%s, %s)",
                (100, "abc'def"))

            # Query the database and obtain data as Python objects.
            cur.execute("SELECT * FROM test")
            cur.fetchone()
            # will return (1, 100, "abc'def")

            # You can use `cur.fetchmany()`, `cur.fetchall()` to return a list
            # of several records, or even iterate on the cursor
            for record in cur:
                print(record)

            # Make the changes to the database persistent
            conn.commit()
    try:
        return str(record)
    except (NameError, UnboundLocalError):
        return "No records found"
