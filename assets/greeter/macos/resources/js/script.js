var time_remaining = 0;
var selected_user = null;
var valid_image = /.*\.(png|svg|jpg|jpeg|bmp)$/i;

///////////////////////////////////////////////
// CALLBACK API. Called by the webkit greeeter
///////////////////////////////////////////////

// called when the greeter asks to show a login prompt for a user
function show_prompt(text) {
  var password_container = document.querySelector("#password_container");
  var password_entry = document.querySelector("#password_entry");
  if (!isVisiblePass(password_container)) {
    var users = document.querySelectorAll(".user");
    var user_node = document.querySelector("#"+selected_user);
    var rect = user_node.getClientRects()[0];
    var parentRect = user_node.parentElement.getClientRects()[0];
    var center = parentRect.width/2;
    var left = center - rect.width/2 - rect.left;
    var i = 0;
    if (left < 5 && left > -5) {
      left = 0;
    }
    for (i = 0; i < users.length; i++) {
      var node = users[i];
      setVisible(node, node.id === selected_user);
      node.style.left= left;
    }

    setVisiblePass(password_container, true);
    password_entry.placeholder= text.replace(":", "");
  }
  password_entry.value= "";
  password_entry.focus();
}

// called when the greeter asks to show a message
function show_message(text) {
  var message = document.querySelector("#message_content");
  message.innerHTML= text;
  if (text) {
    document.querySelector("#message").classList.remove("hidden");
  } else {
    document.querySelector("#message").classList.add("hidden");
  }
  message.classList.remove("error");
}

// called when the greeter asks to show an error
function show_error(text) {
  show_message(text);
  var message = document.querySelector("#message_content");
  message.classList.add("error");
}

// called when the greeter is finished the authentication request
function authentication_complete() {
  if (lightdm.is_authenticated) {
    // web-greeter/nody NON ha lightdm.login(): la sessione si avvia con
    // start_session(key). default_session è la chiave (stringa) della sessione.
    if (typeof lightdm.start_session === "function") {
      lightdm.start_session(lightdm.default_session);
    } else if (typeof lightdm.login === "function") {
      lightdm.login(lightdm.authentication_user, lightdm.default_session);
    }
  } else {
    show_error("Authentication Failed");
    start_authentication(selected_user);
  }
}

// called when the greeter wants us to perform a timed login
function timed_login(user) {
  if (typeof lightdm.start_session === "function") {
    lightdm.start_session(lightdm.default_session);
  } else if (typeof lightdm.login === "function") {
    lightdm.login(lightdm.timed_login_user);
  }
}

//////////////////////////////
// Implementation
//////////////////////////////
function start_authentication(username) {
  if (typeof lightdm.cancel_timed_login === "function") {
    lightdm.cancel_timed_login();
  } else if (typeof lightdm.cancel_autologin === "function") {
    lightdm.cancel_autologin();
  }
  selected_user = username;
  if (typeof lightdm.start_authentication === "function") {
    lightdm.start_authentication(username);
  } else {
    lightdm.authenticate(username);
  }
}

function provide_secret() {
  show_message("Logging in...");
  entry = document.querySelector('#password_entry');
  if (typeof lightdm.provide_secret === "function") {
    lightdm.provide_secret(entry.value);
  } else {
    lightdm.respond(entry.value);
  }
}

function initialize_sessions() {
  var template = document.querySelector("#session_template");
  var container = session_template.parentElement;
  var i = 0;
  container.removeChild(template);

  for (i = 0; i < lightdm.sessions.length; i = i + 1) {
    var session = lightdm.sessions[i];
    var s = template.cloneNode(true);
    s.id = "session_" + session.key;

    var label = s.querySelector(".session_label");
    var radio = s.querySelector("input");

    console.log(s, session);
    label.innerHTML = session.name;
    radio.value = session.key;

    if (session.key === lightdm.default_session.key) {
      radio.checked = true;
    }

    session_container.appendChild(s);
  }
}

function show_users() {
  var users = document.querySelectorAll(".user");
  var i = 0;
  for (i= 0; i < users.length; i++) {
    setVisible(users[i], true);
    users[i].style.left = 0;
  }
  setVisiblePass(document.querySelector("#password_container"), false);
  selected_user = null;
}

function user_clicked(event) {
  if (selected_user !== null) {
    selected_user = null;
    lightdm.cancel_authentication();
    show_users();
  } else {
    selected_user = event.currentTarget.id;
    start_authentication(event.currentTarget.id);
  }
  show_message("");
  event.stopPropagation();
  return false;
}

