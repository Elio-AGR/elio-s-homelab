/* homelab UI — static data, no network calls. Everything on this page is a
   snapshot of the documented state, not a live probe. */

const SNAPSHOT = "2026-10-24";

const CATS = [
  { id: "all", label: "all" },
  { id: "apps", label: "apps" },
  { id: "data", label: "data" },
  { id: "obs", label: "observability" },
  { id: "agents", label: "agents" },
  { id: "net", label: "network" },
];

const SERVICES = [
  { name: "Gitea", role: "Self-hosted git, issues and package registry.", img: "gitea/gitea", port: ":3000 · ssh :222", scope: "lan", cat: "apps" },
  { name: "Nextcloud", role: "Files, calendar and contacts for every device.", img: "nextcloud:34", port: ":8080", scope: "lan", cat: "apps" },
  { name: "MariaDB", role: "Database behind Nextcloud. Never published.", img: "mariadb:10.11", port: "internal", scope: "container", cat: "data" },
  { name: "Jellyfin", role: "Media streaming from the 431 GB library.", img: "jellyfin/jellyfin", port: ":8096", scope: "lan", cat: "apps" },
  { name: "Uptime Kuma", role: "Six HTTP probes, one minute interval, full history.", img: "louislam/uptime-kuma", port: ":3001", scope: "lan", cat: "obs" },
  { name: "Netdata", role: "Per-second host and container metrics.", img: "netdata/netdata", port: ":19999", scope: "tailnet", cat: "obs" },
  { name: "Portainer", role: "Stack management. Mounts the Docker socket.", img: "portainer/portainer-ce", port: ":9000", scope: "tailnet", cat: "obs" },
  { name: "Dashboard", role: "Static landing page for devices on the LAN.", img: "nginx:alpine", port: ":8085", scope: "lan", cat: "apps" },
  { name: "Healthcheck", role: "Tiny endpoint, deliberately separate from the dashboard.", img: "nginx:alpine", port: ":8090", scope: "lan", cat: "apps" },
  { name: "hermes-gateway", role: "Agent runtime. Tool access, loopback API, Telegram replies.", img: "systemd", port: "127.0.0.1", scope: "loopback", cat: "agents" },
  { name: "telegram-bot", role: "Allowlisted remote control: status, disk, backup, reboot.", img: "systemd", port: "outbound only", scope: "loopback", cat: "agents" },
  { name: "ai-factory", role: "Local dashboard over an agent workspace.", img: "systemd", port: "127.0.0.1:8765", scope: "loopback", cat: "agents" },
  { name: "tailscaled", role: "WireGuard mesh. The only path in from outside.", img: "systemd", port: "udp 41641", scope: "tailnet", cat: "net" },
];

const PORTS = [
  ["22", "OpenSSH", "0.0.0.0", "lan"],
  ["222", "Gitea SSH", "0.0.0.0", "lan"],
  ["3000", "Gitea", "0.0.0.0", "lan"],
  ["3001", "Uptime Kuma", "0.0.0.0", "lan"],
  ["8080", "Nextcloud", "0.0.0.0", "lan"],
  ["8085", "Dashboard", "0.0.0.0", "lan"],
  ["8090", "Healthcheck", "0.0.0.0", "lan"],
  ["8096", "Jellyfin", "0.0.0.0", "lan"],
  ["8765", "Agent dashboard", "127.0.0.1", "loopback"],
  ["9000", "Portainer", "tailscale IP", "tailnet"],
  ["19999", "Netdata", "tailscale IP", "tailnet"],
  ["49713", "Agent gateway API", "127.0.0.1", "loopback"],
];

const CRON = [
  ["every 5 min", "Container health, CPU/RAM, Tailscale reachability"],
  ["hourly", "Disk usage warning at 85%"],
  ["7× a day", "Daily report: uptime, CPU temp, RAM, disks, containers"],
  ["20:00", "Full backup to the second physical disk"],
  ["20:10", "Extra backup: photos and configs"],
  ["09:00", "banner-tracker data sync (separate systemd timer)"],
  ["on failure", "ERR trap messages the failing step to Telegram"],
];

