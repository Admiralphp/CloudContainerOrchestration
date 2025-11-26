from flask import Flask, request, render_template
import pymysql
import os

app = Flask(__name__)

DB_HOST = os.environ.get("DB_HOST", "db-service")
DB_PORT = int(os.environ.get("DB_PORT", "3306"))
DB_USER = os.environ.get("DB_USER", "appuser")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "apppassword")
DB_NAME = os.environ.get("DB_NAME", "appdb")


def get_connection():
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor,
    )


@app.route("/", methods=["GET", "POST"])
def index():
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                '''
                CREATE TABLE IF NOT EXISTS people (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(255),
                    email VARCHAR(255)
                );
                '''
            )
            conn.commit()

            if request.method == "POST":
                name = request.form.get("name")
                email = request.form.get("email")
                if name and email:
                    cursor.execute(
                        "INSERT INTO people (name, email) VALUES (%s, %s);",
                        (name, email),
                    )
                    conn.commit()

            cursor.execute("SELECT id, name, email FROM people;")
            rows = cursor.fetchall()
    finally:
        conn.close()

    return render_template("index.html", people=rows)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
