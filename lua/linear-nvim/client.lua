--- @class LinearClient
--- @field callback_for_api_key function
local LinearClient = {}
local curl = require("plenary.curl")
local log = require("plenary.log")
local utils = require("linear-nvim.utils")

API_URL = "https://api.linear.app/graphql"
LinearClient._api_key = ""
LinearClient._team_id = ""
LinearClient.callback_for_api_key = nil
LinearClient._issue_fields = nil
LinearClient._default_labels = {}

--- @param api_key string
--- @param query string
--- @return table?
LinearClient._make_query = function(api_key, query)
    local headers = {
        ["Authorization"] = api_key,
        ["Content-Type"] = "application/json",
    }

    local resp = curl.post(API_URL, {
        body = query,
        headers = headers,
        decoded = true,
    })

    if resp.status ~= 200 then
        log.error(
            string.format(
                "Failed to fetch data: HTTP status %s, Response body: %s",
                resp.status,
                resp.body
            )
        )
        return nil
    end

    local body_type = type(resp.body)
    if body_type ~= "string" then
        log.error(string.format("Response body is %s, not string. Body: %s", body_type, vim.inspect(resp.body)))
        return nil
    end

    local ok, data = pcall(vim.json.decode, resp.body)
    if not ok then
        log.error(string.format("Failed to decode JSON: %s. Body: %s", data, resp.body))
        return nil
    end
    
    local data_type = type(data)
    if data_type ~= "table" then
        log.error(string.format("Decoded data is %s, not table. Data: %s", data_type, vim.inspect(data)))
        return nil
    end
    
    if data.errors then
        log.error(string.format("GraphQL errors: %s", vim.inspect(data.errors)))
        vim.notify("Linear API error: " .. (data.errors[1].message or "Unknown error"), vim.log.levels.ERROR)
        return nil
    end
    
    return data
end

--- @param data table
--- @return boolean
LinearClient._get_hasNextPage = function(data)
    if data.pageInfo then
        return data.pageInfo.hasNextPage
    end
    return false
end

--- @param data table
--- @return string
LinearClient._get_endCursor = function(data)
    if data.pageInfo then
        return data.pageInfo.endCursor
    end
    return ""
end

--- @param callback_for_api_key function
--- @param issue_fields string[]
--- @param default_labels? string[]
--- @return LinearClient
function LinearClient:setup(callback_for_api_key, issue_fields, default_labels)
    self.callback_for_api_key = callback_for_api_key
    self._issue_fields = issue_fields
    self._default_labels = default_labels or {}

    return self
end

--- @return string
function LinearClient:fetch_api_key()
    if
        (not self._api_key or self._api_key == "") and self.callback_for_api_key
    then
        local api_key = self.callback_for_api_key()
        if api_key ~= nil and api_key ~= "" then
            self._api_key = api_key
        else
            log.error("API key not set.")
        end
    end
    return self._api_key
end

--- @param callback function
function LinearClient:fetch_team_id(callback)
    if self._team_id and self._team_id ~= "" then
        callback(self._team_id)
        return
    end

    local teams = self:get_teams()
    if teams == nil then
        vim.notify("No teams found.", vim.log.levels.ERROR)
        log.error("No teams found.", vim.log.levels.ERROR)
        callback(nil)
        return
    end

    if #teams == 1 then
        self._team_id = teams[1].id
        log.info(
            "Only one team found, using team "
                .. teams[1].name
                .. " automatically.",
            vim.log.levels.INFO
        )
        callback(self._team_id)
        return
    end

    local team_options = {}
    for _, team in ipairs(teams) do
        table.insert(team_options, { text = team.name, id = team.id })
    end

    vim.ui.select(team_options, {
        prompt = "Select a team:",
        format_item = function(item)
            return item.text
        end,
    }, function(choice)
        if choice then
            self._team_id = choice.id
            vim.notify(
                "Selected team " .. choice.text .. " saved successfully!",
                vim.log.levels.INFO
            )
            log.info(
                "Selected team " .. choice.text .. " saved successfully!",
                vim.log.levels.INFO
            )
            callback(self._team_id)
        else
            vim.notify("Team selection cancelled.", vim.log.levels.WARN)
            log.warn("Team selection cancelled.")
            callback(nil)
        end
    end)
end

--- @return string?
function LinearClient:get_user_id()
    local query = '{ "query": "{ viewer { id name } }" }'
    local data = self._make_query(self:fetch_api_key(), query)
    if data and data.data and data.data.viewer and data.data.viewer.id then
        return data.data.viewer.id
    else
        log.error("User ID not found in response")
        return nil
    end
