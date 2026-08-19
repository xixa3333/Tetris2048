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
    native.showAlert("發現新版本","BlockMerge 2048 v"..version.." 已發布，是否前往下載？",
        {"前往下載","稍後"},function(event)
            if event.action=="clicked" and event.index==1 then update() end
        end)
end
function AppView:showNotice(message)
    native.showAlert("提示",message,{"知道了"})
end
function AppView:confirm(message,onConfirm)
    native.showAlert("請確認",message,{"確定","取消"},function(event)
        if event.action=="clicked" and event.index==1 then onConfirm() end
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
    local g=self:_screen((actions.displayName or "BlockMerge 2048"):upper())
    text(g,"滑動 × 合併感 × 行列消除",250,145,21,CYAN)
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
function AppView:showModeSelect(start,back)
    local g=self:_screen("選擇模式")
    text(g,"模式1：經典連色模式\n同色相連會合併成同一物件，策略性較高。",250,185,19,BRIGHT)
    button(g,"模式1：經典",250,300,function() start(1) end,250,58)
    text(g,"模式2：輕鬆物件模式\n同色相鄰仍保持不同物件，操作更直覺。",250,430,19,BRIGHT)
    button(g,"模式2：輕鬆",250,545,function() start(2) end,250,58)
    button(g,"返回主畫面",250,720,back,190,50)
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
    button(g,"忘記密碼",250,545,function() actions.forgot(account.text) end,220)
    if actions.shortcut then
        button(g,"快捷登入",250,625,actions.shortcut,220)
        button(g,"返回",250,705,actions.back,150)
    else
        button(g,"返回",250,635,actions.back,150)
    end
end
-- 快捷登入：列出這台裝置登入過的帳號，右邊可以單獨移除該筆。
-- 移除只是拿掉快捷登入選項，不會刪除帳號或排行榜紀錄。
function AppView:showShortcutAccounts(accounts,actions)
    local g=self:_screen("快捷登入")
    if #accounts==0 then
        text(g,"這台裝置還沒有登入過的帳號",250,300,20,BRIGHT)
    else
        text(g,"選擇要登入的帳號",250,150,20,CYAN)
        for index,entry in ipairs(accounts) do
            local y=215+(index-1)*70
            local label=entry.name
            if not entry.hasCredential then label=label.."（本機）" end
            button(g,label,180,y,function() actions.select(entry) end,270,54)
            button(g,"移除",410,y,function() actions.forget(entry) end,140,54)
        end
        text(g,"標示「本機」的帳號需要重新輸入密碼才能使用全球排行榜。",250,600,16,BRIGHT)
    end
    self.status=text(g,"",250,680,17,{1,0.65,0.35})
    button(g,"返回",250,760,actions.back,150)
end
function AppView:showAccountInfo(account,back,onDelete)
    local g=self:_screen("帳號 ID")
    text(g,"目前 ID："..account,250,230,22,CYAN)
    text(g,"帳號 ID 建立後不可修改",250,310,19,BRIGHT)
    self.status=text(g,"",250,380,17,{1,0.65,0.35})
    button(g,"返回排行榜",250,470,back)
    if onDelete then button(g,"刪除帳號",250,560,onDelete,220,48) end
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
    local player=model.playerName or "訪客"
    if model.offline then player=player.."（離線）" elseif not model.signedIn then player=player.."（未登入）" end
    button(g,"本機",46,150,actions.localTab,82); button(g,"全球",148,150,actions.globalTab,82)
    button(g,actions.accountLabel or "帳號 ID",250,150,actions.account,82); button(g,"暱稱",352,150,actions.nickname,82)
    button(g,"密碼",454,150,actions.password,82)
    button(g,"模式1",115,190,actions.mode1,120,38)
    button(g,"模式2",250,190,actions.mode2,120,38)
    text(g,"目前：模式"..(model.mode or 1),385,190,16,ACCENT)
    if model.ownRank then
        local rankBackground=display.newRoundedRect(g,250,230,310,34,10)
        rankBackground:setFillColor(0.12,0.34,0.52)
        text(g,"我的全球名次：第 "..model.ownRank.." 名",250,230,17,BRIGHT)
    end
    if model.totalCount==0 then text(g,"目前沒有紀錄",250,310,20,BRIGHT) end
    for i,record in ipairs(model.items) do
        local y=240+i*40
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
    -- 標題列在 y=85、分頁按鈕上緣在 y=121，中間放不下這行字，改放在分頁與底部按鈕之間。
    text(g,"目前："..player,250,742,16,CYAN)
    button(g,"登出",140,790,actions.logout,150); button(g,"主畫面",350,790,actions.back,170)
end
function AppView:showLoading(value) local g=self:_screen("請稍候"); text(g,value,250,350,21,BRIGHT) end
function AppView:showError(value,back)
    local g=self:_screen("發生錯誤"); text(g,value,250,330,20,{1,0.65,0.35}); button(g,"回到主畫面",250,500,back)
end
function AppView:showSettings(model,save,back,preview)
    -- 即時預覽：調整後立刻套用，但要按「儲存設定」才會寫入；取消或離開會被還原。
    local function apply(channel) if preview then preview(model,channel) end end
    local g=self:_screen("設定")
    local tracks=model.musicTracks or {}
    local selectedIndex=1
    for index,track in ipairs(tracks) do if track.id==model.backgroundTrack then selectedIndex=index end end
    local function selectedTrack() return tracks[selectedIndex] or {id="",name="預設音樂"} end
    if #tracks>0 and (not model.backgroundTrack or model.backgroundTrack=="") then model.backgroundTrack=selectedTrack().id end
    local musicLabel=text(g,"背景音樂："..selectedTrack().name,250,145,20,ACCENT)
    local function selectMusic(delta)
        if #tracks==0 then return end
        selectedIndex=((selectedIndex-1+delta)%#tracks)+1
        model.backgroundTrack=selectedTrack().id
        musicLabel.text="背景音樂："..selectedTrack().name
        apply("music")
    end
    button(g,"上一首",135,205,function() selectMusic(-1) end,150,46)
    button(g,"下一首",365,205,function() selectMusic(1) end,150,46)
    local backgroundLabel=text(g,"背景音量："..model.backgroundVolume.."%",250,270,21,BRIGHT)
    local background=widget.newSlider({x=250,y=320,width=360,value=model.backgroundVolume,
        listener=function(event) model.backgroundVolume=math.floor(event.value+0.5)
            backgroundLabel.text="背景音量："..model.backgroundVolume.."%"; apply("background") end})
    g:insert(background)
    local effectLabel=text(g,"消除 / Game Over 音量："..model.effectVolume.."%",250,395,21,BRIGHT)
    local effect=widget.newSlider({x=250,y=445,width=360,value=model.effectVolume,
        listener=function(event) model.effectVolume=math.floor(event.value+0.5)
            effectLabel.text="消除 / Game Over 音量："..model.effectVolume.."%"
            -- 拖曳過程只調音量，放開手指才試聽一次，避免連續播放。
            apply((event.phase==nil or event.phase=="ended") and "effect" or nil) end})
    g:insert(effect)
    text(g,"關卡種子",250,520,23,ACCENT)
    text(g,"相同種子會產生相同的方塊順序，\n適合和朋友挑戰同一局；留空就是一般隨機。",250,565,16,BRIGHT)
    local seed=native.newTextField(250,630,360,50); seed.placeholder="種子（可留空）"; seed.text=model.seed or ""
    self.fields={seed}
    button(g,"儲存設定",250,720,function() model.seed=seed.text; save(model) end)
    button(g,"取消",250,790,back,160,48)
end
return AppView
