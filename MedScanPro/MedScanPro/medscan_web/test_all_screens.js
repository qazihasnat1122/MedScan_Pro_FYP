const fs = require('fs');

async function testAllScreens() {
  const res = await fetch('http://127.0.0.1:50906/json');
  const targets = await res.json();
  const page = targets.find(t => t.url && t.url.includes('localhost:50888'));
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise(r => ws.onopen = r);
  
  function send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = Math.floor(Math.random() * 10000000);
      const onMsg = (event) => {
        const d = JSON.parse(event.data);
        if (d.id === id) {
          ws.removeEventListener('message', onMsg);
          if (d.error) reject(d.error);
          else resolve(d.result);
        }
      };
      ws.addEventListener('message', onMsg);
      ws.send(JSON.stringify({ id, method, params }));
    });
  }

  await send('Page.enable');
  await send('Runtime.enable');

  const artifactDir = 'C:\\Users\\Nouman\\.gemini\\antigravity-ide\\brain\\d948dcdf-6347-4453-bf17-4900b1e1b327\\.tempmediaStorage';

  const screens = [
    { route: '/', name: 'home' },
    { route: '/medicines', name: 'medicines' },
    { route: '/alerts', name: 'alerts' },
    { route: '/how-it-works', name: 'how_it_works' },
    { route: '/about', name: 'about' },
  ];

  // Test Mobile (360x780) and Desktop (1440x900)
  for (const s of screens) {
    console.log(`Setting Mobile 360x780 for ${s.name}...`);
    await send('Emulation.setDeviceMetricsOverride', {
      width: 360,
      height: 780,
      deviceScaleFactor: 2.0,
      mobile: true,
      screenOrientation: { angle: 0, type: 'portraitPrimary' }
    });

    // GoRouter in Flutter web listens to window.location.hash or browser history:
    // Let's use history.pushState + popstate or window.location.assign:
    await send('Runtime.evaluate', {
      expression: `window.location.hash = '${s.route}';`
    });
    // Trigger popstate so GoRouter immediately navigates
    await send('Runtime.evaluate', {
      expression: `window.dispatchEvent(new Event('popstate'));`
    });

    await new Promise(r => setTimeout(r, 2000));
    
    // Take screenshot of mobile
    const mShot = await send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(`${artifactDir}\\live_mobile_${s.name}.png`, Buffer.from(mShot.data, 'base64'));
    console.log(`Saved live_mobile_${s.name}.png`);
  }

  await send('Emulation.clearDeviceMetricsOverride');
  ws.close();
  console.log('Done capturing live screen suite!');
}

testAllScreens().catch(e => {
  console.error(e);
  process.exit(1);
});
