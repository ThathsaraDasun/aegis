'use strict';
// The fragment is never sent to Hosting, analytics, or map-tile providers.
const token = location.hash.slice(1);
const project = 'aegis-45002';
const $ = id => document.getElementById(id);
let map, marker, circle, position, expires = 0, fixAt = 0, updatedAt = 0;
let stopped = false, fetching = false, lastAttempt = 0, timer;
function status(title, detail) { $('status').textContent = title; $('detail').textContent = detail; }
function clearMap() {
  if (map) { map.remove(); map = null; }
  marker = circle = position = null;
  $('map').hidden = $('center').hidden = $('directions').hidden = true;
  $('coordinates').textContent = $('age').textContent = '';
  $('directions').removeAttribute('href');
}
function stop(title, detail) {
  stopped = true; clearTimeout(timer); clearMap();
  $('retry').hidden = true; status(title, detail);
}
function updateAge() {
  if (stopped) return;
  if (expires && Date.now() >= expires) { stop('This link has expired', 'Ask the sender for a new SOS link if needed.'); return; }
  if (!fixAt) return;
  const seconds = Math.max(0, Math.floor((Date.now() - fixAt) / 1000));
  const stale = seconds > 45 || Date.now() - updatedAt > 45000;
  $('age').textContent = `${stale ? 'Location may be out of date. ' : ''}GPS position: ${seconds < 60 ? seconds + ' seconds' : Math.floor(seconds / 60) + ' minutes'} ago. Expires at ${new Date(expires).toLocaleTimeString()}.`;
}
function number(field) { return field && ('doubleValue' in field || 'integerValue' in field) ? Number(field.doubleValue ?? field.integerValue) : NaN; }
async function refresh() {
  if (stopped || fetching || document.hidden) return;
  // Prevent rapid refresh clicks from creating unbounded database reads.
  if (Date.now() - lastAttempt < 10000) return;
  lastAttempt = Date.now(); fetching = true; $('retry').disabled = true;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/live_shares/${token}`, {
      signal: controller.signal, cache: 'no-store', credentials: 'omit', referrerPolicy: 'no-referrer'
    });
    if ([401, 403, 404].includes(response.status)) {
      stop('Location sharing is unavailable', 'The link may have stopped, expired, or be invalid. Contact the sender directly.'); return;
    }
    if (!response.ok) throw new Error('unavailable');
    const fields = (await response.json()).fields;
    expires = Date.parse(fields.expiresAt?.timestampValue);
    if (fields.active?.booleanValue !== true || !Number.isFinite(expires) || expires <= Date.now()) {
      stop('Location sharing has ended', 'This page will no longer display the sender’s location.'); return;
    }
    fixAt = Date.parse(fields.fixAt?.timestampValue) || 0;
    updatedAt = Date.parse(fields.updatedAt?.timestampValue) || 0;
    const lat = number(fields.lat), lng = number(fields.lng), accuracy = number(fields.accuracy);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180 || !fixAt) {
      clearMap(); status('Waiting for the sender’s GPS', 'The link is active, but no usable position has arrived.'); return;
    }
    position = [lat, lng];
    $('coordinates').textContent = `Latitude ${lat.toFixed(6)}, longitude ${lng.toFixed(6)}${Number.isFinite(accuracy) ? ' · Accuracy about ' + Math.round(accuracy) + ' m' : ''}`;
    $('directions').href = `https://www.openstreetmap.org/?mlat=${lat}&mlon=${lng}#map=17/${lat}/${lng}`;
    $('directions').hidden = false;
    if (typeof L !== 'undefined') {
      $('map').hidden = $('center').hidden = false;
      if (!map) {
        map = L.map('map').setView(position, 16);
        L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
          maxZoom: 19, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        }).addTo(map);
        marker = L.marker(position).addTo(map);
        circle = L.circle(position, {radius: Math.max(0, accuracy || 0)}).addTo(map);
      } else {
        marker.setLatLng(position); circle.setLatLng(position).setRadius(Math.max(0, accuracy || 0));
      }
    }
    status('Latest shared position', 'Updates roughly every 15 seconds when the sender has GPS and internet. Check the age below.');
    updateAge();
  } catch (_) {
    status('Cannot fetch a new location', 'Check your connection. Any position still shown is the last received position, not a confirmed current location.');
    updateAge();
  } finally {
    clearTimeout(timeout); fetching = false; $('retry').disabled = false;
    clearTimeout(timer);
    if (!stopped) timer = setTimeout(refresh, 15000);
  }
}
$('retry').addEventListener('click', refresh);
$('center').addEventListener('click', () => { if (map && position) map.setView(position, 16); });
document.addEventListener('visibilitychange', () => { if (!document.hidden) { updateAge(); refresh(); } });
window.addEventListener('hashchange', () => location.reload());
setInterval(updateAge, 1000);
if (!/^[a-f0-9]{64}$/.test(token)) stop('Open the full SOS link', 'Use the private link sent by the person requesting help.');
else refresh();