const BACKUP_STEPS = [
  "Docker project folders — compose files, nginx roots, configs",
  "Automation scripts and systemd units",
  "crontab",
  "mysqldump of the Nextcloud database, gzipped",
  "Manifest: OS, Docker and Compose versions, file sizes",
];

const INCIDENTS = [
  {
    tag: "silent failure",
    title: "The outage the dashboard never reported",
    body: "Ten weeks of missing heartbeats looked like normal history in every query that counts rows. The monitor died with the host it was watching.",
    lesson: "Lesson",
    point: "Monitor the monitor. An alerting system that shares a power supply with its subject can only report failures that leave it alive.",
  },
  {
    tag: "bad metric",
    title: "The 75.7% uptime that was never real",
    body: "Six independent services, all failing at exactly 75.7%. The query divided good heartbeats by existing heartbeats, not by elapsed time.",
    lesson: "Lesson",
    point: "A ratio over the rows that exist is not a ratio over time. Missing data is not good data.",
  },
  {
    tag: "naming",
    title: "A Compose project named docker",
    body: "One stack used the folder name as its project name, so containers became docker-db-1 — and the monitoring script greps for exactly that string.",
    lesson: "Lesson",
    point: "Infrastructure names are an interface. Renaming one is a breaking change for every script that reads it.",
  },
];

const FINDINGS = [
  { id: "F1", title: "Bot token hardcoded in three scripts", text: "Same token and chat ID in backup, monitoring and reporting scripts. Now read from an environment file outside git; token rotated.", status: "fixed" },
  { id: "F2", title: "Weak default database password", text: "Placeholder credentials from the first build, never rotated. The port is internal, but that is not a password policy.", status: "open" },
  { id: "F3", title: "Portainer has a read-write Docker socket", text: "Needed to manage stacks. Control is reachability: tailnet only, behind device auth.", status: "accepted" },
  { id: "F4", title: "Netdata runs with SYS_PTRACE, AppArmor unconfined", text: "Required for host metrics. Same containment argument: tailnet only.", status: "accepted" },
  { id: "F5", title: "LAN services bind 0.0.0.0 with no host firewall", text: "Isolation is enforced upstream. Joining an untrusted network is the failure mode; binding to the tailnet fixes it.", status: "open" },
  { id: "F6", title: "No TLS on LAN services", text: "HTTP on the LAN, WireGuard on the tailnet. The LAN is assumed trusted — the same assumption F5 breaks.", status: "accepted" },
];

const CHECKLIST = [
  { text: "No secrets in git; .env.example only", done: true },
  { text: "Bot commands allowlisted by numeric user ID", done: true },
  { text: "Admin UIs on the tailnet, not the LAN", done: true },
  { text: "Backups on a separate physical disk", done: true },
  { text: "Rotate the database password", done: false },
  { text: "EnvironmentFile for every unit", done: false },
  { text: "Pin image digests instead of :latest", done: false },
  { text: "Enable ufw or bind LAN services to the tailnet", done: false },
  { text: "Off-site encrypted backup copy", done: false },
];

/* ---------- render ---------- */

const $ = (sel, root = document) => root.querySelector(sel);
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

function renderFilters() {
  const box = $("#filters");
  CATS.forEach((c, i) => {
    const b = document.createElement("button");
    b.className = "chip";
    b.type = "button";
    b.role = "tab";
    b.textContent = c.label;
    b.dataset.cat = c.id;
    b.setAttribute("aria-selected", i === 0 ? "true" : "false");
    b.addEventListener("click", () => {
      box.querySelectorAll(".chip").forEach((x) => x.setAttribute("aria-selected", "false"));
      b.setAttribute("aria-selected", "true");
      renderServices(c.id);
    });
    box.appendChild(b);
  });
}

function renderServices(cat = "all") {
  const grid = $("#service-grid");
  const list = cat === "all" ? SERVICES : SERVICES.filter((s) => s.cat === cat);
  grid.innerHTML = list
    .map(
      (s, i) => `
      <article class="svc reveal">
        <span class="svc-cat cat-${s.cat}"></span>
        <div class="svc-top">
          <span class="svc-name">${esc(s.name)}</span>
          <span class="svc-idx">${String(SERVICES.indexOf(s) + 1).padStart(2, "0")}</span>
        </div>
        <p class="svc-role">${esc(s.role)}</p>
        <div class="svc-meta"><span>${esc(s.img)}</span><span>${esc(s.port)}</span><span>${s.scope}</span></div>
      </article>`
    )
    .join("");
  observeReveal(grid);
}

