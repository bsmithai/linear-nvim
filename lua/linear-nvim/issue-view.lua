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
        
        -- Parse and render markdown with virtual text replacements
        for desc_line in issue.description:gmatch("[^\r\n]+") do
            local line_start = #lines
            local rendered_line = desc_line
            
            -- Replace checkbox syntax with pretty characters
            rendered_line = rendered_line:gsub("%- %[X%]", "- ✔")
            rendered_line = rendered_line:gsub("%- %[x%]", "- ✔")
            rendered_line = rendered_line:gsub("%- %[ %]", "- □")
            
            -- Replace bullet points with prettier bullets
            rendered_line = rendered_line:gsub("^%s*%-%s", function(match)
                return match:gsub("%-", "•")
            end)
            rendered_line = rendered_line:gsub("^%s*%*%s", function(match)
                return match:gsub("%*", "•")
            end)
            
            local indented_line = "    " .. rendered_line
            table.insert(lines, indented_line)
            
            -- Highlight markdown headers (###, ##, #)
            if desc_line:match("^###%s") then
                table.insert(highlights, {line = line_start, col_start = 4, col_end = 7, hl_group = "Comment"})
                table.insert(highlights, {line = line_start, col_start = 8, col_end = #indented_line, hl_group = "Title"})
            elseif desc_line:match("^##%s") then
                table.insert(highlights, {line = line_start, col_start = 4, col_end = 6, hl_group = "Comment"})
                table.insert(highlights, {line = line_start, col_start = 7, col_end = #indented_line, hl_group = "Title"})
            elseif desc_line:match("^#%s") then
                table.insert(highlights, {line = line_start, col_start = 4, col_end = 5, hl_group = "Comment"})
                table.insert(highlights, {line = line_start, col_start = 6, col_end = #indented_line, hl_group = "Title"})
            end
            
            -- Highlight checkboxes
            if rendered_line:match("✔") then
                local checkbox_pos = rendered_line:find("✔")
                if checkbox_pos then
                    table.insert(highlights, {line = line_start, col_start = 4 + checkbox_pos - 1, col_end = 4 + checkbox_pos + 2, hl_group = "String"})
                end
            end
            if rendered_line:match("□") then
                local checkbox_pos = rendered_line:find("□")
                if checkbox_pos then
                    table.insert(highlights, {line = line_start, col_start = 4 + checkbox_pos - 1, col_end = 4 + checkbox_pos + 2, hl_group = "Comment"})
                end
            end
            
            -- Highlight bullet points
            if rendered_line:match("^%s*•%s") then
                local bullet_pos = rendered_line:find("•")
                if bullet_pos then
                    table.insert(highlights, {line = line_start, col_start = 4 + bullet_pos - 1, col_end = 4 + bullet_pos + 2, hl_group = "Special"})
                end
            end
            
            -- Highlight bold (**text**) - remove the ** and highlight the text
            local bold_start = rendered_line:find("%*%*")
            while bold_start do
                local bold_end = rendered_line:find("%*%*", bold_start + 2)
                if bold_end then
                    local before = rendered_line:sub(1, bold_start - 1)
                    local bold_text = rendered_line:sub(bold_start + 2, bold_end - 1)
                    local after = rendered_line:sub(bold_end + 2)
                    rendered_line = before .. bold_text .. after
                    
                    -- Update the line in the buffer
                    lines[#lines] = "    " .. rendered_line
                    indented_line = lines[#lines]
                    
                    -- Add highlight for the bold text
                    table.insert(highlights, {line = line_start, col_start = 4 + #before, col_end = 4 + #before + #bold_text, hl_group = "Bold"})
                    
                    bold_start = rendered_line:find("%*%*")
                else
                    break
                end
            end
            
            -- Highlight code blocks (`code`)
            for code_text in rendered_line:gmatch("`([^`]+)`") do
                local start_pos = rendered_line:find("`" .. code_text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1") .. "`")
                if start_pos then
                    table.insert(highlights, {line = line_start, col_start = 4 + start_pos - 1, col_end = 4 + start_pos + #code_text + 1, hl_group = "String"})
                end
            end
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
    table.insert(lines, "  Press 'q' to close | 'o' to open in browser | 'e' to edit description | 'l' to edit labels")
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
    
    -- Function to calculate window size and position
    local function get_window_config()
        local win_width = vim.api.nvim_get_option("columns")
        local win_height = vim.api.nvim_get_option("lines")
        
        local width = math.min(100, math.floor(win_width * 0.8))
        
        -- Calculate height based on content, with max limits
        local content_height = #lines
        local max_height = math.floor(win_height * 0.8)
        local height = math.min(content_height + 2, max_height) -- +2 for border
        
        local row = math.floor((win_height - height) / 2)
        local col = math.floor((win_width - width) / 2)
        
        return {
            relative = 'editor',
            width = width,
            height = height,
            row = row,
            col = col,
            style = 'minimal',
            border = 'rounded',
        }
    end
    
    -- Create a floating window
    local win = vim.api.nvim_open_win(buf, true, get_window_config())
    
    -- Handle window resize
    local function resize_window()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_set_config(win, get_window_config())
        end
    end
    
    -- Set up autocmd for VimResized event
    local resize_group = vim.api.nvim_create_augroup('LinearIssueViewResize', { clear = true })
    vim.api.nvim_create_autocmd('VimResized', {
        group = resize_group,
        buffer = buf,
        callback = resize_window,
    })
    
    -- Set window options
    vim.api.nvim_win_set_option(win, 'cursorline', true)
    vim.api.nvim_win_set_option(win, 'wrap', true)
    vim.api.nvim_win_set_option(win, 'breakindent', true)
    vim.api.nvim_win_set_option(win, 'breakindentopt', 'shift:0')
    vim.api.nvim_win_set_option(win, 'linebreak', true)
    
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
    
    local function edit_description()
        -- Capture the issue ID BEFORE closing
        local log = require("plenary.log")
        log.debug("Issue object: " .. vim.inspect(issue))
        
        local issue_id = issue.id
        log.debug("Issue ID: " .. tostring(issue_id))
        
        if not issue_id or issue_id == vim.NIL then
            vim.notify("Error: Issue ID not found. Keys: " .. vim.inspect(vim.tbl_keys(issue)), vim.log.levels.ERROR)
            return
        end
        
        close_window()
        
        -- Create a temporary markdown file
        local tmp_file = vim.fn.tempname() .. '.md'
        
        -- Write current description to temp file
        local current_desc = issue.description or ""
        if current_desc == vim.NIL then
            current_desc = ""
        end
        
        local lines_to_write = vim.split(current_desc, '\n', { plain = true })
        vim.fn.writefile(lines_to_write, tmp_file)
        
        -- Check if there's already a buffer for this temp file and delete it
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) then
                local buf_name = vim.api.nvim_buf_get_name(buf)
                if buf_name == tmp_file then
                    vim.api.nvim_buf_delete(buf, { force = true })
                end
            end
        end
        
        -- Create a buffer for editing
        local edit_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(edit_buf, 'buftype', 'acwrite')
        vim.api.nvim_buf_set_option(edit_buf, 'filetype', 'markdown')
        vim.api.nvim_buf_set_option(edit_buf, 'bufhidden', 'wipe')
        vim.api.nvim_buf_set_name(edit_buf, 'Linear: Edit Description')
        
        -- Set the buffer content
        vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, lines_to_write)
        vim.api.nvim_buf_set_option(edit_buf, 'modified', false)
        
        -- Calculate floating window size
        local win_width = vim.api.nvim_get_option("columns")
        local win_height = vim.api.nvim_get_option("lines")
        local width = math.min(100, math.floor(win_width * 0.8))
        local height = math.min(30, math.floor(win_height * 0.8))
        local row = math.floor((win_height - height) / 2)
        local col = math.floor((win_width - width) / 2)
        
        -- Open in a floating window
        local float_win = vim.api.nvim_open_win(edit_buf, true, {
            relative = 'editor',
            width = width,
            height = height,
            row = row,
            col = col,
            style = 'minimal',
            border = 'rounded',
            title = ' Edit Description ',
            title_pos = 'center',
        })
        
        vim.api.nvim_win_set_option(float_win, 'wrap', true)
        vim.api.nvim_win_set_option(float_win, 'linebreak', true)
        
        -- Set up autocmd to save on buffer write and update issue
        local edit_group = vim.api.nvim_create_augroup('LinearIssueDescEdit', { clear = true })
        vim.api.nvim_create_autocmd('BufWriteCmd', {
            group = edit_group,
            buffer = edit_buf,
            callback = function()
                -- Read the updated description
                local updated_lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
                local updated_desc = table.concat(updated_lines, '\n')
                
                -- Write to temp file
                vim.fn.writefile(updated_lines, tmp_file)
                
                -- Update the issue
                local linear_nvim = require("linear-nvim")
                local client = linear_nvim.client
                
                client:update_issue(issue_id, { description = updated_desc }, function(updated_issue)
                    if updated_issue then
                        vim.notify("Issue description updated successfully", vim.log.levels.INFO)
                        -- Mark buffer as saved
                        vim.api.nvim_buf_set_option(edit_buf, 'modified', false)
                    else
                        vim.notify("Failed to update issue description", vim.log.levels.ERROR)
                    end
                end)
            end,
        })
        
        -- Set up a custom quit command that closes the floating window
        local function safe_quit()
            -- Close the floating window
            if vim.api.nvim_win_is_valid(float_win) then
                vim.api.nvim_win_close(float_win, true)
            end
            -- Delete the buffer
            if vim.api.nvim_buf_is_valid(edit_buf) then
                vim.api.nvim_buf_delete(edit_buf, { force = true })
            end
            -- Clean up temp file
            vim.fn.delete(tmp_file)
        end
        
        -- Map q and <Esc> to close
        vim.keymap.set('n', 'q', safe_quit, { buffer = edit_buf, silent = true })
        vim.keymap.set('n', '<Esc>', safe_quit, { buffer = edit_buf, silent = true })
        
        -- Also clean up on window close
        vim.api.nvim_create_autocmd('WinClosed', {
            group = edit_group,
            pattern = tostring(float_win),
            callback = function()
                vim.fn.delete(tmp_file)
                if vim.api.nvim_buf_is_valid(edit_buf) then
                    vim.api.nvim_buf_delete(edit_buf, { force = true })
                end
            end,
        })
        
        -- Add instruction at the bottom
        vim.notify("Editing description - :w to save, 'q' to close", vim.log.levels.INFO)
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
    vim.keymap.set('n', 'e', edit_description, { buffer = buf, silent = true })
    vim.keymap.set('n', 'l', edit_labels, { buffer = buf, silent = true })
end

return M
