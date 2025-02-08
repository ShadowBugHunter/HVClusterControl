const VMData = require('../models/VMData');
const net = require('net');

exports.receiveAgentData = async (req, res) => {
  // TODO: Добавить аутентификацию агента (например, по API key)
  // TODO: Добавить авторизацию для проверки прав доступа

  try {
    const { agentId, vmData } = req.body;

    if (!agentId || !vmData) {
      return res.status(400).json({ message: 'agentId and vmData are required' });
    }

    // Сохранение данных о каждой ВМ
    for (const vm of vmData) {
      const newVMData = new VMData({
        agentId: agentId,
        name: vm.name,
        state: vm.state,
        cpuUsage: vm.cpuUsage,
        memoryAssigned: vm.memoryAssigned
      });
      await newVMData.save();
    }

    res.status(200).json({ message: 'Data received successfully' });

  } catch (error) {
    console.error('Error receiving agent data:', error);
    res.status(500).json({ message: 'Failed to receive data', error: error.message });
  }
};


exports.sendCommandToAgent = async (req, res) => {
  // TODO: Добавить аутентификацию пользователя
  // TODO: Добавить авторизацию для проверки прав доступа

  const { agentId } = req.params;
  const { command } = req.body;

  if (!command) {
    return res.status(400).json({ message: 'Command is required' });
  }

  try {
    // Find agent in DB (replace with your actual logic)
    // This example assumes you have an Agent model.  Adapt as needed.
    // const agent = await Agent.findById(agentId);
    // if (!agent) {
    //   return res.status(404).json({ message: 'Agent not found' });
    // }

    // For this example, we'll hardcode the agent's IP and port
    const agentIp = '127.0.0.1'; // Replace with agent.ip if you fetch from DB
    const agentControlPort = 5002;

    const client = net.createConnection({ port: agentControlPort, host: agentIp }, () => {
      console.log('Connected to agent!');
      client.write(JSON.stringify({ command: command }));
    });

    client.on('data', (data) => {
      console.log('Received: ' + data);
      client.destroy(); // kill client after server's response
    });

    client.on('close', () => {
      console.log('Connection closed');
      res.status(200).json({ message: 'Command sent successfully' });
    });

    client.on('error', (err) => {
      console.error('Error sending command:', err);
      res.status(500).json({ message: 'Failed to send command', error: err.message });
    });


  } catch (error) {
    console.error('Error sending command:', error);
    res.status(500).json({ message: 'Failed to send command', error: error.message });
  }
};