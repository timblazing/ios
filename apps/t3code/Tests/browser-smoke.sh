#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
qa_session="t3-code-smoke-$$"
qa_port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
qa_log=$(mktemp)
python3 -m http.server "$qa_port" --bind 127.0.0.1 --directory Resources > "$qa_log" 2>&1 &
qa_server=$!
cleanup() {
  agent-browser --session "$qa_session" close >/dev/null 2>&1 || true
  kill "$qa_server" 2>/dev/null || true
  rm -f "$qa_log"
}
trap cleanup EXIT
curl --silent --fail --retry 5 --retry-connrefused --retry-delay 1 "http://127.0.0.1:$qa_port/" >/dev/null
agent-browser --session "$qa_session" open "http://127.0.0.1:$qa_port/"
agent-browser --session "$qa_session" set viewport 1024 768
agent-browser --session "$qa_session" eval 'localStorage.clear()'
agent-browser --session "$qa_session" eval --stdin < Tests/fixtures/connected.js
agent-browser --session "$qa_session" eval 'document.getElementById("connection-toggle").click();document.getElementById("address").value="editing.local:3774";receive({type:"threads",canWrite:true,projects:[],threads:[]});if(document.getElementById("connection").className.indexOf("hidden")>=0)throw Error("Background refresh closed Connection");if(document.getElementById("address").value!=="editing.local:3774")throw Error("Background refresh replaced address");document.getElementById("connection-toggle").click();'
agent-browser --session "$qa_session" eval --stdin < Tests/fixtures/connected.js
agent-browser --session "$qa_session" eval --stdin < Tests/fixtures/pickers.js
agent-browser --session "$qa_session" eval 'document.getElementById("draft").value="Hello from iPad";document.getElementById("draft").dispatchEvent(new Event("input"));document.getElementById("send").click();document.getElementById("send").click();if(sent.filter(function(m){return m.operation==="command"}).length!==1)throw Error("Duplicate send");'
agent-browser --session "$qa_session" eval --stdin < Tests/fixtures/flows.js
agent-browser --session "$qa_session" eval 'if(!Array.from(document.querySelectorAll("#requests button")).every(function(n){return n.disabled}))throw Error("Background response enabled");'
agent-browser --session "$qa_session" eval --stdin < Tests/fixtures/showcase.js
for qa_size in '1440 900' '1024 768' '768 1024' '393 852'; do
  read -r qa_width qa_height <<< "$qa_size"
  agent-browser --session "$qa_session" set viewport "$qa_width" "$qa_height"
  agent-browser --session "$qa_session" eval 'if(document.documentElement.scrollWidth>innerWidth)throw Error("Horizontal overflow");if(Array.from(document.querySelectorAll("button")).some(function(n){return n.offsetHeight>0&&n.offsetHeight<44}))throw Error("Small tap target");'
done
agent-browser --session "$qa_session" console
agent-browser --session "$qa_session" errors
