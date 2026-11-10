/* Phone Use site: download events for Plausible, and the bridge mailing-list form (Kit). */
(function () {
  "use strict";
  var track = function (name, props) { try { window.plausible && window.plausible(name, { props: props }); } catch (e) {} };

  /* One "Download" event per click, with the platform and where it was clicked. */
  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest("a[data-dl]");
    if (a) track("Download", { platform: a.getAttribute("data-dl"), from: a.getAttribute("data-where") || "page" });
    var o = e.target.closest && e.target.closest("a[data-out]");
    if (o) track("Board store", { store: o.getAttribute("data-out") });
  });

  /* The bridge mailing list posts straight to Kit's form endpoint (double opt-in). */
  var form = document.getElementById("signup");
  if (!form) return;
  var note = form.querySelector(".signup__note"), input = form.querySelector("input"), button = form.querySelector("button");
  var say = function (state, text, link) {
    form.setAttribute("data-state", state);
    note.textContent = text;
    if (link) { var a = document.createElement("a"); a.href = link; a.target = "_blank"; a.rel = "noopener"; a.textContent = "Continue at Kit"; note.append(" ", a); }
  };
  input.addEventListener("input", function () { if (form.getAttribute("data-state") !== "sending") say("idle", ""); });
  form.addEventListener("submit", function (e) {
    e.preventDefault();
    if (form.getAttribute("data-state") === "sending") return;
    if (!input.value.trim() || !input.checkValidity()) { say("failed", "Enter an email address, like you@example.com."); input.focus(); return; }
    say("sending", "Sending…"); button.disabled = true;
    var body = new FormData(); body.append("email_address", input.value.trim());
    var stop = new AbortController(), timer = setTimeout(function () { stop.abort(); }, 15000);
    fetch("https://app.kit.com/forms/" + form.getAttribute("data-kit") + "/subscriptions", {
      method: "POST", body: body, headers: { Accept: "application/json" }, signal: stop.signal
    }).then(function (res) {
      return res.json().catch(function () { return null; }).then(function (out) {
        if (res.ok && out && out.status === "quarantined" && out.url) return say("check", "One more step: Kit asks you to confirm you're a person.", out.url);
        if (!res.ok || !out || out.status !== "success") throw new Error((out && out.errors && out.errors.messages && out.errors.messages[0]) || "That didn't go through.");
        say("sent", "Check your inbox for a link to confirm.");
        input.value = ""; track("Bridge signup");
      });
    }).catch(function (err) {
      var msg = /abort|failed to fetch|load failed|networkerror/i.test(String(err && (err.name + err.message))) ? "Couldn't reach the form service." : err.message;
      say("failed", (/[.!?]$/.test(msg) ? msg : msg + ".") + " Try again in a moment.");
    }).then(function () { clearTimeout(timer); button.disabled = false; });
  });
})();
