// Run against tools/build_mobile_web.py output served over HTTP.
// Browser WebKit is a simulation; the copied report covers the physical iPhone.
const {chromium, webkit} = require('playwright');
const assert = require('node:assert/strict');
const base = process.env.HOOSHANG_TEST_URL || 'http://127.0.0.1:8765/';
(async () => {
  for (const [name, type] of [['chromium', chromium], ['webkit', webkit]]) {
    const options = {headless:true};
    if (name === 'chromium' && process.env.CHROME_PATH) options.executablePath = process.env.CHROME_PATH;
    if (name === 'chromium') options.args = ['--use-angle=swiftshader','--enable-unsafe-swiftshader'];
    const browser = await type.launch(options);
    try {
      const context = await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true});
      await context.addInitScript(() => Object.defineProperty(navigator,'standalone',{value:true}));
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('console', m => { if (m.text().includes('SCRIPT ERROR')) errors.push(m.text()); });
      const url = new URL(base); url.searchParams.set('touch_test','1');
      await page.goto(url.href);
      await page.waitForFunction(() => window.HooshangTouchTest && JSON.parse(HooshangTouchTest.report()).latest?.available, null, {timeout:90000});
      if (process.env.HOOSHANG_TEST_SCREENSHOT) await page.screenshot({path:process.env.HOOSHANG_TEST_SCREENSHOT + '-' + name + '.png'});
      const manifest = await page.locator('link[rel="manifest"]').getAttribute('href');
      const manifestData = await (await context.request.get(new URL(manifest, url).href)).json();
      assert.equal(new URL(manifestData.start_url, url).searchParams.get('touch_test'),'1');
      assert.match(await page.locator('#touch-environment').textContent(), /HOME SCREEN.*Build \d/);
      const cdp = name === 'chromium' ? await context.newCDPSession(page) : null;
      const fingers = new Map();
      async function touch(type, id, x, y) {
        const point = {id,x,y};
        if (type === 'touchEnd') fingers.delete(id); else fingers.set(id,point);
        if (cdp) await cdp.send('Input.dispatchTouchEvent',{type,touchPoints:[...fingers.values()]});
        else await page.evaluate(({type,point,active}) => {
          const canvas = document.getElementById('canvas');
          const make = p => ({identifier:p.id,target:canvas,clientX:p.x,clientY:p.y,pageX:p.x,pageY:p.y});
          const event = new Event(type.toLowerCase(),{bubbles:true,cancelable:true});
          Object.defineProperties(event,{changedTouches:{value:[make(point)]},touches:{value:active.map(make)},targetTouches:{value:active.map(make)}});
          canvas.dispatchEvent(event);
        }, {type,point,active:[...fingers.values()]});
      }
      async function passed(check) {
        try {
          await page.waitForFunction(key => JSON.parse(HooshangTouchTest.report()).checks[key], check, {timeout:5000});
        } catch (error) {
          console.error(name, check, await page.evaluate(() => HooshangTouchTest.report()));
          throw error;
        }
      }
      await touch('touchStart',1,182,289);
      await page.waitForTimeout(650); // held thumb must survive beyond the mouse grace period
      await touch('touchMove',1,182,247);
      await passed('Climb');
      await touch('touchEnd',1,182,247);
      await touch('touchStart',2,600,280);
      await touch('touchEnd',2,600,280);
      await passed('Jump');
      await touch('touchStart',2,600,280);
      await touch('touchMove',2,645,235);
      await passed('Dash');
      await touch('touchEnd',2,645,235);
      await page.waitForTimeout(1000);
      // Press the visible left arrow without any drag; WebKit also exercises
      // a valid negative browser ID that must not mean "no finger".
      const movementId = name === 'webkit' ? -1 : 7;
      await touch('touchStart',movementId,151,289);
      await passed('Walk');
      await touch('touchEnd',movementId,151,289);
      await page.waitForTimeout(150);
      const report = await page.evaluate(() => JSON.parse(HooshangTouchTest.report()));
      assert(report.raw.touchmove > 0 && report.latest.events.drag > 0);
      assert.equal(report.latest.fingers[0], -1);
      await page.locator('#touch-report-details summary').click();
      assert.match(await page.locator('#touch-report').inputValue(), /touch-test-v1/);
      assert.deepEqual(errors, []);
      // Loading the manifest's actual launch URL must return to the test room.
      await page.goto(new URL(manifestData.start_url,url).href);
      await page.waitForFunction(() => window.HooshangTouchTest && JSON.parse(HooshangTouchTest.report()).latest?.available, null, {timeout:90000});
      console.log(`${name}: Home Screen launch, real player walk/climb/jump/dash, report PASS`);
    } finally { await browser.close(); }
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
