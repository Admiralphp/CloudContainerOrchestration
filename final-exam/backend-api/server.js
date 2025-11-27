const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 5000;

// Analytics Service URL
const ANALYTICS_SERVICE_URL = process.env.ANALYTICS_SERVICE_URL || 'http://localhost:4000';

// Middleware
app.use(cors());
app.use(express.json());

// Configuration PostgreSQL depuis variables d'environnement (ConfigMap + Secret)
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'taskdb',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'password',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Initialiser la base de données
const initDB = async () => {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS tasks (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        completed BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✓ Database initialized successfully');
  } catch (error) {
    console.error('✗ Database initialization error:', error);
    process.exit(1);
  }
};

// Health check endpoint
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ 
      status: 'healthy', 
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(503).json({ 
      status: 'unhealthy', 
      database: 'disconnected',
      error: error.message 
    });
  }
});

// GET all tasks
app.get('/api/tasks', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM tasks ORDER BY created_at DESC');
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching tasks:', error);
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

// GET single task
app.get('/api/tasks/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM tasks WHERE id = $1', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching task:', error);
    res.status(500).json({ error: 'Failed to fetch task' });
  }
});

// POST new task
app.post('/api/tasks', async (req, res) => {
  try {
    const { title, completed = false } = req.body;
    if (!title) {
      return res.status(400).json({ error: 'Title is required' });
    }
    const result = await pool.query(
      'INSERT INTO tasks (title, completed) VALUES ($1, $2) RETURNING *',
      [title, completed]
    );
    
    const task = result.rows[0];
    
    // Envoyer événement vers Analytics Service
    try {
      await axios.post(`${ANALYTICS_SERVICE_URL}/analytics/events`, {
        eventType: 'task.created',
        taskId: task.id,
        metadata: { title: task.title }
      });
    } catch (analyticsError) {
      console.error('Analytics service error:', analyticsError.message);
      // Ne pas bloquer la réponse si Analytics échoue
    }
    
    res.status(201).json(task);
  } catch (error) {
    console.error('Error creating task:', error);
    res.status(500).json({ error: 'Failed to create task' });
  }
});

// PUT update task
app.put('/api/tasks/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { title, completed } = req.body;
    
    // Récupérer l'état précédent
    const oldTask = await pool.query('SELECT * FROM tasks WHERE id = $1', [id]);
    const wasCompleted = oldTask.rows.length > 0 ? oldTask.rows[0].completed : false;
    
    let query = 'UPDATE tasks SET ';
    let params = [];
    let paramCount = 1;
    
    if (title !== undefined) {
      query += `title = $${paramCount}, `;
      params.push(title);
      paramCount++;
    }
    if (completed !== undefined) {
      query += `completed = $${paramCount}, `;
      params.push(completed);
      paramCount++;
    }
    
    query = query.slice(0, -2); // Remove last comma
    query += ` WHERE id = $${paramCount} RETURNING *`;
    params.push(id);
    
    const result = await pool.query(query, params);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }
    
    const task = result.rows[0];
    
    // Envoyer événement vers Analytics Service
    try {
      // Si la tâche passe à completed=true
      if (!wasCompleted && task.completed) {
        await axios.post(`${ANALYTICS_SERVICE_URL}/analytics/events`, {
          eventType: 'task.completed',
          taskId: task.id,
          metadata: { title: task.title }
        });
      }
      // Événement générique de mise à jour
      await axios.post(`${ANALYTICS_SERVICE_URL}/analytics/events`, {
        eventType: 'task.updated',
        taskId: task.id,
        metadata: { title: task.title, completed: task.completed }
      });
    } catch (analyticsError) {
      console.error('Analytics service error:', analyticsError.message);
    }
    
    res.json(task);
  } catch (error) {
    console.error('Error updating task:', error);
    res.status(500).json({ error: 'Failed to update task' });
  }
});

// DELETE task
app.delete('/api/tasks/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('DELETE FROM tasks WHERE id = $1 RETURNING *', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }
    
    const task = result.rows[0];
    
    // Envoyer événement vers Analytics Service
    try {
      await axios.post(`${ANALYTICS_SERVICE_URL}/analytics/events`, {
        eventType: 'task.deleted',
        taskId: task.id,
        metadata: { title: task.title }
      });
    } catch (analyticsError) {
      console.error('Analytics service error:', analyticsError.message);
    }
    
    res.json({ message: 'Task deleted successfully' });
  } catch (error) {
    console.error('Error deleting task:', error);
    res.status(500).json({ error: 'Failed to delete task' });
  }
});

// Proxy endpoints vers Analytics Service
app.get('/api/analytics/*', async (req, res) => {
  try {
    const analyticsPath = req.path.replace('/api', '');
    const response = await axios.get(`${ANALYTICS_SERVICE_URL}${analyticsPath}`, {
      params: req.query
    });
    res.json(response.data);
  } catch (error) {
    console.error('Analytics proxy error:', error.message);
    res.status(error.response?.status || 500).json({
      error: 'Failed to fetch analytics',
      message: error.message
    });
  }
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing server...');
  await pool.end();
  process.exit(0);
});

// Start server
const startServer = async () => {
  await initDB();
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Backend API running on port ${PORT}`);
    console.log(`Database: ${process.env.DB_HOST || 'localhost'}:${process.env.DB_PORT || 5432}`);
    console.log(`Analytics Service: ${ANALYTICS_SERVICE_URL}`);
  });
};

startServer();