function renderPorts() {
  $("#port-body").innerHTML = PORTS.map(
    ([p, svc, bind, scope]) => `
      <tr>
        <td>${esc(p)}</td>
        <td>${esc(svc)}</td>
        <td>${esc(bind)}</td>
        <td><span class="scope scope-${scope}">${scope}</span></td>
      </tr>`
  ).join("");
}

function renderCron() {
  $("#cron").innerHTML = CRON.map(
    ([t, what]) => `<li><span class="t">${esc(t)}</span><span>${esc(what)}</span></li>`
  ).join("");
}

function renderBackup() {
  $("#backup-steps").innerHTML = BACKUP_STEPS.map((s) => `<li>${esc(s)}</li>`).join("");
}

function renderIncidents() {
  $("#incidents-list").innerHTML = INCIDENTS.map(
    (i) => `
      <article class="incident reveal">
        <span class="tag">${esc(i.tag)}</span>
        <h3>${esc(i.title)}</h3>
        <p>${esc(i.body)}</p>
        <div class="lesson"><b>${esc(i.lesson)}</b> — ${esc(i.point)}</div>
      </article>`
  ).join("");
  observeReveal($("#incidents-list"));
}

function renderFindings() {
  $("#findings").innerHTML = FINDINGS.map(
    (f) => `
      <div class="finding reveal">
        <span class="fid">${f.id}</span>
        <div><h4>${esc(f.title)}</h4><p>${esc(f.text)}</p></div>
        <span class="badge ${f.status}">${f.status}</span>
      </div>`
  ).join("");
  observeReveal($("#findings"));
}

function renderChecklist() {
  const done = CHECKLIST.filter((c) => c.done).length;
  $("#checklist").innerHTML = CHECKLIST.map(
    (c) => `<li class="${c.done ? "done" : ""}">${esc(c.text)}</li>`
  ).join("");
  $("#progress-total").textContent = CHECKLIST.length;
  $("#progress-done").textContent = done;
  requestAnimationFrame(() => {
    $("#progress-bar").style.width = `${(done / CHECKLIST.length) * 100}%`;
  });
}

/* ---------- motion ---------- */

let io;
function observeReveal(root = document) {
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    root.querySelectorAll(".reveal").forEach((el) => el.classList.add("in"));
    return;
  }
  io = io || new IntersectionObserver(
    (entries) => entries.forEach((e) => {
      if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
    }),
    { rootMargin: "0px 0px -8% 0px", threshold: 0.08 }
  );
  root.querySelectorAll(".reveal:not(.in)").forEach((el) => io.observe(el));
}

function countUp() {
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  document.querySelectorAll("[data-count]").forEach((el) => {
    const target = Number(el.dataset.count);
    if (reduce || target === 0) { el.textContent = target; return; }
    const start = performance.now();
    const dur = 900;
    const tick = (now) => {
      const p = Math.min(1, (now - start) / dur);
      el.textContent = Math.round(target * (1 - Math.pow(1 - p, 3)));
      if (p < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });
}

function navState() {
  const nav = $("#nav");
  const onScroll = () => nav.classList.toggle("scrolled", window.scrollY > 8);
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  const links = [...document.querySelectorAll(".nav-links a")];
  const spy = new IntersectionObserver(
    (entries) => entries.forEach((e) => {
      if (!e.isIntersecting) return;
      links.forEach((a) => a.classList.toggle("active", a.getAttribute("href") === `#${e.target.id}`));
    }),
    { rootMargin: "-45% 0px -50% 0px" }
  );
  document.querySelectorAll("main section[id]").forEach((s) => spy.observe(s));
}

/* ---------- init ---------- */
renderFilters();
renderServices();
renderPorts();
renderCron();
renderBackup();
renderIncidents();
renderFindings();
renderChecklist();
countUp();
navState();
observeReveal(document);
$("#uptime").textContent = `1d 02h · snapshot ${SNAPSHOT}`;
