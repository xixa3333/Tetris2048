-- Centralized REST paths avoid client-specific parsing of parentheses in (default).
local FirestoreUrl={}

function FirestoreUrl.documents(projectId)
    assert(type(projectId)=="string" and projectId~="","projectId is required")
    return "https://firestore.googleapis.com/v1/projects/"..projectId..
        "/databases/%28default%29/documents"
end

return FirestoreUrl
