local M = {}

--- @param issue table
--- @param options table
function M.show_issue_in_buffer(issue, options)
    local buf = vim.api.nvim_create_buf(false, true)
    
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    
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
    local separator_line_1 = #lines
    table.insert(lines, "")
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
        local label_line = "    Labels:  "
        local line_start_col = #label_line
        
        for i, label in ipairs(issue.labels.nodes) do
            if i > 1 then
                label_line = label_line .. "  "
            end
            
            local color = label.color or "#808080"
            local hl_group = "LinearLabel_" .. color:gsub("#", "")
            
            vim.api.nvim_set_hl(0, hl_group, { fg = color })
            
            local dot_start = #label_line
            label_line = label_line .. "● " .. label.name
            local dot_end = dot_start + 1
            
            table.insert(highlights, {
                line = #lines,
                col_start = dot_start,
                col_end = dot_end,
                hl_group = hl_group
            })
        end
        
        table.insert(lines, label_line)
        table.insert(highlights, {line = #lines - 1, col_start = 4, col_end = 13, hl_group = "Label"})
    end
    
    -- Project
    if issue.project and issue.project ~= vim.NIL and type(issue.project) == "table" and issue.project.name then
        table.insert(lines, "    Project:  " .. issue.project.name)
        table.insert(highlights, {line = #lines - 1, col_start = 4, col_end = 13, hl_group = "Label"})
    end
    
    table.insert(lines, "")
    local separator_line_2 = #lines
    table.insert(lines, "")
    table.insert(lines, "")
    
    -- Description section
    local desc_start_line = nil
    if issue.description and issue.description ~= vim.NIL and issue.description ~= "" then
        table.insert(lines, "  Description")
        table.insert(highlights, {line = #lines - 1, col_start = 2, col_end = 13, hl_group = "Special"})
        table.insert(lines, "")
        
        desc_start_line = #lines
        
        for desc_line in issue.description:gmatch("[^\r\n]+") do
            local indented_line = "    " .. desc_line
            table.insert(lines, indented_line)
        end
        
        table.insert(lines, "")
    end
    
    if issue.url then
        table.insert(lines, "  ───────────────────────────────────────────────────────────────────")
        table.insert(lines, "")
        table.insert(lines, "  URL:  " .. issue.url)
        table.insert(highlights, {line = #lines - 1, col_start = 2, col_end = 6, hl_group = "Label"})
        table.insert(highlights, {line = #lines - 1, col_start = 8, col_end = 8 + #issue.url, hl_group = "Underlined"})
    end
    
    table.insert(lines, "")
    table.insert(lines, "")
    table.insert(lines, "  Press 'q' to close | 'o' to open in browser | 'e' to edit description")
    table.insert(highlights, {line = #lines - 1, col_start = 2, col_end = #lines[#lines], hl_group = "Comment"})
    
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    
    local ns_id = vim.api.nvim_create_namespace('linear_issue_view')
    for _, hl in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(buf, ns_id, hl.hl_group, hl.line, hl.col_start, hl.col_end)
    end
    
    if desc_start_line then
        local has_obsidian_ui, obsidian_ui = pcall(require, "obsidian.ui")
        local has_obsidian, obsidian = pcall(require, "obsidian")
        
        if has_obsidian_ui and has_obsidian and obsidian.get_client then
            local client = obsidian.get_client()
            if client and client.opts and client.opts.ui and client.opts.ui.enable then
                vim.schedule(function()
                    if vim.api.nvim_buf_is_valid(buf) then
                        obsidian_ui.update(client.opts.ui, buf)
                    end
                end)
            else
                setup_markdown_ui(buf)
            end
        else
            setup_markdown_ui(buf)
        end
    end
    
    -- Make buffer read-only
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    
    -- Function to update separator lines based on window width
    local function update_separators(win_width)
        local width = math.min(100, math.floor(win_width * 0.8))
        local separator = "  " .. string.rep("─", width - 4)
        
        vim.api.nvim_buf_set_option(buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(buf, separator_line_1, separator_line_1 + 1, false, {separator})
        vim.api.nvim_buf_set_lines(buf, separator_line_2, separator_line_2 + 1, false, {separator})
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    end
    
    -- Function to calculate window size and position
    local function get_window_config()
        local win_width = vim.api.nvim_get_option("columns")
        local win_height = vim.api.nvim_get_option("lines")
        
        local width = math.min(100, math.floor(win_width * 0.8))
        
        update_separators(win_width)
        
        local content_height = #lines
        local max_height = math.floor(win_height * 0.8)
        local height = math.min(content_height + 2, max_height)
        
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
    
    -- Set up autocmd for VimResized event and window leave
    local resize_group = vim.api.nvim_create_augroup('LinearIssueViewResize', { clear = true })
    vim.api.nvim_create_autocmd('VimResized', {
        group = resize_group,
        buffer = buf,
        callback = resize_window,
    })
    
    vim.api.nvim_create_autocmd('WinLeave', {
        group = resize_group,
        buffer = buf,
        callback = function()
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
        end,
    })
    
    vim.api.nvim_win_set_option(win, 'cursorline', true)
    vim.api.nvim_win_set_option(win, 'wrap', true)
    vim.api.nvim_win_set_option(win, 'breakindent', true)
    vim.api.nvim_win_set_option(win, 'breakindentopt', 'shift:0')
    vim.api.nvim_win_set_option(win, 'linebreak', true)
    vim.api.nvim_win_set_option(win, 'conceallevel', 2)
    vim.api.nvim_win_set_option(win, 'concealcursor', 'nc')
    
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
    
    local function setup_markdown_ui(buf)
        local ns_id = vim.api.nvim_create_namespace('linear_markdown_ui')
        
        local hl_groups = {
            LinearMdTodo = { bold = true, fg = "#f78c6c" },
            LinearMdDone = { bold = true, fg = "#89ddff" },
            LinearMdBullet = { bold = true, fg = "#89ddff" },
            LinearMdImportant = { bold = true, fg = "#d73128" },
        }
        
        for name, opts in pairs(hl_groups) do
            vim.api.nvim_set_hl(0, name, opts)
        end
        
        local function render_markdown()
            vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
            
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            
            for i, line in ipairs(lines) do
                local line_num = i - 1
                
                local unchecked = line:find("%- %[ %]")
                if unchecked then
                    vim.api.nvim_buf_set_extmark(buf, ns_id, line_num, unchecked - 1, {
                        end_col = unchecked + 4,
                        virt_text = {{"□ ", "LinearMdTodo"}},
                        virt_text_pos = "overlay",
                        hl_mode = "combine",
                    })
                end
                
                local checked = line:find("%- %[x%]") or line:find("%- %[X%]")
                if checked then
                    vim.api.nvim_buf_set_extmark(buf, ns_id, line_num, checked - 1, {
                        end_col = checked + 4,
                        virt_text = {{"✔ ", "LinearMdDone"}},
                        virt_text_pos = "overlay",
                        hl_mode = "combine",
                    })
                end
                
                local bullet_dash = line:match("^(%s*)%- ")
                if bullet_dash and not line:find("%- %[") then
                    local indent = #bullet_dash
                    local dash_pos = line:find("%-")
                    if dash_pos then
                        vim.api.nvim_buf_set_extmark(buf, ns_id, line_num, dash_pos - 1, {
                            end_col = dash_pos,
                            virt_text = {{"•", "LinearMdBullet"}},
                            virt_text_pos = "overlay",
                            hl_mode = "combine",
                        })
                    end
                end
                
                local bullet_star = line:match("^(%s*)%* ")
                if bullet_star and not line:find("%* %[") then
                    local indent = #bullet_star
                    local star_pos = line:find("%*")
                    if star_pos then
                        vim.api.nvim_buf_set_extmark(buf, ns_id, line_num, star_pos - 1, {
                            end_col = star_pos,
                            virt_text = {{"•", "LinearMdBullet"}},
                            virt_text_pos = "overlay",
                            hl_mode = "combine",
                        })
                    end
                end
            end
        end
        
        render_markdown()
        
        vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
            buffer = buf,
            callback = function()
                render_markdown()
            end,
        })
    end
    
    local function edit_description()
        local log = require("plenary.log")
        log.debug("Issue object: " .. vim.inspect(issue))
        
        local issue_id = issue.id
        log.debug("Issue ID: " .. tostring(issue_id))
        
        if not issue_id or issue_id == vim.NIL then
            vim.notify("Error: Issue ID not found. Keys: " .. vim.inspect(vim.tbl_keys(issue)), vim.log.levels.ERROR)
            return
        end
        
        close_window()
        
        local tmp_file = vim.fn.tempname() .. '.md'
        
        local current_desc = issue.description or ""
        if current_desc == vim.NIL then
            current_desc = ""
        end
        
        local lines_to_write = vim.split(current_desc, '\n', { plain = true })
        vim.fn.writefile(lines_to_write, tmp_file)
        
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) then
                local buf_name = vim.api.nvim_buf_get_name(buf)
                if buf_name == tmp_file then
                    vim.api.nvim_buf_delete(buf, { force = true })
                end
            end
        end
        
        local edit_buf = vim.api.nvim_create_buf(false, false)
        vim.api.nvim_buf_set_option(edit_buf, 'buftype', '')
        vim.api.nvim_buf_set_option(edit_buf, 'filetype', 'markdown')
        vim.api.nvim_buf_set_option(edit_buf, 'bufhidden', 'wipe')
        vim.api.nvim_buf_set_name(edit_buf, tmp_file)
        
        vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, lines_to_write)
        vim.api.nvim_buf_set_option(edit_buf, 'modified', false)
        
        local has_obsidian_ui, obsidian_ui = pcall(require, "obsidian.ui")
        local has_obsidian, obsidian = pcall(require, "obsidian")
        
        if has_obsidian_ui and has_obsidian and obsidian.get_client then
            local client = obsidian.get_client()
            if client and client.opts and client.opts.ui and client.opts.ui.enable then
                vim.schedule(function()
                    obsidian_ui.update(client.opts.ui, edit_buf)
                end)
                
                vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
                    buffer = edit_buf,
                    callback = function()
                        obsidian_ui.update(client.opts.ui, edit_buf)
                    end,
                })
            else
                setup_markdown_ui(edit_buf)
            end
        else
            setup_markdown_ui(edit_buf)
        end
        
        local win_width = vim.api.nvim_get_option("columns")
        local win_height = vim.api.nvim_get_option("lines")
        local width = math.min(100, math.floor(win_width * 0.8))
        local height = math.min(30, math.floor(win_height * 0.8))
        local row = math.floor((win_height - height) / 2)
        local col = math.floor((win_width - width) / 2)
        
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
        
        local edit_group = vim.api.nvim_create_augroup('LinearIssueDescEdit', { clear = true })
        vim.api.nvim_create_autocmd('BufWritePost', {
            group = edit_group,
            buffer = edit_buf,
            callback = function()
                local updated_lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
                local updated_desc = table.concat(updated_lines, '\n')
                
                local linear_nvim = require("linear-nvim")
                local client = linear_nvim.client
                
                client:update_issue(issue_id, { description = updated_desc }, function(updated_issue)
                    if updated_issue then
                        vim.notify("Issue synced to Linear", vim.log.levels.INFO)
                    else
                        vim.notify("Failed to sync to Linear", vim.log.levels.ERROR)
                    end
                end)
            end,
        })
        
        -- Set up a custom quit command that saves, closes, and reopens issue view
        local function safe_quit()
            local updated_lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
            local updated_desc = table.concat(updated_lines, '\n')
            
            vim.fn.writefile(updated_lines, tmp_file)
            
            if vim.api.nvim_win_is_valid(float_win) then
                vim.api.nvim_win_close(float_win, true)
            end
            
            if vim.api.nvim_buf_is_valid(edit_buf) then
                vim.api.nvim_buf_delete(edit_buf, { force = true })
            end
            
            vim.fn.delete(tmp_file)
            
            local linear_nvim = require("linear-nvim")
            local client = linear_nvim.client
            
            client:update_issue(issue_id, { description = updated_desc }, function(updated_issue)
                if updated_issue then
                    vim.notify("Issue description saved", vim.log.levels.INFO)
                    vim.schedule(function()
                        M.show_issue_in_buffer(updated_issue, options)
                    end)
                else
                    vim.notify("Failed to save issue description", vim.log.levels.ERROR)
                end
            end)
        end
        
        vim.keymap.set('n', 'q', safe_quit, { buffer = edit_buf, silent = true })
        
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
        
        vim.notify("Editing description - :w to save, 'q' to close", vim.log.levels.INFO)
    end
    
    local function edit_labels()
        close_window()
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
