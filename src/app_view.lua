local widget=require("widget")
local gameGuide=require("game_guide")
local AppView={}; AppView.__index=AppView
local BRIGHT={1,1,1}; local ACCENT={1,0.9,0.25}; local CYAN={0.45,0.95,1}
local function remove(o) if o and o.removeSelf then o:removeSelf() end end
local function text(group,value,x,y,size,color)
    local o=display.newText({parent=group,text=value,x=x,y=y,width=460,align="center",
        font=native.systemFontBold,fontSize=size or 20})
    color=color or BRIGHT; o:setTextColor(color[1],color[2],color[3]); return o
end
local function button(group,value,x,y,action,width,height)
    local o=widget.newButton({defaultFile="image/explode1.png",overFile="image/explode3.png",
        label=value,font=native.systemFontBold,fontSize=21,
        labelColor={default=BRIGHT,over=ACCENT},emboss=true,
        x=x,y=y,width=width or 220,height=height or 58,onRelease=function() action(); return true end})
    group:insert(o); return o
end
function AppView.new() return setmetatable({fields={}},AppView) end
function AppView:hide()
    for _,field in ipairs(self.fields) do remove(field) end
    self.fields={}; remove(self.group); self.group=nil; self.status=nil
end
function AppView:_screen(title)
    self:hide(); self.group=display.newGroup()
    local bg=display.newRect(self.group,250,425,500,850); bg:setFillColor(0.04,0.07,0.12)
    text(self.group,title,250,85,42,ACCENT); return self.group
end
function AppView:showCover(actions,user)
    local g=self:_screen("TETRIS 2048")
    text(g,"方塊 × 滑動 × 消除",250,145,21,CYAN)
    if user then text(g,"玩家："..(user.nickname or user.account),250,190,18,BRIGHT) end
    button(g,"遊戲開始",250,285,actions.start)
    button(g,"遊戲介紹",250,370,actions.intro)
    button(g,"排行榜／帳號",250,455,actions.leaderboard)
    button(g,"退出遊戲",250,540,actions.exit)
end
function AppView:showIntro(back)
    local g=self:_screen("遊戲介紹")
    local tops={145,285,425,565}
    for index,section in ipairs(gameGuide) do
        text(g,section.title,250,tops[index],20,ACCENT)
        text(g,section.body,250,tops[index]+62,16,BRIGHT)
    end
    button(g,"返回",250,790,back,150,48)
end
function AppView:showAuth(actions)
    local g=self:_screen("登入排行榜")
    text(g,"電子郵件是唯一帳號",250,155,19,CYAN)
    local email=native.newTextField(250,245,370,50); email.placeholder="電子郵件帳號"; email.inputType="email"
    local password=native.newTextField(250,315,370,50); password.placeholder="密碼（至少 6 個字元）"; password.isSecure=true
    self.fields={email,password}; self.status=text(g,"",250,380,17,{1,0.65,0.35})
    button(g,"登入",155,465,function() actions.login(email.text,password.text) end,150)
    button(g,"註冊",345,465,function() actions.register(email.text,password.text) end,150)
    button(g,"忘記密碼",250,550,function() actions.forgot(email.text) end,190)
    button(g,"返回",250,635,actions.back,150)
end
function AppView:setStatus(value) if self.status then self.status.text=value end end
function AppView:showNickname(save,back)
    local g=self:_screen("修改暱稱")
    text(g,"排行榜會顯示此暱稱（2～16 個字元）",250,190,19,BRIGHT)
    local nickname=native.newTextField(250,285,370,50); nickname.placeholder="玩家暱稱"
    self.fields={nickname}; self.status=text(g,"",250,355,17,{1,0.65,0.35})
    button(g,"儲存暱稱",250,455,function() save(nickname.text) end)
    button(g,"返回",250,550,back)
end
function AppView:showPasswordChange(save,back)
    local g=self:_screen("修改密碼")
    text(g,"新密碼至少需要 6 個字元",250,190,19,BRIGHT)
    local password=native.newTextField(250,285,370,50); password.placeholder="新密碼"; password.isSecure=true
    self.fields={password}; self.status=text(g,"",250,355,17,{1,0.65,0.35})
    button(g,"修改密碼",250,455,function() save(password.text) end)
    button(g,"返回",250,550,back)
end
function AppView:showLeaderboard(title,model,actions,canDelete)
    local g=self:_screen(title)
    button(g,"本機",80,150,actions.localTab,100); button(g,"全球",190,150,actions.globalTab,100)
    button(g,"暱稱",300,150,actions.nickname,100); button(g,"密碼",410,150,actions.password,100)
    if model.totalCount==0 then text(g,"目前沒有紀錄",250,290,20,BRIGHT) end
    for i,record in ipairs(model.items) do
        local y=200+i*44
        text(g,string.format("%d. %s   %d 分",model.firstRank+i-1,record.nickname or record.account or "玩家",record.score),205,y,17,BRIGHT)
        if canDelete then
            local selectedRecord=record
            button(g,"刪除",440,y,function() actions.delete(selectedRecord) end,75,38)
        end
    end
    if model.hasPrevious then button(g,"上一頁",125,700,actions.previous,120,46) end
    text(g,string.format("%d / %d",model.page,model.totalPages),250,700,18,ACCENT)
    if model.hasNext then button(g,"下一頁",375,700,actions.next,120,46) end
    button(g,"登出",140,790,actions.logout,150); button(g,"主畫面",350,790,actions.back,170)
end
function AppView:showLoading(value) local g=self:_screen("請稍候"); text(g,value,250,350,21,BRIGHT) end
function AppView:showError(value,back)
    local g=self:_screen("發生錯誤"); text(g,value,250,330,20,{1,0.65,0.35}); button(g,"回到主畫面",250,500,back)
end
return AppView
