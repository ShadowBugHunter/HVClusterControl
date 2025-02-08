const express = require('express');
const agentController = require('../controllers/agentController');

const router = express.Router();

router.post('/data', agentController.receiveAgentData);
router.post('/:agentId/command', agentController.sendCommandToAgent);

module.exports = router;