// Resize within the browser's safe area, including iPhone notches/home indicator.
// No Fullscreen API dependency: this also works inside itch.io's mobile iframe.
const canvas = document.getElementById('canvas');
function fitCanvas() {
  const safe = getComputedStyle(document.getElementById('safe-area'));
  const left = parseFloat(safe.paddingLeft) || 0, right = parseFloat(safe.paddingRight) || 0;
  const top = parseFloat(safe.paddingTop) || 0, bottom = parseFloat(safe.paddingBottom) || 0;
  const viewport = window.visualViewport;
  const width = Math.max(1, (viewport ? viewport.width : window.innerWidth) - left - right);
  const height = Math.max(1, (viewport ? viewport.height : window.innerHeight) - top - bottom);
  canvas.style.left = ((viewport ? viewport.offsetLeft : 0) + left) + 'px';
  canvas.style.top = ((viewport ? viewport.offsetTop : 0) + top) + 'px';
  canvas.style.width = width + 'px'; canvas.style.height = height + 'px';
  const ratio = window.devicePixelRatio || 1;
  const pixelsWide = Math.round(width * ratio), pixelsHigh = Math.round(height * ratio);
  if (canvas.width !== pixelsWide) canvas.width = pixelsWide;
  if (canvas.height !== pixelsHigh) canvas.height = pixelsHigh;
}
fitCanvas();
window.addEventListener('resize', fitCanvas);
if (window.visualViewport) {
  window.visualViewport.addEventListener('resize', fitCanvas);
  window.visualViewport.addEventListener('scroll', fitCanvas);
}
// Request synchronously from this real DOM click: a deferred engine callback
// loses user activation on mobile. Fullscreen the root, keeping touch UI visible.
const screenToggle = document.getElementById('screen-toggle');
const screenHelp = document.getElementById('screen-help');
const openGame = document.getElementById('open-game');
const installURL = new URL(window.location.href);
installURL.searchParams.set('install', '1');
openGame.href = installURL.href;
const isAppleMobile = /iPhone|iPad|iPod/.test(navigator.userAgent) ||
  (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
function isStandalone() {
  return navigator.standalone === true || window.matchMedia('(display-mode: standalone)').matches ||
    window.matchMedia('(display-mode: fullscreen)').matches;
}
const root = document.documentElement;
function fullscreenElement() { return document.fullscreenElement || document.webkitFullscreenElement; }
function canFullscreen() {
  return Boolean((root.requestFullscreen && document.fullscreenEnabled) ||
    (root.webkitRequestFullscreen && document.webkitFullscreenEnabled));
}
function updateFullscreen() {
  const install = isAppleMobile && !canFullscreen();
  const label = fullscreenElement() ? 'Exit fullscreen' : install ? 'Add to Home Screen' : canFullscreen() ? 'Enter fullscreen' : 'Screen options';
  screenToggle.hidden = isStandalone() && !fullscreenElement();
  screenToggle.classList.toggle('install', install);
  screenToggle.textContent = install ? 'Install to play fullscreen' : '⛶';
  screenToggle.setAttribute('aria-label', label);
  screenToggle.title = label;
  screenToggle.setAttribute('aria-pressed', String(Boolean(fullscreenElement())));
  fitCanvas();
}
function showScreenHelp() {
  // Pause existing gameplay through the same handler as backgrounding.
  window.dispatchEvent(new Event('blur'));
  const embedded = window.self !== window.top;
  const apple = isAppleMobile;
  document.getElementById('screen-help-title').textContent = apple ? 'Play without Safari’s bars' : 'Screen options';
  document.getElementById('screen-help-message').textContent = apple
    ? (embedded ? 'First open the game’s install page. Then add that page to your Home Screen, not the itch.io listing.'
      : 'Safari cannot hide its tabs with a game button. Launch Hooshang from your Home Screen to play without the address bar and tabs.')
    : (embedded ? 'Fullscreen is blocked in this embed. Open the game in its own tab, then try fullscreen again.'
      : 'Native fullscreen is unavailable in this browser. The game fits the available window.');
  document.getElementById('install-steps').hidden = !apple || embedded;
  openGame.textContent = apple ? 'Open install page' : 'Open game in a new tab';
  openGame.hidden = !embedded;
  openGame.style.display = embedded ? 'inline-block' : 'none';
  document.getElementById('open-game-note').hidden = !embedded && !apple;
  screenHelp.hidden = false;
  document.getElementById('close-screen-help').focus();
}
function closeScreenHelp() { screenHelp.hidden = true; screenToggle.focus(); }
screenToggle.addEventListener('click', () => {
  try {
    let result;
    if (fullscreenElement()) {
      result = (document.exitFullscreen || document.webkitExitFullscreen).call(document);
    } else if (canFullscreen()) {
      result = (root.requestFullscreen || root.webkitRequestFullscreen).call(root);
    } else { showScreenHelp(); return; }
    if (result && result.catch) result.catch(showScreenHelp);
  } catch (_) { showScreenHelp(); }
});
document.getElementById('close-screen-help').addEventListener('click', closeScreenHelp);
screenHelp.addEventListener('keydown', event => {
  if (event.key === 'Escape') { event.preventDefault(); closeScreenHelp(); }
});
document.addEventListener('fullscreenchange', updateFullscreen);
document.addEventListener('webkitfullscreenchange', updateFullscreen);
document.addEventListener('fullscreenerror', showScreenHelp);
document.addEventListener('webkitfullscreenerror', showScreenHelp);
updateFullscreen();
if (window.self === window.top && isAppleMobile && !isStandalone() &&
    new URL(window.location.href).searchParams.get('install') === '1') showScreenHelp();
canvas.addEventListener('contextmenu', event => event.preventDefault());
canvas.addEventListener('touchmove', event => event.preventDefault(), { passive: false });
document.addEventListener('gesturestart', event => event.preventDefault(), { passive: false });

const engine = new Engine(GODOT_CONFIG);

(function () {
	const statusOverlay = document.getElementById('status');
	const statusProgress = document.getElementById('status-progress');
	const statusNotice = document.getElementById('status-notice');
	const loadingDetail = document.getElementById('loading-detail');

	let initializing = true;
	let statusMode = '';

	function setStatusMode(mode) {
		if (statusMode === mode || !initializing) {
			return;
		}
		if (mode === 'hidden') {
			statusOverlay.remove();
			initializing = false;
			return;
		}
		statusOverlay.style.visibility = 'visible';
		statusProgress.style.display = mode === 'progress' ? 'block' : 'none';
		loadingDetail.style.display = mode === 'progress' ? 'block' : 'none';
		statusNotice.style.display = mode === 'notice' ? 'block' : 'none';
		statusMode = mode;
	}

	function setStatusNotice(text) {
		while (statusNotice.lastChild) {
			statusNotice.removeChild(statusNotice.lastChild);
		}
		const lines = text.split('\n');
		lines.forEach((line) => {
			statusNotice.appendChild(document.createTextNode(line));
			statusNotice.appendChild(document.createElement('br'));
		});
	}

	function displayFailureNotice(err) {
		console.error(err);
		if (err instanceof Error) {
			setStatusNotice(err.message);
		} else if (typeof err === 'string') {
			setStatusNotice(err);
		} else {
			setStatusNotice('An unknown error occurred.');
		}
		setStatusMode('notice');
		initializing = false;
	}

	const missing = Engine.getMissingFeatures({
		threads: GODOT_THREADS_ENABLED,
	});

	if (missing.length !== 0) {
		if (GODOT_CONFIG['serviceWorker'] && GODOT_CONFIG['ensureCrossOriginIsolationHeaders'] && 'serviceWorker' in navigator) {
			let serviceWorkerRegistrationPromise;
			try {
				serviceWorkerRegistrationPromise = navigator.serviceWorker.getRegistration();
			} catch (err) {
				serviceWorkerRegistrationPromise = Promise.reject(new Error('Service worker registration failed.'));
			}
			// There's a chance that installing the service worker would fix the issue
			Promise.race([
				serviceWorkerRegistrationPromise.then((registration) => {
					if (registration != null) {
						return Promise.reject(new Error('Service worker already exists.'));
					}
					return registration;
				}).then(() => engine.installServiceWorker()),
				// For some reason, `getRegistration()` can stall
				new Promise((resolve) => {
					setTimeout(() => resolve(), 2000);
				}),
			]).then(() => {
				// Reload if there was no error.
				window.location.reload();
			}).catch((err) => {
				console.error('Error while registering service worker:', err);
			});
		} else {
			// Display the message as usual
			const missingMsg = 'Error\nThe following features required to run Godot projects on the Web are missing:\n';
			displayFailureNotice(missingMsg + missing.join('\n'));
		}
	} else {
		setStatusMode('progress');
		engine.startGame({
			'onProgress': function (current, total) {
				if (current > 0 && total > 0) {
					statusProgress.value = current;
					statusProgress.max = total;
                    loadingDetail.textContent = current >= total ? 'Download complete. Starting game…' :
                      `Downloading game: ${Math.floor(current / total * 100)}% — ${Math.round(current / 1048576)} / ${Math.round(total / 1048576)} MB`;

				} else {
					statusProgress.removeAttribute('value');
					statusProgress.removeAttribute('max');
				}
			},
		}).then(() => {
			setStatusMode('hidden');
		}, displayFailureNotice);
	}
}());
