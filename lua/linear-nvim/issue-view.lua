local M = {}

--- @param issue table
--- @param options table
function M.show_issue_in_buffer(issue, options)
    -- Create a new buffer
    local buf = vim.api.nvim_create_buf(false, true)
    
    -- Set buffer options
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'linear-issue')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    
    -- Build the content
    local lines = {}
    local highlights = {}
    
    -- Title section
    table.insert(lines, "")
    table.insert(lines, "  " .. (issue.identifier or ""))
    table.insert(highlights, {line = #lines - 1, col_start = 2, col_end = 2 + #(issue.identifier or ""), hl_group = "Comment"})
    
    table.insert(lines, "")
    table.insert(lines, "  " .. (issue.title or "Untitled"))
    table.insert(highlights, {line = #lines - 1, col_start = 2, col_end = 2 + #(issue.title or ""), hl_group = "Title"})
    
    table.insert(lines, "")
    table.insert(lines, "  ───────────────────────────────────────────────────────────────────")
    table.insert(lines, "")
    
    -- Properties section
    table.insert(lines, "  Properties")
    table.insert(highlights, {line = #lines - 1, col_start = 2, col_end = 12, hl_group = "Special"})
    table.insert(lines, "")
    
    -- Status
    if issue.state and issue.state ~= vim.NIL and issue.state.name then
        table.insert(lines, "    Status:  " .. issue.state.name)
        table.insert(highlights, {line = #lines - 1, col_start = 4, col_end = 12, hl_group = "Label"})
    end
    
    -- Priority
    if issue.priority and issue.priority ~= vim.NIL then
        local priority_text = tostring(issue.priority)
        table.insert(lines, "    Priority:  " .. priority_text)
        table.insert(highlights, {line = #lines - 1, col_start = 4, col_end = 14, hl_group = "Label"})
    end
    
    -- Assignee
    if issue.assignee and issue.assignee ~= vim.NIL and issue.assignee.name then
        table.insert(lines, "    Assignee:  " .. issue.assignee.name)
        table.insert(highlights, {line = #lines - 1, col_start = 4, col_end = 14, hl_group = "Label"})
    end
    
    -- Labels
    if issue.labels and issue.labels ~= vim.NIL and issue.labels.nodes and #issue.labels.nodes > 0 then
        local label_names = {}
        for _, label in ipairs(issue.labels.nodes) do
            table.insert(label_names, label.name)
        end
        table.insert(lines, "    Labels:  " .. table.concat(label_names, ", "))
        table.insert(highlights, {line = #lines - 1, col_start = 4, col_end = 13, hl_group = "Label"})
    end
    
    -- Project
    if issue.project and issue.project ~= vim.NIL and type(issue.project) == "table" and issue.project.name then
        table.insert(lines, "    Project:  " .. issue.project.name)
        table.insert(highlights, {line = #lines - 1, col_start = 4, col_end = 13, hl_group = "Label"})
    end
    
    table.insert(lines, "")
    table.insert(lines, "  ───────────────────────────────────────────────────────────────────")
    table.insert(lines, "")
    
    -- Description section
    if issue.description and issue.description ~= vim.NIL and issue.description ~= "" then
        table.insert(lines, "  Description")
        table.insert(highlights, {line = #lines - 1, col_start = 2, col_end = 13, hl_group = "Special"})
        table.insert(lines, "")
        
        -- Split description by newlines and indent
        for desc_line in issue.description:gmatch("[^\r\n]+") do
            table.insert(lines, "    " .. desc_line)
        end
        
        table.insert(lines, "")
    end
    
    -- URL
    if issue.url then
        table.insert(lines, "  ───────────────────────────────────────────────────────────────────")
        table.insert(lines, "")
        table.insert(lines, "  URL:  " .. issue.url)
        table.insert(highlights, {line = #lines - 1, col_start = 2, col_end = 6, hl_group = "Label"})
        table.insert(highlights, {line = #lines - 1, col_start = 8, col_end = 8 + #issue.url, hl_group = "Underlined"})
    end
    
    table.insert(lines, "")
    table.insert(lines, "")
    table.insert(lines, "  Press 'q' to close | 'o' to open in browser | 'e' to edit labels")
    table.insert(highlights, {line = #lines - 1, col_start = 2, col_end = #lines[#lines], hl_group = "Comment"})
    
    -- Set buffer content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    
    -- Apply highlights
    local ns_id = vim.api.nvim_create_namespace('linear_issue_view')
    for _, hl in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(buf, ns_id, hl.hl_group, hl.line, hl.col_start, hl.col_end)
    end
    
    -- Make buffer read-only
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    
    -- Open in a split or current window
    local win_width = vim.api.nvim_get_option("columns")
    local win_height = vim.api.nvim_get_option("lines")
    
    -- Create a floating window
    local width = math.min(100, math.floor(win_width * 0.8))
    local height = math.min(40, math.floor(win_height * 0.8))
    
    local row = math.floor((win_height - height) / 2)
    local col = math.floor((win_width - width) / 2)
    
    local opts = {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
    }
    
    local win = vim.api.nvim_open_win(buf, true, opts)
    
    -- Set window options
    vim.api.nvim_win_set_option(win, 'cursorline', true)
    vim.api.nvim_win_set_option(win, 'wrap', true)
    
    -- Set up keymaps
    local function close_window()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end
    
    local function open_in_browser()
        if issue.url then
            local utils = require("linear-nvim.utils")
            utils.open_in_browser_raw(issue.url)
            close_window()
        end
    end
    
    local function edit_labels()
        close_window()
        -- Call the update labels function
        local linear_nvim = require("linear-nvim")
        local client = linear_nvim.client
        
        client:fetch_team_id(function(team_id)
            if not team_id then
                vim.notify("Failed to get team ID", vim.log.levels.ERROR)
                return
            end
            
            local show_label_picker = function(callback)
                local labels = client:get_labels(nil)
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
                
                local utils = require("linear-nvim.utils")
                utils.show_telescope_picker_multiselect(entries, "Select Labels", function(selected)
                    local label_ids = {}
                    for _, item in ipairs(selected) do
                        table.insert(label_ids, item.value)
                    end
                    callback(label_ids)
                end)
            end
            
            show_label_picker(function(label_ids)
                client:update_issue(issue.id, { labelIds = label_ids }, function(updated_issue)
                    if updated_issue then
                        vim.notify("Issue labels updated successfully", vim.log.levels.INFO)
                        -- Refresh the view
                        M.show_issue_in_buffer(updated_issue, options)
                    else
                        vim.notify("Failed to update issue labels", vim.log.levels.ERROR)
                    end
                end)
            end)
        end)
    end
    
    vim.keymap.set('n', 'q', close_window, { buffer = buf, silent = true })
    vim.keymap.set('n', '<Esc>', close_window, { buffer = buf, silent = true })
    vim.keymap.set('n', 'o', open_in_browser, { buffer = buf, silent = true })
    vim.keymap.set('n', 'e', edit_labels, { buffer = buf, silent = true })
end

return M
