const fs = require('fs');

async function testScreens() {
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

  // Wait for Flutter Web app to initialize
  console.log('Waiting for Flutter canvas/glass pane...');
  let ready = false;
  for (let i = 0; i < 30; i++) {
    const check = await send('Runtime.evaluate', {
      expression: 'Boolean(document.querySelector("flt-glass-pane") || document.querySelector("flutter-view") || document.querySelector("canvas"))',
      returnByValue: true
    });
    if (check.result && check.result.value) {
      ready = true;
      console.log('Flutter is loaded and ready!');
      break;
    }
    await new Promise(r => setTimeout(r, 1000));
  }

  if (!ready) {
    console.log('Flutter took longer to initialize. Reloading page...');
    await send('Page.reload');
    await new Promise(r => setTimeout(r, 6000));
  }

  const testCases = [
    // Mobile Viewport (iPhone / Small Android 360x780)
    { device: 'Mobile_360x780', w: 360, h: 780, mobile: true, route: '/', label: 'home' },
    { device: 'Mobile_360x780', w: 360, h: 780, mobile: true, route: '/medicines', label: 'medicines' },
    { device: 'Mobile_360x780', w: 360, h: 780, mobile: true, route: '/alerts', label: 'alerts' },
    { device: 'Mobile_360x780', w: 360, h: 780, mobile: true, route: '/how-it-works', label: 'how_it_works' },
    { device: 'Mobile_360x780', w: 360, h: 780, mobile: true, route: '/about', label: 'about' },
    { device: 'Mobile_360x780', w: 360, h: 780, mobile: true, route: '/assets', label: 'assets' },

    // Tablet Viewport (iPad / Medium Tablet 768x1024)
    { device: 'Tablet_768x1024', w: 768, h: 1024, mobile: false, route: '/', label: 'home' },
    { device: 'Tablet_768x1024', w: 768, h: 1024, mobile: false, route: '/medicines', label: 'medicines' },
    { device: 'Tablet_768x1024', w: 768, h: 1024, mobile: false, route: '/alerts', label: 'alerts' },

    // Desktop Viewport (1440x900)
    { device: 'Desktop_1440x900', w: 1440, h: 900, mobile: false, route: '/', label: 'home' },
    { device: 'Desktop_1440x900', w: 1440, h: 900, mobile: false, route: '/medicines', label: 'medicines' },
  ];

  for (const tc of testCases) {
    console.log(`Setting device metrics: ${tc.device} (${tc.w}x${tc.h})`);
    await send('Emulation.setDeviceMetricsOverride', {
      width: tc.w,
      height: tc.h,
      deviceScaleFactor: 2.0,
      mobile: tc.mobile,
      screenOrientation: { angle: 0, type: 'portraitPrimary' }
    });

    // Navigate using history push or window.location.hash for Flutter Web GoRouter
    console.log(`Navigating to route: ${tc.route}`);
    await send('Runtime.evaluate', {
      expression: `window.location.hash = '${tc.route}'; window.dispatchEvent(new HashChangeEvent('hashchange'));`
    });

    // Wait 2 seconds for rebuild & rendering
    await new Promise(r => setTimeout(r, 2000));

    // Capture screenshot
    const shot = await send('Page.captureScreenshot', { format: 'png' });
    const filename = `verified_${tc.device}_${tc.label}.png`;
    fs.writeFileSync(`${artifactDir}\\${filename}`, Buffer.from(shot.data, 'base64'));
    console.log(`Saved screenshot: ${filename}`);
  }

  await send('Emulation.clearDeviceMetricsOverride');
  ws.close();
  console.log('Finished all verified screenshot captures!');
}

testScreens().catch(e => {
  console.error('Error:', e);
  process.exit(1);
});
