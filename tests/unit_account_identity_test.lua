local T=require("test_helper")
local AccountIdentity=require("account_identity")

T.test("Account IDs normalize and map to private Firebase transport addresses",function()
    local email,id=AccountIdentity.toEmail(" Player_01 ")
    T.equal(id,"player_01")
    T.equal(email,"player_01@users.tetris2048.app")
    T.equal(AccountIdentity.fromEmail(email),"player_01")
end)

T.test("Account ID validation rejects injection, email and boundary violations",function()
    local invalid={"ab","123456789012345678901","a@b.com","-player","玩家","a b","a/b"}
    for _,value in ipairs(invalid) do T.equal(AccountIdentity.validate(value),nil) end
    T.equal(AccountIdentity.validate("abc"),"abc")
    T.equal(AccountIdentity.validate("a-b.c_d"),"a-b.c_d")
end)

T.test("Legacy email accounts remain available for sign-in and password reset only",function()
    local email,account,legacy=AccountIdentity.forSignIn(" OLD@Example.com ")
    T.equal(email,"old@example.com"); T.equal(account,"old@example.com"); T.equal(legacy,true)
    T.equal(AccountIdentity.isLegacyEmail(email),true)
    T.equal(AccountIdentity.isLegacyEmail("new_id"),false)
end)
