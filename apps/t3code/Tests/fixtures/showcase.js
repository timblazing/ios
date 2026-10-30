// Rich, realistic state for screenshots: shelves, statuses, grouped tool activity, Markdown, an approval card.
(function(){var now=Date.now(),iso=function(min){return new Date(now-min*60000).toISOString();};
document.getElementById('project-filter').value='';document.getElementById('search').value='';try{localStorage.removeItem('t3code.settledOpen');}catch(e){}
window.sent=[];window.webkit={messageHandlers:{client:{postMessage:function(m){window.sent.push(m)}}}};
receive({type:'connecting'});receive({type:'paired',canWrite:true});receive({type:'environment',label:'mac'});
receive({type:'catalog',providers:[{instanceId:'claude',title:'Claude',enabled:true,installed:true,supportedRuntimeModes:['approval-required'],models:[{id:'opus',label:'Claude Opus 5.5'}]},{instanceId:'codex',title:'Codex',enabled:true,installed:true,supportedRuntimeModes:['approval-required'],models:[{id:'gpt-6-luna',label:'GPT-6 Luna'}]}]});
var m={instanceId:'claude',model:'opus'};
receive({type:'threads',address:'http://192.168.1.73:3774/',canWrite:true,projects:[{id:'p1',title:'ios',defaultModelSelection:m},{id:'p2',title:'gateway',defaultModelSelection:m},{id:'p3',title:'t3code',defaultModelSelection:m}],threads:[
{id:'t1',projectId:'p1',title:'Build T3 Code for iPad',status:'running',activeRunId:'r1',updatedAt:iso(0.5),modelSelection:m},
{id:'t5',projectId:'p2',title:'Rotate gateway certificates',status:'waiting',updatedAt:iso(3),pendingRuntimeRequest:{kind:'approval'},modelSelection:m},
{id:'t2',projectId:'p3',title:'Mobile design review',status:'idle',settledOverride:'settled',settledAt:iso(14),updatedAt:iso(14),modelSelection:m},
{id:'t3',projectId:'p1',title:'Device validation',status:'failed',lastErrorClass:'usage_limit',settledOverride:'settled',settledAt:iso(190),updatedAt:iso(190),modelSelection:m},
{id:'t4',projectId:'p2',title:'Investigate flaky websocket reconnect on wake',status:'failed',lastErrorClass:'usage_limit',updatedAt:iso(60*26),modelSelection:m}]});
document.querySelector('[data-thread-id="t1"]').click();
receive({type:'messages',id:'t1',thread:{id:'t1',title:'Build T3 Code for iPad',projectId:'p1',status:'running',activeRunId:'r1',modelSelection:m},items:[
{id:'u1',type:'user_message',text:'Make the iPad app match the official T3 Code iOS app.',updatedAt:iso(4)},
{id:'x1',type:'reasoning',text:'Reading the mobile source first.',status:'completed'},
{id:'x2',type:'command_execution',input:'git clone --depth 1 https://github.com/pingdotgg/t3code',output:'Cloning…\ndone.',status:'completed',exitCode:0},
{id:'x3',type:'dynamic_tool_call',title:'Read ThreadFeed.tsx',status:'completed'},
{id:'x4',type:'dynamic_tool_call',title:'Read ThreadComposer.tsx',status:'completed'},
{id:'a1',type:'assistant_message',text:'## Design notes\n\nThe feed uses **DM Sans** at `16/23`, a `#161616` user bubble and plain assistant text.\n\n- Sidebar: 328pt, `#000`\n- Composer: 27pt pill\n\n```css\n.bubble { border-radius: 20px; }\n```',updatedAt:iso(2),completedAt:iso(2)},
{id:'x5',type:'file_change',fileName:'chat.css',title:'Edited chat.css',additions:212,deletions:48,status:'completed'},
{id:'x6',type:'command_execution',input:'make package FINALPACKAGE=1',status:'running',streaming:true},
{id:'q1',type:'approval_request',requestId:'rq1',title:'Run make package?',prompt:'Allow the agent to run `make package FINALPACKAGE=1` in ios?',reason:'Writes build output to .theos/',options:[{decision:'accept',label:'Allow once'},{decision:'acceptForSession',label:'Allow session'},{decision:'decline',label:'Decline'}]}],
requests:[{id:'rq1',kind:'approval',status:'pending',responseCapability:'live'}]});
if(document.querySelectorAll('#threads .thread').length!==3)throw Error('Settled threads should start collapsed');if(!/Settled \(2\)/.test(document.querySelector('#threads .shelf').textContent))throw Error('Settled count missing');if(!/Limited/.test(document.getElementById('threads').textContent))throw Error('Usage limit should read Limited');return 'ok';})();
