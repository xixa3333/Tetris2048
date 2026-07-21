local widget = require("widget")
local AppView = {}; AppView.__index = AppView

local function remove(o) if o and o.removeSelf then o:removeSelf() end end
local function text(group, value, x, y, size, color)
    local o = display.newText({parent=group,text=value,x=x,y=y,width=450,align="center",
        font=native.systemFont,fontSize=size or 20})
    color=color or {1,1,1}; o:setTextColor(color[1],color[2],color[3]); return o
end
local function button(group, value, x, y, action, width)
    local o=widget.newButton({defaultFile="image/explode1.png",overFile="image/explode3.png",
        label=value,fontSize=20,x=x,y=y,width=width or 220,height=55,
        onRelease=function() action(); return true end})
    group:insert(o); return o
end

function AppView.new() return setmetatable({fields={}},AppView) end
function AppView:hide()
    for _,field in ipairs(self.fields) do remove(field) end
    self.fields={}; remove(self.group); self.group=nil; self.status=nil
end
function AppView:_screen(title)
    self:hide(); self.group=display.newGroup()
    local bg=display.newRect(self.group,250,425,500,850); bg:setFillColor(0.05,0.08,0.13)
    text(self.group,title,250,95,42,{1,0.82,0.15}); return self.group
end
function AppView:showCover(actions,user)
    local g=self:_screen("TETRIS 2048")
    text(g,"方塊 × 滑動 × 消除",250,155,20,{0.5,0.9,1})
    if user then text(g,"玩家："..(user.nickname or user.account),250,205,16) end
    button(g,"遊戲開始",250,300,actions.start); button(g,"遊戲介紹",250,385,actions.intro)
    button(g,"排行榜",250,470,actions.leaderboard); button(g,"退出遊戲",250,555,actions.exit)
end
function AppView:showIntro(back)
    local g=self:_screen("遊戲介紹")
    text(g,"W/A/S/D 或畫面按鈕移動方塊\nR 旋轉下一塊，Space 保留方塊\n\n每次移動後，會在放置新方塊前後\n各判定一次完整橫列與直行。\n每消除一條得 10 分。",250,360,19)
    button(g,"返回",250,690,back)
end
function AppView:showAuth(actions)
    local g=self:_screen("登入排行榜"); text(g,"使用電子郵件作為唯一帳號",250,175,18)
    local email=native.newTextField(250,265,360,48); email.placeholder="電子郵件帳號"; email.inputType="email"
    local password=native.newTextField(250,335,360,48); password.placeholder="密碼（至少 6 個字元）"; password.isSecure=true
    self.fields={email,password}; self.status=text(g,"",250,405,16,{1,0.45,0.45})
    button(g,"登入",170,490,function() actions.login(email.text,password.text) end,140)
    button(g,"註冊",330,490,function() actions.register(email.text,password.text) end,140)
    button(g,"返回",250,590,actions.back)
end
function AppView:setStatus(value) if self.status then self.status.text=value end end
function AppView:showNickname(save,back)
    local g=self:_screen("設定暱稱")
    text(g,"排行榜會顯示此暱稱（2～16 個字元）",250,200,18)
    local nickname=native.newTextField(250,300,360,48); nickname.placeholder="玩家暱稱"
    self.fields={nickname}; self.status=text(g,"",250,370,16,{1,0.45,0.45})
    button(g,"儲存",250,465,function() save(nickname.text) end)
    button(g,"返回",250,555,back)
end
function AppView:showLeaderboard(title,records,actions,canDelete)
    local g=self:_screen(title)
    button(g,"個人",125,165,actions.localTab,130); button(g,"全球",275,165,actions.globalTab,130)
    button(g,"暱稱",405,165,actions.nickname,85)
    button(g,"登出",465,225,actions.logout,65)
    if #records==0 then text(g,"目前沒有紀錄",250,300,20) end
    for i=1,math.min(#records,8) do
        local record=records[i]; local y=230+i*55
        text(g,string.format("%d. %s   %d 分",i,record.nickname or record.account or "玩家",record.score),215,y,17)
        if canDelete then button(g,"刪除",430,y,function() actions.delete(record.id) end,75) end
    end
    button(g,"返回封面",250,770,actions.back)
end
function AppView:showLoading(value) local g=self:_screen("排行榜"); text(g,value,250,360,20) end
function AppView:showError(value,back)
    local g=self:_screen("連線錯誤"); text(g,value,250,350,20,{1,0.45,0.45}); button(g,"返回",250,500,back)
end
return AppView
