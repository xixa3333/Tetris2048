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
function AppView:showUpdatePrompt(version,update)
    native.showAlert("發現新版本","Tetris2048 v"..version.." 已發布，是否前往下載？",
        {"前往下載","稍後"},function(event)
            if event.action=="clicked" and event.index==1 then update() end
        end)
end
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
    button(g,"遊戲開始",250,260,actions.start)
    button(g,"遊戲介紹",250,335,actions.intro)
    button(g,"排行榜／帳號",250,410,actions.leaderboard)
    button(g,"APP 資訊",250,485,actions.info)
    button(g,"設定",250,560,actions.settings)
    button(g,"退出遊戲",250,635,actions.exit)
    local version=display.newText({parent=g,text="v"..actions.version,x=475,y=825,
        font=native.systemFontBold,fontSize=15})
    version.anchorX=1; version:setTextColor(CYAN[1],CYAN[2],CYAN[3])
end
function AppView:showSettings(model,save,back)
    -- Keep the settings screen on the same 500 x 850 layout grid as the cover.
    -- config.lua letterboxes this grid on every device, preventing controls from drifting.
    local g=self:_screen("設定")
    local backgroundLabel=text(g,"背景音樂："..model.backgroundVolume.."%",250,165,21,BRIGHT)
    local background=widget.newSlider({x=250,y=215,width=360,value=model.backgroundVolume,
        listener=function(event) model.backgroundVolume=math.floor(event.value+0.5); backgroundLabel.text="背景音樂："..model.backgroundVolume.."%" end})
    g:insert(background)
    local effectLabel=text(g,"消除音效："..model.effectVolume.."%",250,290,21,BRIGHT)
    local effect=widget.newSlider({x=250,y=340,width=360,value=model.effectVolume,
        listener=function(event) model.effectVolume=math.floor(event.value+0.5); effectLabel.text="消除音效："..model.effectVolume.."%" end})
    g:insert(effect)
    text(g,"關卡種子",250,420,23,ACCENT)
    text(g,"相同種子會重現相同的方塊與落點順序，\n適合和朋友挑戰同一關；留空就是一般隨機。",250,475,17,BRIGHT)
    local seed=native.newTextField(250,555,360,50); seed.placeholder="留空＝隨機"; seed.text=model.seed or ""
    self.fields={seed}
    button(g,"儲存設定",250,655,function() model.seed=seed.text; save(model) end)
    button(g,"取消",250,735,back,160)
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
function AppView:showAppInfo(info,model,actions)
    local g=self:_screen("APP 資訊")
    button(g,"遊戲 GitHub",140,155,actions.repository,190,50)
    button(g,"問題回報區",360,155,actions.issues,190,50)
    local release=model.items[1]
    text(g,"版本 "..release.version,250,250,24,ACCENT)
    local lines={}
    for _,item in ipairs(release.bullets) do lines[#lines+1]="• "..item end
    text(g,table.concat(lines,"\n"),250,370,18,BRIGHT)
    if model.hasPrevious then button(g,"較新版本",120,585,actions.previous,150,46) end
    text(g,string.format("%d / %d",model.page,model.totalPages),250,585,18,ACCENT)
    if model.hasNext then button(g,"較舊版本",380,585,actions.next,150,46) end
    button(g,"作者 GitHub：xixa3333",250,680,actions.author,300,50)
    button(g,"返回封面",250,775,actions.back,170,48)
end
function AppView:showAuth(actions)
    local g=self:_screen("登入排行榜")
    text(g,"帳號 ID 具有唯一性（3～20 字元）",250,155,19,CYAN)
    local account=native.newTextField(250,245,370,50); account.placeholder="帳號 ID"; account.inputType="default"
    local password=native.newTextField(250,315,370,50); password.placeholder="密碼（至少 6 個字元）"; password.isSecure=true
    self.fields={account,password}; self.status=text(g,"",250,380,17,{1,0.65,0.35})
    button(g,"登入",155,465,function() actions.login(account.text,password.text) end,150)
    button(g,"註冊",345,465,function() actions.register(account.text,password.text) end,150)
    button(g,"舊信箱忘記密碼",250,550,function() actions.forgot(account.text) end,220)
    button(g,"返回",250,635,actions.back,150)
end
function AppView:showAccountInfo(account,back)
    local g=self:_screen("帳號 ID")
    text(g,"目前 ID："..account,250,230,22,CYAN)
    text(g,"帳號 ID 建立後不可修改",250,310,19,BRIGHT)
    button(g,"返回排行榜",250,500,back)
end
function AppView:showLegacyMigration(save,back)
    local g=self:_screen("轉換舊帳號")
    text(g,"舊信箱帳號需轉換為永久 ID\n暱稱與全球最高分會保留",250,170,18,BRIGHT)
    local account=native.newTextField(250,285,370,50); account.placeholder="新的永久帳號 ID"
    local password=native.newTextField(250,355,370,50); password.placeholder="目前密碼"; password.isSecure=true
    self.fields={account,password}; self.status=text(g,"",250,425,16,{1,0.65,0.35})
    button(g,"確認轉換",250,520,function() save(account.text,password.text) end)
    button(g,"稍後再說",250,610,back)
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
    button(g,"本機",46,150,actions.localTab,82); button(g,"全球",148,150,actions.globalTab,82)
    button(g,actions.accountLabel or "帳號 ID",250,150,actions.account,82); button(g,"暱稱",352,150,actions.nickname,82)
    button(g,"密碼",454,150,actions.password,82)
    if model.ownRank then
        local rankBackground=display.newRoundedRect(g,250,202,310,34,10)
        rankBackground:setFillColor(0.12,0.34,0.52)
        text(g,"我的全球名次：第 "..model.ownRank.." 名",250,202,17,BRIGHT)
    end
    if model.totalCount==0 then text(g,"目前沒有紀錄",250,290,20,BRIGHT) end
    for i,record in ipairs(model.items) do
        local y=200+i*44
        if record.isCurrent then
            local rowBackground=display.newRoundedRect(g,245,y,470,38,8)
            rowBackground:setFillColor(0.12,0.34,0.52)
        end
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
