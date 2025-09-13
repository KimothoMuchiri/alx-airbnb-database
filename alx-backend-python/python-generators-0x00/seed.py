import mysql.connector
import uuid
import csv
import sys
from mysql.connector import Error

DB_NAME = "ALX_prodev"
TABLE_NAME = "user_data"
CSV_FILE = "D:/ALX_backend/alx-airbnb-database/alx-backend-python/python-generators-0x00/data.csv"

def connect_db():
    """Connects to the MySQL database server."""
    try:
        connection = mysql.connector.connect(
            host="localhost",
            user= USER,
            password= PASSWORD
        )
        if connection.is_connected():
            print("Successfully connected to MySQL server!")
        return connection
    except Error as e:
        print(f"Error connecting to MySQL: {e}")
        return None

def create_database(connection):
    """Creates the ALX_prodev database if it does not exist."""
    query = f"CREATE DATABASE IF NOT EXISTS {DB_NAME}"
    try:
        with connection.cursor() as cursor:
            cursor.execute(query)
            print(f"Database {DB_NAME} created successfully!")
    except Error as e:
        print(f"Error creating the database: {e}")

def connect_to_prodev():
    """Connects to the ALX_prodev database."""
    try:
        connection = mysql.connector.connect(
            host="localhost",
            user= USER,
            password= PASSWORD,
            database=DB_NAME
        )
        if connection.is_connected():
            print(f"Successfully connected to the {DB_NAME} database!")
        return connection
    except Error as e:
        print(f"Error connecting to {DB_NAME}: {e}")
        return None

def create_table(connection):
    """Creates a table user_data if it does not exist."""
    query = f"""
    CREATE TABLE IF NOT EXISTS {TABLE_NAME} (
        user_id CHAR(36),
        name VARCHAR(100) NOT NULL,
        email VARCHAR(255) NOT NULL,
        age DECIMAL(5,2) NOT NULL,
        PRIMARY KEY (user_id)
    )"""
    try:
        with connection.cursor() as cursor:
            cursor.execute(query)
            print(f"Table {TABLE_NAME} created successfully!")
    except Error as e:
        print(f"Error creating the table: {e}")

def insert_data(connection, data):
    """Inserts data from a CSV file into the database."""
    query = f"INSERT INTO {TABLE_NAME} (user_id, name, email, age) VALUES (%s, %s, %s, %s)"
    try:
        with connection.cursor() as cursor:
            with open(data, 'r') as csvfile:
                csvreader = csv.reader(csvfile)
                next(csvreader, None)  # Skip the header row
                for row in csvreader:
                    user_id = str(uuid.uuid4())
                    data_tuple = (user_id, row[0], row[1], float(row[2]))
                    cursor.execute(query, data_tuple)
        connection.commit()
        print("Data inserted successfully!")
    except Error as e:
        print(f"Error inserting data: {e}")

# The generator function you just perfected
def stream_rows():
    """A generator that streams rows from the database one by one."""
    connection = None
    try:
        connection = connect_to_prodev()
        query = f"SELECT * FROM {TABLE_NAME}"
        with connection.cursor(dictionary=True) as cursor:
            cursor.execute(query)
            for row in cursor:
                yield row
    finally:
        if connection and connection.is_connected():
            connection.close()
            print("Database connection closed.")

def main():
    # Step 1-3: Connect to server, create database, and close connection
    server_conn = connect_db()
    if server_conn:
        create_database(server_conn)
        server_conn.close()

    # Step 4-6: Connect to the new database, create the table, and insert data
    db_conn = connect_to_prodev()
    if db_conn:
        create_table(db_conn)
        if db_conn.cursor().rowcount == 0:  # Check if the table is empty
            insert_data(db_conn, CSV_FILE)
        db_conn.close()

    # Step 7-8: Use the generator to stream the data
    print("\n--- Streaming data from the database ---")
    row_count = 0
    for row in stream_rows():
        print(f"Processing row: {row}")
        row_count += 1
        if row_count >= 5:  # Let's just process a few rows to demonstrate
            print("Stopping after processing 5 rows to save memory.")
            break
    print(f"\nCompleted streaming process. Processed {row_count} rows.")

if __name__ == '__main__':
    # Make sure you have the CSV file and your MySQL server is running
    # You also need to replace 'your_username' and 'your_password' with your actual credentials.
    main()