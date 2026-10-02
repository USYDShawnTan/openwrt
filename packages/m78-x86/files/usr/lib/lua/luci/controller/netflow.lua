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
    entry({"admin", "services", "netflow", "zashboard"}, call("action_zashboard"), _("Zashboard"), 81)
    entry({"admin", "services", "netflow", "subscription"}, call("action_subscription"), _("节点订阅"), 82)
end

function action_subscription()
    local token_file = "/etc/netflow/xiaotan/sub-token"
    local f = io.open(token_file, "r")
    local token = f and (f:read("*l") or "") or ""
    if f then f:close() end
    token = token:gsub("[^%w]", "")

    local exists = false
    if token ~= "" then
        local sub = io.open("/www/m78-sub/" .. token .. ".yaml", "r")
        if sub then
            exists = true
            sub:close()
        end
    end

    local path = token ~= "" and ("/m78-sub/" .. token .. ".yaml") or ""
    local jsonc = require "luci.jsonc"

    http.prepare_content("text/html; charset=utf-8")
    http.write([[
<!doctype html>
<meta charset="utf-8">
<title>M78 私人节点订阅</title>
<style>
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;max-width:900px;margin:40px auto;padding:0 20px;color:#222}
.card{border:1px solid #ddd;border-radius:12px;padding:20px}
code{display:block;padding:12px;background:#f5f5f5;border-radius:8px;word-break:break-all;margin:12px 0}
button{padding:8px 16px;border:0;border-radius:8px;cursor:pointer}
.ok{color:#16803a}.wait{color:#a15c00}
</style>
<div class="card">
<h2>M78 私人节点订阅</h2>
<p>这里只导出 M78 生成配置里的 <b>proxies:</b>，节点名称和套餐信息节点原样保留，不包含 M78 的策略组、规则、DNS 或 TUN 配置。</p>
<p id="status" class="]] .. (exists and "ok" or "wait") .. [[">]] ..
        (exists and "订阅已生成。" or "尚未生成订阅。请在 M78 中启动或重启一次代理。") .. [[</p>
<code id="url"></code>
<button onclick="navigator.clipboard.writeText(document.getElementById('url').textContent)">复制订阅地址</button>
</div>
<script>
(function(){
  var path = ]] .. jsonc.stringify(path) .. [[;
  document.getElementById('url').textContent = path ? (window.location.origin + path) : '尚未生成 token';
})();
</script>
]])
end

function action_zashboard()
    local jsonc = require "luci.jsonc"
    local secret = uci:get("netflow", "config", "api_secret") or "netflow_secret"
    local bridge_port = "9092"

    http.prepare_content("text/html; charset=utf-8")
    http.write([[
<!doctype html>
<meta charset="utf-8">
<title>Opening Zashboard...</title>
<script>
(function () {
    var secret = ]] .. jsonc.stringify(secret) .. [[;
    var target = "/zashboard/#/setup?hostname=" +
        encodeURIComponent(window.location.hostname) +
        "&port=]] .. bridge_port .. [[" +
        "&secret=" + encodeURIComponent(secret) +
        "&disableUpgradeCore=1&disableTunMode=1";
    window.location.replace(target);
})();
</script>
<noscript>请启用 JavaScript 后打开 Zashboard。</noscript>
]])
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
