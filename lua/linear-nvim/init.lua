local M = {}
local linear_client = require("linear-nvim.client")
local key_store = require("linear-nvim.key-store")
local utils = require("linear-nvim.utils")
local log = require("plenary.log")

--- @class LinearNvimOptions
--- @field issue_regex? string
--- @field issue_fields? string[]
--- @field default_label_ids? string[]
--- @field log_level? string
--- @field open_url_key? string
--- @field open_issue_browser? boolean

--- @type LinearNvimOptions
M.options = {
    issue_regex = "",
    issue_fields = {},
    default_label_ids = {},
}

--- @class LinearNvimIssueFields
M._issue_fields = {
    url = "Issue URL",
    branchName = "Branch Name",
    title = "Issue Title",
    identifier = "Issue Identifier",
    description = "Issue Description",
    id = "Issue ID",
}

--- @class LinearNvimOptions
local defaults = {
    issue_regex = "",
    issue_fields = {
        "url",
        "branchName",
        "title",
        "identifier",
        "description",
        "id",
    },
    default_label_ids = {},
    log_level = "warn",
    open_url_key = "<c-b>",
    open_issue_browser = false,
}

--- @param options? LinearNvimOptions
function M.setup(options)
    options = options or {}
    M.options = vim.tbl_deep_extend("force", defaults, options)
    utils.setup(M.options)
    M.client = linear_client:setup(
        key_store.fetch_api_key,
        M.options.issue_fields,
        M.options.default_label_ids
    )
    log.new({
        plugin = "linear-nvim",
        use_console = "async",
        level = M.options.log_level,
    }, true)
end

--- @param issues table
local function show_issues_picker(issues)
    -- Prepare entries for the picker from the issues map
    local entries = {}
    for display_key, data_bag in pairs(issues) do
        table.insert(entries, {
            value = data_bag.branch_name, -- This is what will be copied to the clipboard
            display = display_key, -- How the entry will be displayed
            ordinal = display_key, -- Used for sorting and searching
            description = data_bag.description, -- Additional information that can be displayed
            url = data_bag.url,
        })
    end

    utils.show_telescope_picker(entries, "Issues")
end

--- @param issue table
--- @param issue_fields string[]
local function show_create_issues_result_picker(issue, issue_fields)
    local entries = {}

    for _, key in ipairs(issue_fields) do
        if issue[key] then
            local issue_desc = issue[key]
            if issue[key] == vim.NIL or issue[key] == nil then
                issue_desc = "No data avaialble"
            end
            table.insert(entries, {
                value = issue_desc,
                display = "Copy " .. M._issue_fields[key],
                ordinal = "Copy " .. M._issue_fields[key],
                description = issue_desc,
            })
        end
    end

    utils.show_telescope_picker(entries, "Issue created")
end
-- create a setup command the user has to call to provide an api key to use
-- once this key is saved, we can then setup key commands to trigger fetching
-- issues from Linear and display them in something similar to neotree or neotest
-- i.e. a panel

function M.show_user_id()
    print(M.client:get_user_id())
end

function M.show_assigned_issues()
    local issues = M.client:get_assigned_issues()
    if not issues then
        log.warn("No issues found. Exiting...")
        return
    end

    local issue_titles = {}
    for _, issue in ipairs(issues) do
        local description = issue.description
        if description == vim.NIL or description == nil then
            description = "No description available"
        end
        issue_titles[issue.identifier .. " - " .. issue.title] = {
            branch_name = issue.branchName,
            description = description,
            url = issue.url,
        }
    end

    show_issues_picker(issue_titles)
end

--- @param team_id string?
--- @param callback function(label_ids: string[])
local function show_label_picker(team_id, callback)
    local labels = M.client:get_labels(nil)  -- Pass nil to get all labels
    if not labels or #labels == 0 then
        vim.notify("No labels found", vim.log.levels.WARN)
        callback({})
        return
    end
    
    local entries = {}
    for _, label in ipairs(labels) do
        table.insert(entries, {
            value = label.id,
            display = label.name,
            ordinal = label.name,
            label = label,
        })
    end
    
    utils.show_telescope_picker_multiselect(entries, "Select Labels", function(selected)
        local label_ids = {}
        for _, item in ipairs(selected) do
            table.insert(label_ids, item.value)
        end
        callback(label_ids)
    end)
end

function M.create_issue()
    local full_selection = utils.get_visual_selection()
    local title, description = full_selection:match("([^\n]*)\n(.*)")

    -- If there is no newline, the whole selection is the title
    if not title then
        title = full_selection
        description = ""
    end
    if title == "" then
        title = vim.fn.input("Enter the title of the issue: ")
    end
    if title == "" then
        log.warn("No title provided. Not creating an issue")
        return
    end
    M.client:create_issue(title, description, function(issue)
        if issue ~= nil then
            vim.notify("Issue created successfully", vim.log.levels.INFO)
            if M.options.open_issue_browser then
                log.debug("Opening in browser")
                -- Open the url in the browser
                utils.open_in_browser_raw(issue.url)
            else
                log.debug("Opening telescope picker")
                show_create_issues_result_picker(issue, M.options.issue_fields)
            end
        else
            vim.notify("Failed to create issue", vim.log.levels.ERROR)
        end
    end)
