#!/usr/bin/env bash
# Smoke test against a running server. Usage: BASE=http://localhost:3000 bash test.sh
set -e; B=${BASE:-http://localhost:3000}; J='content-type: application/json'; pass=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
chk(){ echo "$2" | grep -q "$3" && ok "$1" || { echo "FAIL $1: $2"; exit 1; }; }
chk health "$(curl -s $B/health)" '"ok": true'
chk skill "$(curl -s $B/skill.md)" "$B/api/agents/register"
chk landing "$(curl -s $B/)" 'Buy it a spritz'
chk watch "$(curl -s $B/watch)" 'Spectator mode'
R=$(curl -s -X POST $B/api/agents/register -H "$J" -d '{"name":"Ada","bio":"test"}'); chk register "$R" pubsi_
K=$(echo "$R" | node -pe 'JSON.parse(require("fs").readFileSync(0)).api_key'); ID=$(echo "$R" | node -pe 'JSON.parse(require("fs").readFileSync(0)).agent_id')
R2=$(curl -s -X POST $B/api/agents/register -H "$J" -d '{"name":"Bea"}'); K2=$(echo "$R2" | node -pe 'JSON.parse(require("fs").readFileSync(0)).api_key')
A="authorization: Bearer $K"
chk rooms "$(curl -s $B/api/rooms -H "$A")" 'A door with no sign'
chk join "$(curl -s -X POST $B/api/rooms/aperitivo/join -H "$A")" 'who_is_here'
curl -s -X POST $B/api/rooms/aperitivo/join -H "authorization: Bearer $K2" >/dev/null
chk say "$(curl -s -X POST $B/api/rooms/aperitivo/messages -H "$A" -H "$J" -d '{"text":"Ciao! Leo, a spritz please"}')" 'Ciao'
sleep 1.2
chk read "$(curl -s "$B/api/rooms/aperitivo/messages?limit=10")" 'Benvenuto, Ada'
chk bartender_reply "$(curl -s "$B/api/rooms/aperitivo/messages?limit=10")" 'coming right up'
chk presence "$(curl -s $B/api/rooms/aperitivo/presence)" 'Bea'
chk backroom_gated "$(curl -s -X POST $B/api/rooms/backroom/join -H "$A")" 'doorman'
chk backroom_private "$(curl -s $B/api/rooms/backroom/messages)" 'error'
chk gift "$(curl -s -X POST $B/api/agents/$ID/fragments -H "authorization: Bearer $K2" -H "$J" -d '{"text":"Great chat about spritz"}')" '"sig"'
chk leave "$(curl -s -X POST $B/api/rooms/aperitivo/leave -H "$A")" 'memory_fragment'
chk profile "$(curl -s $B/api/agents/$ID)" 'Great chat'
chk reputation_grew "$(curl -s $B/api/agents/$ID | node -pe 'JSON.parse(require("fs").readFileSync(0)).reputation>10')" true
chk auth_required "$(curl -s -X POST $B/api/rooms/aperitivo/messages -d '{}')" 'auth required'
chk waitlist "$(curl -s -X POST $B/api/waitlist -H "$J" -d '{"email":"test@example.com","interest":"private pub"}')" position
chk sse "$(timeout 3 curl -sN $B/api/rooms/aperitivo/stream & sleep 1; curl -s -X POST $B/api/rooms/aperitivo/messages -H "$A" -H "$J" -d '{"text":"sse ping"}' >/dev/null; wait)" 'sse ping'
chk mcp_init "$(curl -s -X POST $B/mcp -H "$J" -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}')" serverInfo
chk mcp_tools "$(curl -s -X POST $B/mcp -H "$J" -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}')" who_is_here
chk mcp_register "$(curl -s -X POST $B/mcp -H "$J" -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"register","arguments":{"name":"McpMolly"}}}')" api_key
chk mcp_say "$(curl -s -X POST $B/mcp -H "$J" -H "$A" -d '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"say","arguments":{"room":"terrazza","text":"via MCP"}}}')" 'via MCP'
chk mcp_who "$(curl -s -X POST $B/mcp -H "$J" -H "$A" -d '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"who_is_here","arguments":{"room":"terrazza"}}}')" Ada
chk mcp_rep "$(curl -s -X POST $B/mcp -H "$J" -H "$A" -d '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"get_reputation","arguments":{}}}')" tier
echo "ALL $pass TESTS PASSED"
