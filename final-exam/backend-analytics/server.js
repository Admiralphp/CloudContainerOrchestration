const express = require('express');
const cors = require('cors');
const { MongoClient } = require('mongodb');

const app = express();
const PORT = process.env.PORT || 4000;

// Middleware
app.use(cors());
app.use(express.json());

// Configuration MongoDB depuis variables d'environnement
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017';
const MONGO_DB_NAME = process.env.MONGO_DB_NAME || 'analytics';
const MONGO_USER = process.env.MONGO_USER;
const MONGO_PASSWORD = process.env.MONGO_PASSWORD;

let db;
let eventsCollection;
let metricsCollection;

// Connexion MongoDB avec auth
const connectDB = async () => {
  try {
    const mongoUrl = MONGO_USER && MONGO_PASSWORD
      ? `mongodb://${MONGO_USER}:${MONGO_PASSWORD}@${MONGO_URI.replace('mongodb://', '')}/${MONGO_DB_NAME}?authSource=admin`
      : `${MONGO_URI}/${MONGO_DB_NAME}`;

    const client = new MongoClient(mongoUrl, {
      serverSelectionTimeoutMS: 5000,
    });

    await client.connect();
    console.log('✓ Connected to MongoDB');

    db = client.db(MONGO_DB_NAME);
    eventsCollection = db.collection('events');
    metricsCollection = db.collection('metrics');

    // Créer index pour performance
    await eventsCollection.createIndex({ timestamp: -1 });
    await eventsCollection.createIndex({ eventType: 1 });
    await metricsCollection.createIndex({ date: -1 });

    console.log('✓ Database initialized');
  } catch (error) {
    console.error('✗ MongoDB connection error:', error);
    process.exit(1);
  }
};

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    if (db) {
      await db.admin().ping();
      res.json({
        status: 'healthy',
        database: 'connected',
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(503).json({
        status: 'unhealthy',
        database: 'disconnected'
      });
    }
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      error: error.message
    });
  }
});

// POST /analytics/events - Enregistrer un événement
app.post('/analytics/events', async (req, res) => {
  try {
    const { eventType, taskId, metadata } = req.body;

    if (!eventType) {
      return res.status(400).json({ error: 'eventType is required' });
    }

    const event = {
      eventType,
      taskId,
      timestamp: new Date(),
      metadata: metadata || {}
    };

    await eventsCollection.insertOne(event);

    // Mettre à jour les métriques en temps réel
    await updateMetrics();

    res.status(201).json({
      message: 'Event logged successfully',
      event
    });
  } catch (error) {
    console.error('Error logging event:', error);
    res.status(500).json({ error: 'Failed to log event' });
  }
});

