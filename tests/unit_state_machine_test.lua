local T=require("test_helper")
local StateMachine=require("state_machine")

local function build()
    local owner={log={},changes={}}
    local function mark(name) return function(app) app.log[#app.log+1]=name end end
    local machine=StateMachine.new({owner=owner,initial="app",
        onChange=function(app,state) app.changes[#app.changes+1]=state end,
        states={
            app={initial="menu",on={back="cover",resume="cover"}},
            cover={parent="app",enter=mark("+cover"),exit=mark("-cover")},
            menu={parent="app",initial="intro",enter=mark("+menu"),exit=mark("-menu"),
                on={resume=function(_,_,current) return current end}},
            intro={parent="menu",enter=mark("+intro"),exit=mark("-intro")},
            settings={parent="menu",enter=mark("+settings"),exit=mark("-settings")},
            modeSelect={parent="menu",enter=mark("+modeSelect"),on={resume="cover"}},
            game={parent="app",enter=mark("+game"),on={resume=function(app) app.resumed=true end}}
        }})
    return machine,owner
end

T.test("State machine resolves the initial leaf through every composite state",function()
    local machine,owner=build()
    T.equal(machine:state(),"intro")
    T.equal(table.concat(owner.log,","),"+menu,+intro")
    T.equal(machine:isIn("menu"),true); T.equal(machine:isIn("app"),true)
    T.equal(machine:isIn("cover"),false)
end)

T.test("Transitions inside one group keep the shared parent entered",function()
    local machine,owner=build(); owner.log={}
    machine:enter("settings")
    T.equal(table.concat(owner.log,","),"-intro,+settings")
    T.equal(machine:state(),"settings")
end)

T.test("Leaving a group exits children before parents and enters parents first",function()
    local machine,owner=build(); owner.log={}
    machine:enter("cover")
    T.equal(table.concat(owner.log,","),"-intro,-menu,+cover")
end)

T.test("Self transition re-renders the leaf without re-entering its parents",function()
    local machine,owner=build(); machine:enter("settings"); owner.log={}
    machine:enter("settings")
    T.equal(table.concat(owner.log,","),"-settings,+settings")
end)

T.test("Events bubble from the leaf and children override their parent",function()
    local machine=build(); machine:enter("settings")
    T.equal(machine:dispatch("resume"),true); T.equal(machine:state(),"settings")
    machine:enter("modeSelect"); machine:dispatch("resume")
    T.equal(machine:state(),"cover")
    machine:enter("settings"); machine:dispatch("back")
    T.equal(machine:state(),"cover")
end)

T.test("Function transitions act as guards and may stay in place",function()
    local machine,owner=build(); machine:enter("game")
    T.equal(machine:dispatch("resume"),true)
    T.equal(owner.resumed,true); T.equal(machine:state(),"game")
end)

T.test("Unknown events are reported instead of silently transitioning",function()
    local machine=build()
    T.equal(machine:dispatch("teleport"),false)
    T.equal(machine:handles("teleport"),false)
    T.equal(machine:handles("back"),true)
    T.equal(machine:state(),"intro")
end)

T.test("Boundary: unknown states and missing definitions fail loudly",function()
    local machine=build()
    T.equal(pcall(function() machine:enter("nowhere") end),false)
    T.equal(pcall(function() StateMachine.new({}) end),false)
    T.equal(pcall(function()
        StateMachine.new({initial="a",states={a={parent="ghost"}}})
    end),false)
end)

T.test("Boundary: a transition inside enter cancels the outdated entry chain",function()
    local log={}
    local machine=StateMachine.new({owner={},states={
        root={initial="first"},
        first={parent="root",enter=function(_,_,name) log[#log+1]=name end},
        group={parent="root",enter=function(app,payload,name) log[#log+1]=name end},
        skipped={parent="group",enter=function() log[#log+1]="skipped" end}
    },initial="root"})
    machine.states.group.enter=function() log[#log+1]="group"; machine:enter("first") end
    machine:enter("skipped")
    T.equal(machine:state(),"first")
    T.equal(table.concat(log,","),"first,group,first")
end)

T.test("State change notification exposes the new leaf before its enter handler runs",function()
    local order={}
    local machine=StateMachine.new({owner={},states={
        root={initial="idle"},
        idle={parent="root"},
        busy={parent="root",enter=function() order[#order+1]="enter" end}
    },initial="root",onChange=function(_,state) order[#order+1]="change:"..state end})
    order={}
    machine:enter("busy")
    T.equal(table.concat(order,","),"change:busy,enter")
end)