end

--- @return table?
function LinearClient:get_assigned_issues()
    local query = string.format(
        '{"query": "query { user(id: \\"%s\\") { id name assignedIssues(filter: {state: {type: {nin: [\\"completed\\", \\"canceled\\"]}}}) { nodes { id title identifier branchName description url } } } }"}',
        self:get_user_id()
    )
    local data = self._make_query(self:fetch_api_key(), query)

    if
        data
        and data.data
        and data.data.user
        and data.data.user.assignedIssues
    then
        return data.data.user.assignedIssues.nodes
    else
        log.error("Assigned issues not found in response")
        return nil
    end
end

--- @return table?
function LinearClient:get_teams()
    --- @param cursor string?
    local function create_query(cursor)
        local template =
            "query { teams(first: 50%s) { nodes {id name}, pageInfo {hasNextPage endCursor}}}"

        -- Add the after parameter only if cursor is provided
        local after_param = cursor and (', after: \\"' .. cursor .. '\\"') or ""

        -- Format the complete query string
        return string.format(
            '{"query":"%s"}',
            string.format(template, after_param)
        )
    end

    local api_key = self:fetch_api_key()
    local teams = {}
    local endCursor = ""
    local hasNextPage = true

    -- Use initial query with no cursor
    while hasNextPage do
        local query_string = create_query(endCursor ~= "" and endCursor or nil)
        local data = self._make_query(api_key, query_string)

        if data and data.data and data.data.teams then
            if data.data.teams.nodes then
                for _, team in ipairs(data.data.teams.nodes) do
                    table.insert(teams, team)
                end
            end

            hasNextPage = self._get_hasNextPage(data.data.teams)
            endCursor = self._get_endCursor(data.data.teams)
        else
            if #teams == 0 then
                log.error("No teams found")
                return nil
            end
            break
        end
    end
    return teams
end

--- @param team_id string?
--- @return table?
function LinearClient:get_labels(team_id)
    local query
    if team_id then
        query = string.format(
            '{"query":"query { issueLabels(filter: { team: { id: { eq: \\"%s\\" }}}) { nodes { id name color }}}"}',
            team_id
        )
    else
        -- Fetch all labels across all teams
        query = '{"query":"query { issueLabels { nodes { id name color }}}"}'
    end
    
    local data = self._make_query(self:fetch_api_key(), query)
    
    if not data or not data.data or not data.data.issueLabels or not data.data.issueLabels.nodes then
        log.error("Failed to fetch labels")
        return nil
    end
    
    return data.data.issueLabels.nodes
end

--- @param team_id string
--- @param label_names string[]
--- @return string[]
function LinearClient:get_label_ids_by_names(team_id, label_names)
    if #label_names == 0 then
        return {}
    end
    
    local labels = self:get_labels(team_id)
    if not labels then
        return {}
    end
    
    local label_map = {}
    for _, label in ipairs(labels) do
        label_map[label.name] = label.id
    end
    
    local label_ids = {}
    for _, name in ipairs(label_names) do
        if label_map[name] then
            table.insert(label_ids, label_map[name])
        else
            log.warn(string.format("Label '%s' not found in team", name))
        end
    end
    
    return label_ids
end

--- @param labels string[]
--- @return string
local function convertDefaultLabelsToGQLArray(labels)
    local labelArray = {}
    for _, label in ipairs(labels) do
        table.insert(labelArray, string.format('\\"%s\\"', label))
    end
    return string.format("[%s]", table.concat(labelArray, ","))
end

