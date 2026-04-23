<div class="chat-widget">
  <div class="chat-box" id="chatBox">
    <div class="chat-header">
      <span>🍽️ Grizzy's Assistant</span>
      <button class="chat-close" onclick="toggleChat()">✕</button>
    </div>
    <div class="chat-messages" id="chatMessages">
      <div class="chat-msg bot">Hi there! I'm Grizzy's virtual assistant. I can help you find meal kits or check your order status. What can I help you with?</div>
    </div>
    <div class="chat-input-row">
      <input type="text" id="chatInput" placeholder="Type a message..." onkeydown="if(event.key==='Enter')sendChat()">
      <button onclick="sendChat()">➤</button>
    </div>
  </div>
  <button class="chat-btn" onclick="toggleChat()" id="chatToggle">💬</button>
</div>
<script>
function toggleChat() {
  var box = document.getElementById('chatBox');
  box.classList.toggle('open');
}
var chatHistory = [];
async function sendChat() {
  var input = document.getElementById('chatInput');
  var msg = input.value.trim();
  if (!msg) return;
  input.value = '';
  appendMsg(msg, 'user');
  chatHistory.push({role:'user',content:msg});
  var thinking = appendMsg('...', 'bot');
  try {
    var res = await fetch('/api/agent.php', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({messages: chatHistory})
    });
    var data = await res.json();
    thinking.textContent = data.reply || 'Sorry, something went wrong.';
    chatHistory.push({role:'assistant',content:data.reply});
  } catch(e) {
    thinking.textContent = 'Connection error. Please try again.';
  }
}
function appendMsg(text, role) {
  var div = document.createElement('div');
  div.className = 'chat-msg ' + role;
  div.textContent = text;
  var msgs = document.getElementById('chatMessages');
  msgs.appendChild(div);
  msgs.scrollTop = msgs.scrollHeight;
  return div;
}
</script>
