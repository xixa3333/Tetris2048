-- Coordinates the one-time legacy-email migration without owning HTTP or UI.
-- New ID accounts are immutable; this service only transfers old accounts.
local AccountMigration={}; AccountMigration.__index=AccountMigration

function AccountMigration.new(auth,profile,globalBoard)
    return setmetatable({auth=auth,profile=profile,globalBoard=globalBoard},AccountMigration)
end

function AccountMigration:_rollback(context,message,callback)
    self.globalBoard:deleteCurrent(function()
        self.profile:deleteCurrent(function()
            self.auth:rollbackLegacyMigration(context,function()
                callback(false,message or "帳號轉換失敗，已恢復舊帳號")
            end)
        end)
    end)
end

function AccountMigration:migrate(account,password,callback)
    self.auth:beginLegacyMigration(account,password,function(ok,result)
        if not ok then callback(false,result); return end
        local context=result
        self.profile:save(context.oldUser.nickname,function(profileOk,profileMessage)
            if not profileOk then self:_rollback(context,profileMessage,callback); return end
            self.globalBoard:migrateFrom(context.oldUser,function(scoreOk,scoreMessage)
                if not scoreOk then self:_rollback(context,scoreMessage,callback); return end
                self.auth:commitLegacyMigration()
                callback(true,"帳號已轉換，之後請使用 ID 登入")
            end)
        end)
    end)
end

return AccountMigration
