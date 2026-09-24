module("luci.controller.netflow", package.seeall)

local sys = require "luci.sys"
local http = require "luci.http"
local uci = require "luci.model.uci".cursor()

local function call_backend_post(action, json_file_path)
    local port = uci:get("netflow", "config", "backend_port") or "9190"
    if not port:match("^%d+$") then port = "9190" end
    local url = string.format("http://127.0.0.1:%s/api/%s", port, action)
    local curl = string.format(
        "curl -sS --connect-timeout 8 --max-time 45 -X POST '%s' -H 'Content-Type: application/json' -d @%s 2>/dev/null",
        url, json_file_path
    )
    local out = sys.exec(curl)
    if out and out ~= "" then
        return out
    end
    local wget = string.format(
        "wget -qO- --timeout=50 --header='Content-Type: application/json' --post-file=%s '%s' 2>/dev/null",
        json_file_path, url
    )
    return sys.exec(wget) or ""
end

function index()
    entry({"admin", "services", "netflow"}, template("netflow/main"), _("M78加速器"), 80)
    entry({"admin", "services", "netflow", "api"}, call("action_api"), nil)
    entry({"admin", "services", "netflow", "upload_core"}, call("action_upload_core"), nil)
end

function action_api()
    local action = http.formvalue("action") or ""

    if not action:match("^[%w_]+$") then
        http.prepare_content("application/json")
        http.write('{"status":"error","message":"invalid action"}')
        return
    end

    local function urldecode(s)
        if not s then return s end
        s = s:gsub('+', ' ')
        s = s:gsub('%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
        return s
    end

    local params = {}
    local known_keys = {
        "email", "password", "group", "node", "mode", "state", "run_mode", "source"
    }
    for _, key in ipairs(known_keys) do
        local val = http.formvalue(key)
        if val and val ~= "" then
            params[key] = urldecode(val)
        end
    end

    local jsonc = require "luci.jsonc"
    local json_body = jsonc.stringify(params) or "{}"

    local tmp = os.tmpname()
    local f = io.open(tmp, "w")
    if f then
        f:write(json_body)
        f:close()
    end

    local result = call_backend_post(action, tmp)
    os.remove(tmp)

    if not result or result == "" then
        result = '{"status":"error","message":"后端未响应，请检查服务是否运行（或安装 curl/wget）"}'
    end

    http.prepare_content("application/json")
    http.write(result)
end

function action_upload_core()
    local fp
    local upload_path = "/tmp/mihomo_upload"

    http.setfilehandler(function(meta, chunk, eof)
        if not fp and meta and meta.name == "corefile" then
            fp = io.open(upload_path, "w")
        end
        if fp and chunk then
            fp:write(chunk)
        end
        if fp and eof then
            fp:close()
        end
    end)

    http.formvalue("corefile")

    local empty_json = os.tmpname()
    local ef = io.open(empty_json, "w")
    if ef then
        ef:write("{}")
        ef:close()
    end

    local result = call_backend_post("core_install_upload", empty_json)
    os.remove(empty_json)

    if not result or result == "" then
        result = '{"status":"error","message":"后端未响应，请检查服务是否运行"}'
    end

    http.prepare_content("application/json")
    http.write(result)
end
