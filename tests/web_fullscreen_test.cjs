// Run with Playwright available via NODE_PATH (or an installed dev dependency).
// The game engine is stubbed; browser fullscreen and iframe policies are real.
const { chromium, webkit } = require('playwright');
const fs = require('fs');
const assert = require('assert/strict');
const shell = fs.readFileSync('web/mobile_shell.html', 'utf8')
  .replace(/<script src="\$GODOT_URL"><\/script>/, `<script>
    class Engine { static getMissingFeatures() { return []; }
      startGame() { return Promise.resolve(); } }
    </script>`)
  .replace('<link rel="stylesheet" href="game_shell.css">', () => '<style>' + fs.readFileSync('web/game_shell.css', 'utf8') + '</style>')
  .replace('<script src="game_shell.js"></script>', () => '<script>' + fs.readFileSync('web/game_shell.js', 'utf8') + '</script>')
  .replace('<script src="build_info.js"></script>', '<script>window.HOOSHANG_BUILD = "test";</script>')
  .replace('<script src="touch_diagnostics.js"></script>', () => '<script>' + fs.readFileSync('web/touch_diagnostics.js', 'utf8') + '</script>')
  .replace('$GODOT_CONFIG', '{}').replace('$GODOT_THREADS_ENABLED', 'false')
  .replace(/\$GODOT_[A-Z_]+/g, '');
(async () => {
 for (const kind of [chromium, webkit]) {
  const browser = await kind.launch(kind === chromium ? {
    executablePath: process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true
  } : {headless:true});
  const context = await browser.newContext({viewport:{width:844,height:390},hasTouch:true});
  await context.route('http://localhost:9988/**', route => route.fulfill({contentType:'text/html',body:shell}));
  const page = await context.newPage();
  const errors=[]; page.on('pageerror',e=>errors.push({message:e.message,stack:e.stack}));
  await page.goto('http://localhost:9988/game');
  assert.equal(await page.evaluate(()=>!!document.fullscreenElement),false);
  if (await page.evaluate(()=>document.fullscreenEnabled)) {
   await page.locator('#screen-toggle').tap();
   await page.waitForFunction(()=>!!document.fullscreenElement);
   assert.equal(await page.evaluate(()=>document.fullscreenElement.tagName),'HTML');
   await page.locator('#screen-toggle').tap();
   await page.waitForFunction(()=>!document.fullscreenElement);
  }
  // iPhone-style unsupported API: visible fallback, no exception or dead tap.
  await page.evaluate(()=>{
   Object.defineProperty(document,'fullscreenEnabled',{value:false,configurable:true});
   Object.defineProperty(document,'webkitFullscreenEnabled',{value:false,configurable:true});
  });
  await page.locator('#screen-toggle').tap();
  assert(await page.locator('#screen-help').isVisible());
  assert.match(await page.locator('#screen-help-message').textContent(),/Native fullscreen is unavailable/);
  assert.equal(await page.locator('#open-game').isVisible(),false);
  await page.locator('#close-screen-help').tap();
  // Permission rejection is handled rather than becoming an unhandled promise.
  await page.evaluate(()=>{
   Object.defineProperty(document,'fullscreenEnabled',{value:true,configurable:true});
   document.documentElement.requestFullscreen=()=>Promise.reject(new Error('Denied'));
  });
  await page.locator('#screen-toggle').tap();
  await page.waitForFunction(()=>!document.getElementById('screen-help').hidden);
  await page.locator('#close-screen-help').tap();
  await page.setViewportSize({width:390,height:844});
  assert(await page.locator('#rotate-phone').isVisible());
  await page.waitForFunction(()=>document.getElementById('canvas').getBoundingClientRect().width===390);
  const size=await page.locator('#canvas').boundingBox();
  assert.equal(size.width,390);assert.equal(size.height,844);
  assert.deepEqual(errors,[]);
  // Cross-origin host cannot grant fullscreen: show an explicit standalone link.
  await context.route('http://127.0.0.1:9988/host', route=>route.fulfill({contentType:'text/html',body:'<iframe src="http://localhost:9988/game" width="600" height="360"></iframe>'}));
  await page.goto('http://127.0.0.1:9988/host');
  const frame=page.frameLocator('iframe');
  await frame.locator('#screen-toggle').tap();
  assert(await frame.locator('#screen-help').isVisible());
  assert(await frame.locator('#open-game').isVisible());
  assert.equal(await frame.locator('#open-game').getAttribute('href'),'http://localhost:9988/game?install=1');
  // WebKit reports the intentionally denied iframe policy as a page error,
  // even when the fullscreen capability query returns false as expected.
  assert(errors.every(e=>kind===webkit && e.stack.startsWith("Permission policy 'Fullscreen' check failed")));
  console.log(`${kind.name()}: fullscreen, exit, unsupported, rejection, resize, iframe fallback PASS`);
  const iphone = await browser.newContext({viewport:{width:844,height:390},hasTouch:true,
    userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 Version/26.0 Mobile/15E148 Safari/604.1'});
  await iphone.addInitScript(()=>{
    Object.defineProperty(document,'fullscreenEnabled',{value:false});
    Object.defineProperty(document,'webkitFullscreenEnabled',{value:false});
    Object.defineProperty(navigator,'standalone',{value:location.search.includes('standaloneTest')});
  });
  await iphone.route('http://localhost:9988/**', route=>route.fulfill({contentType:'text/html',body:shell}));
  const phone = await iphone.newPage();
  await phone.goto('http://localhost:9988/index.html');
  assert.equal(await phone.locator('#screen-toggle').textContent(),'Install to play fullscreen');
  await phone.locator('#screen-toggle').tap();
  assert(await phone.locator('#install-steps').isVisible());
  assert.match(await phone.locator('#install-steps').textContent(),/Add to Home Screen/);
  assert.equal(await phone.locator('meta[name="apple-mobile-web-app-capable"]').getAttribute('content'),'yes');
  assert.equal(await phone.locator('link[rel="manifest"]').getAttribute('href'),'manifest.webmanifest');
  await phone.goto('http://localhost:9988/index.html?install=1');
  assert(await phone.locator('#install-steps').isVisible());
  // Home Screen launch must not show an install prompt or redundant button.
  await phone.goto('http://localhost:9988/index.html?install=1&standaloneTest=1');
  assert.equal(await phone.locator('#screen-toggle').isVisible(),false);
  assert.equal(await phone.locator('#screen-help').isVisible(),false);
  console.log(`${kind.name()}: iPhone install instructions and standalone launch PASS`);
  await browser.close();
 }
})().catch(e=>{console.error(e);process.exit(1);});
