const express = require('express');
const mongoose = require('mongoose');
const agentRoutes = require('./routes/agentRoutes');

const app = express();
const port = 3000;

app.use(express.json()); // for parsing application/json

// MongoDB connection
mongoose.connect('mongodb://localhost:27017/clustercontrol', {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => console.log('Connected to MongoDB'))
.catch(err => console.error('MongoDB connection error:', err));

// Routes
app.use('/api/agents', agentRoutes);

app.listen(port, () => {
  console.log(`Server listening at http://localhost:${port}`);
});