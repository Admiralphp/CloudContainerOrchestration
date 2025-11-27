import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [tasks, setTasks] = useState([]);
  const [newTask, setNewTask] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [apiStatus, setApiStatus] = useState('checking...');

  // Récupérer l'URL de l'API depuis window.ENV (injecté par ConfigMap)
  const API_URL = window.ENV?.API_URL || 'http://localhost:5000/api';

  // Vérifier la santé de l'API
  useEffect(() => {
    checkApiHealth();
  }, []);

  const checkApiHealth = async () => {
    try {
      const response = await axios.get(`${API_URL}/health`);
      setApiStatus(`✓ Connected (${response.data.status})`);
    } catch (err) {
      setApiStatus('✗ API Unavailable');
    }
  };

  // Charger les tâches
  useEffect(() => {
    fetchTasks();
  }, []);

  const fetchTasks = async () => {
    setLoading(true);
    setError('');
    try {
      const response = await axios.get(`${API_URL}/tasks`);
      setTasks(response.data);
    } catch (err) {
      setError('Failed to fetch tasks: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const addTask = async (e) => {
    e.preventDefault();
    if (!newTask.trim()) return;

    setLoading(true);
    setError('');
    try {
      const response = await axios.post(`${API_URL}/tasks`, { 
        title: newTask,
        completed: false 
      });
      setTasks([...tasks, response.data]);
      setNewTask('');
    } catch (err) {
      setError('Failed to add task: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const toggleTask = async (id, completed) => {
    try {
      const response = await axios.put(`${API_URL}/tasks/${id}`, { 
        completed: !completed 
      });
      setTasks(tasks.map(task => 
        task.id === id ? response.data : task
      ));
    } catch (err) {
      setError('Failed to update task: ' + err.message);
    }
  };

  const deleteTask = async (id) => {
    try {
      await axios.delete(`${API_URL}/tasks/${id}`);
      setTasks(tasks.filter(task => task.id !== id));
    } catch (err) {
      setError('Failed to delete task: ' + err.message);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>🚀 Three-Tier Task Manager</h1>
        <p className="api-status">API Status: {apiStatus}</p>
      </header>

      <main className="App-main">
        {error && <div className="error-message">{error}</div>}

        <form onSubmit={addTask} className="task-form">
          <input
            type="text"
            value={newTask}
            onChange={(e) => setNewTask(e.target.value)}
            placeholder="Enter a new task..."
            disabled={loading}
            className="task-input"
          />
          <button type="submit" disabled={loading} className="add-button">
            {loading ? 'Adding...' : 'Add Task'}
          </button>
        </form>

        <div className="tasks-container">
          {loading && tasks.length === 0 ? (
            <p className="loading">Loading tasks...</p>
          ) : tasks.length === 0 ? (
            <p className="no-tasks">No tasks yet. Add one above!</p>
          ) : (
            <ul className="task-list">
              {tasks.map(task => (
                <li key={task.id} className={`task-item ${task.completed ? 'completed' : ''}`}>
                  <input
                    type="checkbox"
                    checked={task.completed}
                    onChange={() => toggleTask(task.id, task.completed)}
                    className="task-checkbox"
                  />
                  <span className="task-title">{task.title}</span>
                  <button 
                    onClick={() => deleteTask(task.id)}
                    className="delete-button"
                  >
                    Delete
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        <footer className="App-footer">
          <p>Frontend: React + Nginx | Backend: Node.js API | Database: PostgreSQL StatefulSet</p>
        </footer>
      </main>
    </div>
  );
}

export default App;
