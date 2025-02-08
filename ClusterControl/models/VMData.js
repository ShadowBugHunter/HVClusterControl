const mongoose = require('mongoose');

const VMDataSchema = new mongoose.Schema({
  agentId: { type: String, required: true },
  name: { type: String, required: true },
  state: String,
  cpuUsage: Number,
  memoryAssigned: Number,
  timestamp: { type: Date, default: Date.now }
});

module.exports = mongoose.model('VMData', VMDataSchema);