--- @param title string
--- @param description string
--- @param callback function(issue: table?)
function LinearClient:create_issue(title, description, callback)
    local parsed_title = utils.escape_json_string(title)
    local issue_fields_query = table.concat(self._issue_fields, " ")
    local user_id = self:get_user_id()

    if not user_id then
        vim.notify("Failed to get user ID", vim.log.levels.ERROR)
        callback(nil)
        return
    end

    self:fetch_team_id(function(team_id)
        if not team_id then
            vim.notify("Failed to get team ID", vim.log.levels.ERROR)
            callback(nil)
            return
        end

        local label_ids = self:get_label_ids_by_names(team_id, self._default_labels)
        local labels_to_attach = convertDefaultLabelsToGQLArray(label_ids)

        local query = string.format(
            '{"query": "mutation IssueCreate { issueCreate(input: {title: \\"%s\\" teamId: \\"%s\\" assigneeId: \\"%s\\" labelIds: %s}) { success issue { %s } } }"}',
            parsed_title,
            team_id,
            user_id,
            labels_to_attach,
            issue_fields_query
        )

        local data = self._make_query(self:fetch_api_key(), query)
        
        print(string.format("[DEBUG] create_issue received data of type: %s", type(data)))
        if data then
            print(string.format("[DEBUG] data.data is of type: %s", type(data.data)))
        end

        if
            data
            and data.data
            and data.data.issueCreate
            and data.data.issueCreate.success
            and data.data.issueCreate.success == true
            and data.data.issueCreate.issue
        then
            callback(data.data.issueCreate.issue)
        else
            vim.notify("Issue not found in response", vim.log.levels.ERROR)
            callback(nil)
        end
    end)
end

--- @param issue_id string
--- @return table?
function LinearClient:get_issue_details(issue_id)
    local issue_fields_query = table.concat(self._issue_fields, " ")
    local query = string.format(
        '{"query":"query { issue(id: \\"%s\\") { id identifier %s state { id name } assignee { id name } labels { nodes { id name color }} project { id name } }}"}',
        issue_id,
        issue_fields_query
    )

    local data = self._make_query(self:fetch_api_key(), query)

    if data and data.data and data.data.issue then
        return data.data.issue
    else
        vim.notify("Issue not found in response", vim.log.levels.ERROR)
        return nil
    end
end

--- @param issue_id string
--- @param updates table
--- @param callback function(issue: table?)
function LinearClient:update_issue(issue_id, updates, callback)
    local update_fields = {}
    
    if updates.title then
        local parsed_title = utils.escape_json_string(updates.title)
        table.insert(update_fields, string.format('title: \\"%s\\"', parsed_title))
    end
    
    if updates.description then
        local parsed_desc = updates.description
        parsed_desc = parsed_desc:gsub("\\", "\\\\\\\\") -- Escape backslashes (needs 4 for JSON in GraphQL)
        parsed_desc = parsed_desc:gsub('"', '\\\\\\"') -- Escape quotes
        parsed_desc = parsed_desc:gsub("\n", "\\\\n") -- Escape newlines
        parsed_desc = parsed_desc:gsub("\r", "\\\\r") -- Escape carriage returns
        parsed_desc = parsed_desc:gsub("\t", "\\\\t") -- Escape tabs
        table.insert(update_fields, string.format('description: \\"%s\\"', parsed_desc))
    end
    
    if updates.labelIds then
        local labels_array = convertDefaultLabelsToGQLArray(updates.labelIds)
        table.insert(update_fields, string.format('labelIds: %s', labels_array))
    end
    
    if #update_fields == 0 then
        vim.notify("No updates provided", vim.log.levels.WARN)
        callback(nil)
        return
    end
    
    local issue_fields_query = table.concat(self._issue_fields, " ")
    local updates_string = table.concat(update_fields, " ")
    
    local query = string.format(
        '{"query": "mutation IssueUpdate { issueUpdate(id: \\"%s\\" input: {%s}) { success issue { id %s state { id name } assignee { id name } labels { nodes { id name color }} project { id name } } } }"}',
        issue_id,
        updates_string,
        issue_fields_query
    )
    
    local data = self._make_query(self:fetch_api_key(), query)
    
    if not data then
        vim.notify("Failed to update issue - no response", vim.log.levels.ERROR)
        callback(nil)
        return
    end
    
    if data.errors then
        local error_msg = data.errors[1] and data.errors[1].message or "Unknown error"
        local error_details = ""
        if data.errors[1] and data.errors[1].extensions then
            error_details = vim.inspect(data.errors[1].extensions)
        end
        vim.notify("Failed to update issue: " .. error_msg, vim.log.levels.ERROR)
        log.error(string.format("GraphQL errors: %s", vim.inspect(data.errors)))
        log.error(string.format("Query was: %s", query:sub(1, 1000)))
        callback(nil)
        return
    end
    
    if
        data.data
        and data.data.issueUpdate
        and data.data.issueUpdate.success
        and data.data.issueUpdate.issue
    then
        callback(data.data.issueUpdate.issue)
    else
        vim.notify("Failed to update issue - unexpected response", vim.log.levels.ERROR)
        log.error(string.format("Unexpected response: %s", vim.inspect(data)))
        callback(nil)
    end
end

return LinearClient