end

function M.create_issue_with_labels()
    local full_selection = utils.get_visual_selection()
    local title, description = full_selection:match("([^\n]*)\n(.*)")

    if not title then
        title = full_selection
        description = ""
    end
    if title == "" then
        title = vim.fn.input("Enter the title of the issue: ")
    end
    if title == "" then
        log.warn("No title provided. Not creating an issue")
        return
    end
    
    M.client:fetch_team_id(function(team_id)
        if not team_id then
            vim.notify("Failed to get team ID", vim.log.levels.ERROR)
            return
        end
        
        show_label_picker(team_id, function(label_ids)
            local original_labels = M.client._default_labels
            M.client._default_labels = label_ids
            
            M.client:create_issue(title, description, function(issue)
                M.client._default_labels = original_labels
                
                if issue ~= nil then
                    vim.notify("Issue created successfully", vim.log.levels.INFO)
                    if M.options.open_issue_browser then
                        utils.open_in_browser_raw(issue.url)
                    else
                        show_create_issues_result_picker(issue, M.options.issue_fields)
                    end
                else
                    vim.notify("Failed to create issue", vim.log.levels.ERROR)
                end
            end)
        end)
    end)
end

function M.show_issue_details()
    local issue_id = utils.get_current_word()
    if not M.options.issue_regex or M.options.issue_regex == "" then
        vim.notify("Issue regex not set", vim.log.levels.WARN)
        return
    end

    local parsed_issue_id = string.match(issue_id, M.options.issue_regex)
    if not parsed_issue_id then
        vim.notify("Not a valid issue ID: " .. issue_id, vim.log.levels.WARN)
        return
    end
    local issue = M.client:get_issue_details(parsed_issue_id)
    if issue == nil then
        return
    end
    show_create_issues_result_picker(issue, M.options.issue_fields)
end

function M.update_issue_labels()
    if not M.options.issue_regex or M.options.issue_regex == "" then
        vim.notify("Issue regex not set", vim.log.levels.WARN)
        return
    end
    
    local word = utils.get_current_word()
    local parsed_issue_id = string.match(word, M.options.issue_regex)
    if not parsed_issue_id then
        vim.notify("Not a valid issue ID: " .. word, vim.log.levels.WARN)
        return
    end
    
    local issue = M.client:get_issue_details(parsed_issue_id)
    if not issue then
        return
    end
    
    M.client:fetch_team_id(function(team_id)
        if not team_id then
            vim.notify("Failed to get team ID", vim.log.levels.ERROR)
            return
        end
        
        show_label_picker(team_id, function(label_ids)
            M.client:update_issue(issue.id, { labelIds = label_ids }, function(updated_issue)
                if updated_issue then
                    vim.notify("Issue labels updated successfully", vim.log.levels.INFO)
                else
                    vim.notify("Failed to update issue labels", vim.log.levels.ERROR)
                end
            end)
        end)
    end)
end

function M.search_and_update_issue_labels()
    local issues = M.client:get_assigned_issues()
    if not issues or #issues == 0 then
        vim.notify("No issues found", vim.log.levels.WARN)
        return
    end
    
    local entries = {}
    for _, issue in ipairs(issues) do
        local description = issue.description
        if description == vim.NIL or description == nil then
            description = "No description available"
        end
        table.insert(entries, {
            value = issue.id,
            display = issue.identifier .. " - " .. issue.title,
            ordinal = issue.identifier .. " - " .. issue.title,
            description = description,
            issue = issue,
        })
    end
    
    utils.show_telescope_picker_with_action(entries, "Select Issue to Update Labels", function(selected_issue)
        M.client:fetch_team_id(function(team_id)
            if not team_id then
                vim.notify("Failed to get team ID", vim.log.levels.ERROR)
                return
            end
            
            show_label_picker(team_id, function(label_ids)
                M.client:update_issue(selected_issue.value, { labelIds = label_ids }, function(updated_issue)
                    if updated_issue then
                        vim.notify("Issue labels updated successfully: " .. selected_issue.display, vim.log.levels.INFO)
                    else
                        vim.notify("Failed to update issue labels", vim.log.levels.ERROR)
                    end
                end)
            end)
        end)
    end)
end

function M.search_and_show_issue_details()
    local issues = M.client:get_assigned_issues()
    if not issues or #issues == 0 then
        vim.notify("No issues found", vim.log.levels.WARN)
        return
    end
    
    local entries = {}
    for _, issue in ipairs(issues) do
        local description = issue.description
        if description == vim.NIL or description == nil then
            description = "No description available"
        end
        table.insert(entries, {
            value = issue.id,
            display = issue.identifier .. " - " .. issue.title,
            ordinal = issue.identifier .. " - " .. issue.title,
            description = description,
            issue = issue,
        })
    end
    
    utils.show_telescope_picker_with_action(entries, "Select Issue to View Details", function(selected_issue)
        local issue = M.client:get_issue_details(selected_issue.value)
        if issue then
            local issue_view = require("linear-nvim.issue-view")
            issue_view.show_issue_in_buffer(issue, M.options)
        end
    end)
end

return M