function setVisible(element, visible) {
  if (visible) {
    element.classList.remove("hidden");
  } else {
    element.classList.add("hidden");
  }
}

function setVisiblePass(element, visible) {
  if (visible) {
    element.classList.remove("passhidden");
  } else {
    element.classList.add("passhidden");
  }
}

function isVisible(element) {
  return !element.classList.contains("hidden");
}

function isVisiblePass(element) {
  return !element.classList.contains("passhidden");
}

function update_time() {
  var now = new Date();
  var time = document.querySelector("#current_time");
  var dateEl = document.querySelector("#current_date");

  var hh = now.getHours();
  var mm = now.getMinutes();
  if (hh < 10) { hh = "0" + hh; }
  if (mm < 10) { mm = "0" + mm; }
  if (time) { time.innerHTML = hh + ":" + mm; }

  if (dateEl) {
    var s = now.toLocaleDateString("it-IT", {
      weekday: "long", day: "numeric", month: "long"
    });
    dateEl.innerHTML = s.charAt(0).toUpperCase() + s.slice(1);
  }
}
//////////////////////////////////
// Initialization
//////////////////////////////////

// nody-greeter / web-greeter usano un modello a SEGNALI: i callback del tema
// non vengono chiamati come funzioni globali, vanno collegati con .connect().
// (Il vecchio lightdm-webkit-greeter invece li invocava direttamente.)
function wire_lightdm_signals() {
  if (typeof lightdm === "undefined" || !lightdm) {
    return;
  }
  // Prompt password/utente -> mostra la pillola e dà il focus
  if (lightdm.show_prompt && typeof lightdm.show_prompt.connect === "function") {
    lightdm.show_prompt.connect(function (text, type) {
      show_prompt(typeof text === "string" ? text : "");
    });
  }
  // Messaggi dal PAM: type 1 = errore, altrimenti info
  if (lightdm.show_message && typeof lightdm.show_message.connect === "function") {
    lightdm.show_message.connect(function (text, type) {
      if (type === 1 || type === "error") {
        show_error(text);
      } else {
        show_message(text);
      }
    });
  }
  // Esito autenticazione
  if (lightdm.authentication_complete &&
      typeof lightdm.authentication_complete.connect === "function") {
    lightdm.authentication_complete.connect(authentication_complete);
  }
  // Login temporizzato (autologin) — opzionale
  if (lightdm.autologin_timer_expired &&
      typeof lightdm.autologin_timer_expired.connect === "function") {
    lightdm.autologin_timer_expired.connect(function () {
      if (lightdm.autologin_user) {
        timed_login(lightdm.autologin_user);
      }
    });
  }
}

function initialize() {
  wire_lightdm_signals();
  show_message("");
  initialize_users();
  initialize_timer();
}

function on_image_error(e) {
  e.currentTarget.src = "resources/img/avatar.svg";
}

function initialize_users() {
  var template = document.querySelector("#user_template");
  var parent = template.parentElement;
  parent.removeChild(template);

  for (i = 0; i < lightdm.users.length; i += 1) {
    user = lightdm.users[i];
    userNode = template.cloneNode(true);

    var image = userNode.querySelectorAll(".user_image")[0];
    var name = userNode.querySelectorAll(".user_name")[0];
    name.innerHTML = user.display_name;

    if (user.image) {
      image.src = user.image;
      image.onerror = on_image_error;
    } else {
      image.src = "resources/img/avatar.svg";
    }

    // nody-greeter/web-greeter espongono "username" (non "name", che era la
    // vecchia API lightdm-webkit). Senza questo l'id diventava "undefined" e
    // authenticate() veniva chiamato con username "undefined" -> PAM "user
    // unknown" -> password (anche corretta) sempre rifiutata.
    userNode.id = user.username || user.name;
    userNode.onclick = user_clicked;
    parent.appendChild(userNode);
  }
  setTimeout(show_users, 400);
}

function initialize_timer() {
  update_time();
  setInterval(update_time, 1000);
}

function add_action(id, name, image, clickhandler, template, parent) {
  action_node = template.cloneNode(true);
  action_node.id = "action_" + id;
  img_node = action_node.querySelectorAll(".action_image")[0];
  label_node = action_node.querySelectorAll(".action_label")[0];
  label_node.innerHTML = name;
  img_node.src = image;
  action_node.onclick = clickhandler;
  parent.appendChild(action_node);
}