// GET /analytics/summary - Statistiques globales
app.get('/analytics/summary', async (req, res) => {
  try {
    // Compter les événements par type
    const createdCount = await eventsCollection.countDocuments({ eventType: 'task.created' });
    const completedCount = await eventsCollection.countDocuments({ eventType: 'task.completed' });
    const deletedCount = await eventsCollection.countDocuments({ eventType: 'task.deleted' });

    // Calculer les tâches actives
    const activeTasks = createdCount - deletedCount;
    const incompleteTasks = activeTasks - completedCount;

    // Taux de complétion
    const completionRate = activeTasks > 0 
      ? ((completedCount / activeTasks) * 100).toFixed(2)
      : 0;

    res.json({
      totalTasks: activeTasks,
      completedTasks: completedCount,
      incompleteTasks: incompleteTasks > 0 ? incompleteTasks : 0,
      deletedTasks: deletedCount,
      completionRate: parseFloat(completionRate),
      lastUpdated: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error fetching summary:', error);
    res.status(500).json({ error: 'Failed to fetch summary' });
  }
});

// GET /analytics/tasks/count - Compteurs par type d'événement
app.get('/analytics/tasks/count', async (req, res) => {
  try {
    const counts = await eventsCollection.aggregate([
      {
        $group: {
          _id: '$eventType',
          count: { $sum: 1 }
        }
      }
    ]).toArray();

    const result = counts.reduce((acc, item) => {
      acc[item._id] = item.count;
      return acc;
    }, {});

    res.json(result);
  } catch (error) {
    console.error('Error fetching counts:', error);
    res.status(500).json({ error: 'Failed to fetch counts' });
  }
});

// GET /analytics/tasks/timeline - Timeline des créations (7 derniers jours)
app.get('/analytics/tasks/timeline', async (req, res) => {
  try {
    const days = parseInt(req.query.days) || 7;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const timeline = await eventsCollection.aggregate([
      {
        $match: {
          timestamp: { $gte: startDate },
          eventType: { $in: ['task.created', 'task.completed'] }
        }
      },
      {
        $group: {
          _id: {
            date: { $dateToString: { format: '%Y-%m-%d', date: '$timestamp' } },
            eventType: '$eventType'
          },
          count: { $sum: 1 }
        }
      },
      {
        $sort: { '_id.date': 1 }
      }
    ]).toArray();

    // Reformater pour une structure plus lisible
    const groupedByDate = {};
    timeline.forEach(item => {
      const date = item._id.date;
      if (!groupedByDate[date]) {
        groupedByDate[date] = { date, created: 0, completed: 0 };
      }
      if (item._id.eventType === 'task.created') {
        groupedByDate[date].created = item.count;
      } else if (item._id.eventType === 'task.completed') {
        groupedByDate[date].completed = item.count;
      }
    });

    const result = Object.values(groupedByDate);

    res.json({
      period: `${days}days`,
      data: result
    });
  } catch (error) {
    console.error('Error fetching timeline:', error);
    res.status(500).json({ error: 'Failed to fetch timeline' });
  }
});

// GET /analytics/events - Liste des derniers événements
app.get('/analytics/events', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const events = await eventsCollection
      .find()
      .sort({ timestamp: -1 })
      .limit(limit)
      .toArray();

    res.json(events);
  } catch (error) {
    console.error('Error fetching events:', error);
    res.status(500).json({ error: 'Failed to fetch events' });
  }
});

// DELETE /analytics/events - Supprimer tous les événements (admin)
app.delete('/analytics/events', async (req, res) => {
  try {
    const result = await eventsCollection.deleteMany({});
    res.json({
      message: 'All events deleted',
      deletedCount: result.deletedCount
    });
  } catch (error) {
    console.error('Error deleting events:', error);
    res.status(500).json({ error: 'Failed to delete events' });
  }
});

// Fonction pour mettre à jour les métriques
const updateMetrics = async () => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const createdCount = await eventsCollection.countDocuments({ eventType: 'task.created' });
    const completedCount = await eventsCollection.countDocuments({ eventType: 'task.completed' });
    const deletedCount = await eventsCollection.countDocuments({ eventType: 'task.deleted' });

    const activeTasks = createdCount - deletedCount;
    const incompleteTasks = activeTasks - completedCount;
    const completionRate = activeTasks > 0 ? (completedCount / activeTasks) * 100 : 0;

    await metricsCollection.updateOne(
      { date: today },
      {
        $set: {
          totalTasks: activeTasks,
          completedTasks: completedCount,
          incompleteTasks: incompleteTasks > 0 ? incompleteTasks : 0,
          deletedTasks: deletedCount,
          completionRate: parseFloat(completionRate.toFixed(2)),
          updatedAt: new Date()
        }
      },
      { upsert: true }
    );
  } catch (error) {
    console.error('Error updating metrics:', error);
  }
};

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing server...');
  process.exit(0);
});

// Start server
const startServer = async () => {
  await connectDB();
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Analytics Service running on port ${PORT}`);
    console.log(`MongoDB: ${MONGO_URI}/${MONGO_DB_NAME}`);
  });
};

startServer();
