"""
High School Management System API

A super simple FastAPI application that allows students to view and sign up
for extracurricular activities at Mergington High School.
"""

from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse
import os
from pathlib import Path

import sqlite3
import json

app = FastAPI(title="Mergington High School API",
              description="API for viewing and signing up for extracurricular activities")

# Mount the static files directory
current_dir = Path(__file__).parent
app.mount("/static", StaticFiles(directory=os.path.join(Path(__file__).parent,
          "static")), name="static")

# Données d'exemple utilisées uniquement pour pré-peupler la base au démarrage.
ACTIVITIES_DATA = {
    "Chess Club": {
        "description": "Learn strategies and compete in chess tournaments",
        "schedule": "Fridays, 3:30 PM - 5:00 PM",
        "max_participants": 12,
        "participants": ["michael@mergington.edu", "daniel@mergington.edu"]
    },
    "Programming Class": {
        "description": "Learn programming fundamentals and build software projects",
        "schedule": "Tuesdays and Thursdays, 3:30 PM - 4:30 PM",
        "max_participants": 20,
        "participants": ["emma@mergington.edu", "sophia@mergington.edu"]
    },
    "Gym Class": {
        "description": "Physical education and sports activities",
        "schedule": "Mondays, Wednesdays, Fridays, 2:00 PM - 3:00 PM",
        "max_participants": 30,
        "participants": ["john@mergington.edu", "olivia@mergington.edu"]
    },
    "Soccer Team": {
        "description": "Inter-school soccer team training and matches",
        "schedule": "Mondays, Wednesdays, 4:00 PM - 6:00 PM",
        "max_participants": 22,
        "participants": ["liam@mergington.edu", "ava@mergington.edu"]
    },
    "Track and Field": {
        "description": "Sprinting, distance running, jumps and throws practice",
        "schedule": "Tuesdays and Thursdays, 4:00 PM - 5:30 PM",
        "max_participants": 40,
        "participants": ["noah@mergington.edu", "mia@mergington.edu"]
    },
    "Art Studio": {
        "description": "Open studio for drawing, painting and mixed media projects",
        "schedule": "Wednesdays, 3:30 PM - 5:30 PM",
        "max_participants": 18,
        "participants": ["isabella@mergington.edu", "lucas@mergington.edu"]
    },
    "Drama Club": {
        "description": "Acting workshops and school play productions",
        "schedule": "Fridays, 4:00 PM - 6:00 PM",
        "max_participants": 25,
        "participants": ["charlotte@mergington.edu", "jack@mergington.edu"]
    },
    "Science Club": {
        "description": "Hands-on experiments, science fairs and guest lectures",
        "schedule": "Thursdays, 3:30 PM - 5:00 PM",
        "max_participants": 20,
        "participants": ["amelia@mergington.edu", "ethan@mergington.edu"]
    },
    "Debate Team": {
        "description": "Competitive debate practice and tournament preparation",
        "schedule": "Mondays and Wednesdays, 5:00 PM - 6:30 PM",
        "max_participants": 16,
        "participants": ["harper@mergington.edu", "owen@mergington.edu"]
    }
}


DB_PATH = os.path.join(Path(__file__).parent.parent, "data", "activities.db")


def _ensure_db_dir():
    db_dir = os.path.dirname(DB_PATH)
    os.makedirs(db_dir, exist_ok=True)


def _get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    # Return rows as dict-like
    conn.row_factory = sqlite3.Row
    return conn


def _init_db():
    _ensure_db_dir()
    conn = _get_db_connection()
    cur = conn.cursor()
    # Table activities: name (primary key), description, schedule, max_participants, participants (JSON stored as TEXT)
    cur.execute('''
    CREATE TABLE IF NOT EXISTS activities (
        name TEXT PRIMARY KEY,
        description TEXT,
        schedule TEXT,
        max_participants INTEGER,
        participants TEXT
    )
    ''')
    conn.commit()
    # Pré-peupler (INSERT OR REPLACE)
    for name, data in ACTIVITIES_DATA.items():
        cur.execute('''
        INSERT OR REPLACE INTO activities (name, description, schedule, max_participants, participants)
        VALUES (?, ?, ?, ?, ?)
        ''', (name, data["description"], data["schedule"], data["max_participants"], json.dumps(data["participants"])))
    conn.commit()
    conn.close()


@app.on_event("startup")
def startup_db():
    _init_db()
    # store path for later use
    app.state.db_path = DB_PATH


@app.on_event("shutdown")
def shutdown_db():
    # nothing to close for sqlite connections opened per-request
    pass


@app.get("/")
def root():
    return RedirectResponse(url="/static/index.html")


@app.get("/activities")
def get_activities():
    """Retourne toutes les activités depuis MongoDB sous la forme {name: details}"""
    conn = _get_db_connection()
    cur = conn.cursor()
    cur.execute('SELECT name, description, schedule, max_participants, participants FROM activities')
    rows = cur.fetchall()
    result = {}
    for r in rows:
        participants = []
        try:
            participants = json.loads(r["participants"]) if r["participants"] else []
        except Exception:
            participants = []
        result[r["name"]] = {
            "description": r["description"] or "",
            "schedule": r["schedule"] or "",
            "max_participants": r["max_participants"] or 0,
            "participants": participants,
        }
    conn.close()
    return result
