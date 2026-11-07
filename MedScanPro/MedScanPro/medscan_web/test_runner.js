const http = require('http');
const fs = require('fs');
const path = require('path');

async function run() {
  const targetsRes = await fetch('http://127.0.0.1:50906/json');
  const targets = await targetsRes.json();
  const pageTarget = targets.find(t => t.url && t.url.includes('localhost:50888'));
  
  if (!pageTarget) {
    console.error('Flutter page target not found');
    process.exit(1);
  }
  
  const ws = new WebSocket(pageTarget.webSocketDebuggerUrl);
  let id = 1;
  const pending = new Map();

  function send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const msgId = id++;
      pending.set(msgId, { resolve, reject });
      ws.send(JSON.stringify({ id: msgId, method, params }));
    });
  }

  ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    if (data.id && pending.has(data.id)) {
      const { resolve, reject } = pending.get(data.id);
      pending.delete(data.id);
      if (data.error) reject(data.error);
      else resolve(data.result);
    }
  };

  await new Promise((resolve) => { ws.onopen = resolve; });
  await send('Page.enable');
  await send('Runtime.enable');

  const artifactDir = 'C:\\Users\\Nouman\\.gemini\\antigravity-ide\\brain\\d948dcdf-6347-4453-bf17-4900b1e1b327\\.tempmediaStorage';
  if (!fs.existsSync(artifactDir)) {
    fs.mkdirSync(artifactDir, { recursive: true });
  }

  const routes = [
    { url: 'http://localhost:50888/', label: 'home' },
    { url: 'http://localhost:50888/medicines', label: 'medicines' },
    { url: 'http://localhost:50888/alerts', label: 'alerts' },
    { url: 'http://localhost:50888/how-it-works', label: 'how_it_works' },
    { url: 'http://localhost:50888/about', label: 'about' },
  ];

  const devices = [
    { name: 'Mobile_360x780', width: 360, height: 780, mobile: true, dsf: 2.0 },
    { name: 'Tablet_768x1024', width: 768, height: 1024, mobile: false, dsf: 2.0 },
    { name: 'Desktop_1440x900', width: 1440, height: 900, mobile: false, dsf: 1.0 },
  ];

  for (const device of devices) {
    console.log(`\n=== Testing Device Profile: ${device.name} ===`);
    await send('Emulation.setDeviceMetricsOverride', {
      width: device.width,
      height: device.height,
      deviceScaleFactor: device.dsf,
      mobile: device.mobile,
      screenOrientation: { angle: 0, type: 'portraitPrimary' }
    });

    for (const route of routes) {
      console.log(`Navigating to ${route.url}...`);
      await send('Page.navigate', { url: route.url });
      await new Promise(r => setTimeout(r, 2200));

      const shot = await send('Page.captureScreenshot', { format: 'png' });
      const filename = `shot_${device.name}_${route.label}.png`;
      const filePath = path.join(artifactDir, filename);
      fs.writeFileSync(filePath, Buffer.from(shot.data, 'base64'));
      console.log(`Captured: ${filename}`);
    }
  }

  await send('Emulation.clearDeviceMetricsOverride');
  ws.close();
  console.log('\nAll direct screenshots captured!');
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
