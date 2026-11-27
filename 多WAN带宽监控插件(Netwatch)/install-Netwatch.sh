#!/bin/sh
# NetWatch V6.1 encoding bootstrap (ASCII; do not edit).
# Chinese configuration and page source are below this section.
export LC_ALL=C
nw_codec() {
    LC_ALL=C awk -v mode="$1" '
    BEGIN { for(i=1;i<256;i++) ord[sprintf("%c",i)]=i }
    function die(){ bad=1; exit 1 }
    function byte(s,i){ return (i<=length(s)) ? ord[substr(s,i,1)]+0 : -1 }
    function utf(n){ if(n<128)return sprintf("%c",n); if(n<2048)return sprintf("%c%c",192+int(n/64),128+n%64); if(n<65536)return sprintf("%c%c%c",224+int(n/4096),128+int(n/64)%64,128+n%64); return sprintf("%c%c%c%c",240+int(n/262144),128+int(n/4096)%64,128+int(n/64)%64,128+n%64) }
    function out(n,   x){if(n<128)return sprintf("%c",n); if(mode=="lua")return "\\" sprintf("%03d",n); if(mode=="html" && js){if(n<=65535)return "\\u" sprintf("%04X",n); x=n-65536;return "\\u" sprintf("%04X",55296+int(x/1024)) "\\u" sprintf("%04X",56320+x%1024)} if(mode=="html")return "&#" n ";";return utf(n)}
    mode=="gb" && FNR==NR { if(FNR<=126){for(j=1;j<=NF;j++) table[(FNR-1)*190+j-1]=$j+0} else {k++;lo[k]=$1;hi[k]=$2;base[k]=$3} next }
    {
      s=$0; if(mode=="html" && s ~ /<script([ >]|$)/)js=1; result="";
      for(i=1;i<=length(s);i++){
        a=byte(s,i); n=a;
        if(a>=128){
          if(mode=="lua"){result=result out(a);continue}
          if(mode=="gb"){
            b=byte(s,i+1);if(a<129||a>254)die();
            if(b>=48&&b<=57){c=byte(s,i+2);d=byte(s,i+3);if(c<129||c>254||d<48||d>57)die();idx=(((a-129)*10+b-48)*126+c-129)*10+d-48;n=0;for(j=1;j<=k;j++)if(idx>=lo[j]&&idx<=hi[j]){n=base[j]+idx-lo[j];break}i+=3;}
            else {if(b<64||b==127||b>254)die();idx=(a-129)*190+b-64-(b>127);n=table[idx];i++}if(!n)die();
          } else {
            if(a>=194&&a<=223){count=1;n=a-192;min=128}else if(a>=224&&a<=239){count=2;n=a-224;min=2048}else if(a>=240&&a<=244){count=3;n=a-240;min=65536}else die();
            for(j=0;j<count;j++){b=byte(s,++i);if(b<128||b>191)die();n=n*64+b-128}if(n<min||n>1114111||(n>=55296&&n<=57343))die();
          }
        }
        if(mode!="validate")result=result out(n);
      }
      if(mode!="validate")print result;
      if(mode=="html" && s ~ /<\/script>/)js=0;
    }
    END{if(bad)exit 1}
    ' "$2" ${3:+"$3"}
}
# Normalize before any file removal. A GB18030 copy is repaired and re-executed.
if ! nw_codec validate "$0" >/dev/null; then
    echo '[INFO] Source is not UTF-8; trying GB18030 conversion.' >&2
    nw_tmp=$(mktemp -d /tmp/netwatch-encoding.XXXXXX) || exit 1
    trap 'rm -rf "$nw_tmp"' EXIT HUP INT TERM
    if command -v iconv >/dev/null 2>&1 && iconv -f GB18030 -t UTF-8 "$0" > "$nw_tmp/source.sh" 2>/dev/null; then :
    else
        sed -n '/^# NW_GB_TABLE_BEGIN$/,/^# NW_GB_TABLE_END$/{ /^# NW_GB_TABLE_/d; p; }' "$0" | base64 -d | gzip -dc > "$nw_tmp/table" || exit 1
        nw_codec gb "$nw_tmp/table" "$0" > "$nw_tmp/source.sh" || { echo '[ERROR] Source encoding is damaged. Save as UTF-8 and upload in binary mode.' >&2; exit 1; }
    fi
    nw_codec validate "$nw_tmp/source.sh" >/dev/null || exit 1
    sh "$nw_tmp/source.sh" "$@"
    exit $?
fi
# End encoding bootstrap.
# ============================================================
# NetWatch V6.1 - 多WAN实时带宽监控
# 文件编码：UTF-8（无 BOM），换行符：LF
# ============================================================

# ========== 配置区 ==========
TOP_MARGIN=24
# 项目地址：填写完整的 http:// 或 https:// 网址；留空则显示待配置
PROJECT_URL="https://github.com/jiange6666/OUC_Campus_Network"
# ============================

set -e
# Check built-in OpenWrt tools before changing installed files.
for tool in uci ubus awk; do command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }; done
[ -r /usr/share/libubox/jshn.sh ] || { echo 'Missing OpenWrt jshn.sh' >&2; exit 1; }
case "$TOP_MARGIN" in ""|*[!0-9]*) echo "错误：TOP_MARGIN 必须是非负整数。" >&2; exit 1;; esac

# 检查项目地址，避免无效链接或换行破坏页面
case "$PROJECT_URL" in
    "") ;;
    *[[:space:][:cntrl:]]*) echo "错误：项目地址不能包含空白或控制字符。" >&2; exit 1 ;;
    http://?*|https://?*) ;;
    *) echo "错误：项目地址必须以 http:// 或 https:// 开头。" >&2; exit 1 ;;
esac

echo "======================================"
printf '%s\n' "  多WAN带宽监控 独立CGI版 开始部署"
printf '%s\n' "  中文源码版：安装时自动转换网页及菜单编码"
echo "======================================"

# 1. Remove previous version and caches
printf '%s\n' "[1/5] 清理旧文件与缓存..."
rm -f /www/cgi-bin/wan-bw-api
rm -f /www/cgi-bin/wan-bandwidth
rm -f /usr/lib/lua/luci/controller/admin/wan_bandwidth.lua
rm -f /usr/lib/lua/luci/view/admin_network/wan_bandwidth.htm
rm -f /tmp/wan_bw_prev.dat
rm -rf /tmp/luci-* /tmp/luci-indexcache /tmp/luci-modulecache

# 2. Create JSON API
printf '%s\n' "[2/5] 创建数据接口..."
mkdir -p /www/cgi-bin
cat > /www/cgi-bin/wan-bw-api <<'EOF'
#!/bin/sh
export LC_ALL=C
printf 'Content-Type: application/json; charset=UTF-8\r\nCache-Control: no-store\r\n\r\n'
. /usr/share/libubox/jshn.sh
read -r uptime rest < /proc/uptime
config=$(uci -q -X show network) || { printf '{"error":"uci unavailable"}\n'; exit 0; }
dump=$(ubus call network.interface dump 2>/dev/null) || { printf '{"error":"ubus unavailable"}\n'; exit 0; }
# Use configured logical interfaces, not the Devices tab or raw kernel names.
names=$(printf '%s\n' "$config" | sed -n 's/^network\.\([A-Za-z0-9_][A-Za-z0-9_.-]*\)=interface$/\1/p' | grep -vx loopback || true)
json_load "$dump" || { printf '{"error":"invalid ubus data"}\n'; exit 0; }
json_select interface || { printf '{"error":"missing interface list"}\n'; exit 0; }
json_get_keys keys
# Build an ASCII tabular snapshot; names/devices are restricted to safe kernel/UCI names.
{
for key in $keys; do
    json_select "$key" || continue
    json_get_vars interface l3_device device up
    json_select ..
    case "$interface" in ''|*[!A-Za-z0-9_.-]*) continue;; esac
    [ "$interface" != loopback ] || continue
    # Use actual L3 device for PPPoE, VLAN, bridges, etc.; fallback only if up.
    dev=${l3_device:-$device}
    case "$dev" in ''|.|..|*[!A-Za-z0-9_.:@-]*) dev='';; esac
    [ "$up" = 1 ] || dev=''
    printf '%s|%s\n' "$interface" "$dev"
done
} | awk -F '|' -v names="$names" -v uptime="$uptime" '
BEGIN { n=split(names,a,"\n"); printf "{\"uptime\":%.2f,\"interfaces\":[",uptime; sep="" }
{ dev[$1]=$2 }
END {
 for(i=1;i<=n;i++){
  name=a[i]; if(name=="")continue; d=dev[name]; rx="";tx="";idx="";
  if(d!=""){
   path="/sys/class/net/" d "/statistics/rx_bytes"; if((getline rx < path)<=0)rx="";close(path);
   path="/sys/class/net/" d "/statistics/tx_bytes"; if((getline tx < path)<=0)tx="";close(path);
   path="/sys/class/net/" d "/ifindex";if((getline idx < path)<=0)idx="";close(path);
  }
  printf "%s{\"iface\":\"%s\",\"device\":\"%s\",\"ifindex\":\"%s\",",sep,name,d,idx;
  if(rx~/^[0-9]+$/ && tx~/^[0-9]+$/ && idx~/^[0-9]+$/)printf "\"rx_bytes\":%s,\"tx_bytes\":%s,\"online\":true}",rx,tx;
  else printf "\"rx_bytes\":null,\"tx_bytes\":null,\"online\":false}";
  sep=",";
 }print "]}";
}'
EOF
chmod +x /www/cgi-bin/wan-bw-api

# 3. Create standalone HTML CGI
printf '%s\n' "[3/5] 创建独立监控页面..."
cat > /www/cgi-bin/wan-bandwidth <<'EOF'
#!/bin/sh
printf 'Content-Type: text/html; charset=UTF-8\r\nCache-Control: no-store, no-cache, must-revalidate\r\nX-WAN-BW-Version: netwatch-6.1\r\n\r\n'

cat <<'HTML'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>NetWatch · 多WAN实时带宽监控</title>
<style>
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;min-height:100vh;color:#16203d;font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif;background:radial-gradient(ellipse at 2% 95%,#71b9ff 0,transparent 39%),radial-gradient(ellipse at 98% 12%,#c2b4fa 0,transparent 40%),radial-gradient(ellipse at 48% 22%,#fff 0,transparent 55%),linear-gradient(130deg,#d2eaff,#e3e8f9 55%,#dcd6fb);padding:__TOP__px 4.4vw 24px}body:before{content:"";position:fixed;inset:0;pointer-events:none;z-index:-1;background:repeating-linear-gradient(150deg,transparent 0 79px,#ffffff32 80px 81px),repeating-linear-gradient(30deg,transparent 0 79px,#ffffff26 80px 81px);mask-image:linear-gradient(transparent 15%,#000)}.wrap{max-width:1600px;margin:auto}.glass{background:linear-gradient(135deg,#ffffffb8,#f8f9ff78);border:1px solid #fff;box-shadow:inset 0 0 0 3px #ffffff55,0 12px 32px #5476ae22;backdrop-filter:blur(15px);border-radius:23px}.top{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:12px 18px;min-height:70px}.brand{display:flex;gap:12px;align-items:center;white-space:nowrap}.brand strong{font-size:25px;letter-spacing:-.6px;line-height:1.1;display:block}.brand small{font-size:11px;color:#65728c;letter-spacing:.5px}.logo{width:43px;height:43px}.back{color:#53617e;text-decoration:none;padding:8px 15px;border-radius:25px;white-space:nowrap}.actions{display:flex;gap:10px;align-items:center}.status{font-size:13px;white-space:nowrap;border-radius:22px;padding:7px 12px;background:#ffffffac;display:flex;align-items:center;gap:7px}.dot{width:9px;height:9px;border-radius:50%;background:#a4acc3;box-shadow:0 0 8px #a4acc3}.status.live .dot{background:#18cf64;box-shadow:0 0 9px #18cf6480}.status.fail .dot{background:#ef6a62}.back{background:linear-gradient(105deg,#1d9bff,#365af4 65%,#a65aef);color:#fff;box-shadow:0 5px 15px #506ee34d,inset 0 0 0 1px #ffffff55;font-weight:600;font-size:13px}.back:hover{filter:brightness(1.06)}.hero{position:relative;min-height:225px;display:flex;align-items:center;isolation:isolate}.hero-copy{position:relative;z-index:2;padding:22px 12px 25px;max-width:68%}.hero h1{margin:0 0 12px;font-size:clamp(30px,4.15vw,69px);font-weight:850;line-height:1.16;letter-spacing:-1px;background:linear-gradient(100deg,#0877e8,#1854d7 48%,#9249e6);color:#1d65df;background-clip:text;-webkit-background-clip:text;-webkit-text-fill-color:transparent;filter:drop-shadow(0 3px 0 #ffffffa0)}.hero p{font-size:clamp(13px,1.4vw,21px);margin:0;color:#435471;letter-spacing:.4px}.hero-art{position:absolute;right:-10px;top:0;width:49%;height:100%;z-index:1;overflow:visible;pointer-events:none}.dashboard{display:grid;grid-template-columns:minmax(0,2.8fr) minmax(270px,1fr);gap:18px;align-items:stretch}.left{display:grid;gap:15px;min-width:0}.panel{padding:18px 19px;min-width:0}.panel-head{display:flex;align-items:center;justify-content:space-between;gap:8px;margin:0 0 14px}.panel-head h2,.panel h2{font-size:20px;line-height:1.2;margin:0;font-weight:680;display:flex;align-items:center;gap:9px}.subtle{font-size:12px;color:#63708e}.tools{display:flex;align-items:center;gap:8px}.chip{background:#ffffffa8;border:1px solid #fff;padding:6px 10px;border-radius:10px;white-space:nowrap}.refresh{font:inherit;color:#fff;cursor:pointer;border:1px solid #ffffffb8;background:linear-gradient(135deg,#2999ff,#7d65ef);border-radius:10px;width:36px;height:35px;box-shadow:0 3px 9px #637ef955}.refresh:disabled{opacity:.55;cursor:wait}.table-scroll{overflow-x:auto;border-radius:12px}table{width:100%;border-collapse:separate;border-spacing:0;text-align:left;white-space:nowrap;font-size:14px}th{font-size:13px;font-weight:500;color:#576680;padding:11px 12px;background:#c9d9f36b}td{padding:14px 12px;border-bottom:1px solid #d4dff055;background:#ffffff56}tr:nth-child(even) td{background:#edf3fc65}tr:last-child td{border-bottom:0}td:first-child{font-weight:650}.port{display:flex;align-items:center;gap:9px}.port i{display:grid;place-items:center;width:29px;height:29px;border-radius:50%;color:#fff;background:var(--c);box-shadow:inset 0 0 0 1px #ffffffaa;font-style:normal}.port svg{width:17px;height:17px}.rate{display:flex;align-items:center;gap:7px;color:var(--c);font-variant-numeric:tabular-nums}.rate b{font-weight:600}.rate small{font-size:11px}.spark{width:64px;height:28px;flex-shrink:0;display:block;margin-left:auto;overflow:visible}.traffic{font-variant-numeric:tabular-nums;color:#34425e}.traffic span{color:var(--c);margin-right:5px}.lower{display:grid;grid-template-columns:1fr 1.12fr;gap:15px;min-width:0}.share-list{display:grid;gap:10px;margin-top:14px}.share-row{display:grid;grid-template-columns:72px 1fr 47px;gap:8px;align-items:center;font-size:13px;font-variant-numeric:tabular-nums}.share-row strong{text-align:right;font-weight:550}.track{height:11px;background:#aebfe33d;border-radius:20px;overflow:hidden}.fill{height:100%;background:linear-gradient(90deg,var(--c),var(--c2));box-shadow:0 2px 5px var(--c2);border-radius:20px;transition:width .4s;width:0;position:relative}.fill:after{content:"";position:absolute;right:4px;top:2px;width:7px;height:7px;border-radius:50%;background:#ffffffab}.features{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));padding:17px 13px;gap:0;align-items:center}.feature{padding:8px 11px;min-width:0}.feature+.feature{border-left:1px solid #9eb5df36}.feature i{font-style:normal;display:grid;place-items:center;width:39px;height:39px;background:#d7e7ff;border-radius:50%;color:#2268f4;font-size:21px;margin-bottom:8px}.feature:nth-child(2) i{background:#e7ddff;color:#7749eb}.feature:nth-child(3) i{background:#cceef4;color:#0695ae}.feature b{font-size:14px}.feature p{color:#67748c;font-size:12px;margin:6px 0 0}.summary{display:flex;flex-direction:column;gap:12px;padding:19px}.summary h2{margin:0;font-size:20px;line-height:1.3}.metric-list{background:#ffffff84;border-radius:15px;padding:0 13px}.metric{display:flex;align-items:center;gap:9px;justify-content:space-between;padding:12px 0;border-bottom:1px solid #c8d4ec66}.metric:last-child{border:0}.metric-label{font-size:13px;color:#586783}.metric-number{font-size:clamp(21px,2vw,32px);font-weight:680;line-height:1.3;color:#155ff0;white-space:nowrap;font-variant-numeric:tabular-nums;letter-spacing:-.4px}.metric-number small{font-size:13px;font-weight:500;letter-spacing:0}.metric:nth-child(2) .metric-number{color:#7440e5}.metric .spark{width:78px;height:44px}.donut-card{background:#ffffff65;border-radius:15px;display:flex;align-items:center;gap:13px;padding:14px;margin-top:auto;min-height:139px}.donut{width:112px;height:112px;flex-shrink:0;transform:rotate(-90deg)}.donut-caption{font-size:12px;color:#65728e}.donut-caption strong{font-size:28px;color:#172750;display:block;line-height:1.2}.note{font-size:11px;color:#6d7890;margin:0}.footer{display:grid;grid-template-columns:minmax(0,1fr) auto minmax(0,1fr);align-items:center;gap:12px;margin:14px auto 0}.footer-inner{grid-column:2}.project-link{grid-column:3;justify-self:end;max-width:100%;padding:9px 14px;border-radius:25px;color:#52617f;font-size:12px;text-decoration:none;white-space:nowrap}.project-link[href]{color:#2361df;font-weight:600}.project-link[href]:hover{background:#fff;box-shadow:0 4px 15px #7fa5d744}@media(max-width:1000px){.footer{display:flex;justify-content:flex-end;flex-wrap:wrap}.footer-inner{margin-right:auto}}.footer-inner{border-radius:25px;padding:9px 18px;display:flex;gap:12px;flex-wrap:wrap;justify-content:center;font-size:12px;color:#52617f}.footer-inner b{color:#2361df}.loading{text-align:center;color:#71809e}.muted{opacity:.64}@media(max-width:1250px){.dashboard{grid-template-columns:minmax(0,2.5fr) minmax(245px,1fr)}.panel{padding:15px}.summary{padding:15px}td,th{padding:12px 8px}.spark{width:49px}.metric .spark{width:58px}.features{padding:12px 8px}.feature{padding:5px 8px}.hero{min-height:200px}}@media(max-width:1000px){.dashboard{grid-template-columns:1fr}.summary{display:grid;grid-template-columns:1fr 1fr}.summary h2{grid-column:1/-1}.summary .note{grid-column:1/-1}.donut-card{margin-top:0;justify-content:center}.metric .spark{width:90px}.hero-copy{max-width:72%}}@media(max-width:620px){body{padding:12px 11px 18px}.top{padding:9px 10px;gap:6px;flex-wrap:wrap}.brand strong{font-size:20px}.brand small{font-size:10px}.logo{width:34px;height:34px}.actions{gap:5px}.status{font-size:11px;padding:5px 7px}.back{font-size:11px;padding:7px 9px}.hero{min-height:165px}.hero-copy{max-width:100%;padding:20px 6px}.hero-art{opacity:.35;width:65%}.hero h1{font-size:32px}.hero p{max-width:90%}.lower,.summary{grid-template-columns:1fr}.panel-head h2,.panel h2{font-size:17px}.panel{padding:12px}.chip{font-size:10px;padding:5px 6px}.panel-head{gap:4px}.features{padding:10px}.feature p{font-size:11px}.metric .spark{width:90px}.table-scroll table{min-width:620px}.footer-inner{gap:5px 10px}.donut-card{justify-content:flex-start}}@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important;transition:none!important}}

.settings{margin:0 0 16px;padding:16px 20px}.settings-head{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap}.settings-head h2{font-size:19px;margin:0}.interval-field{display:flex;gap:9px;align-items:center;font-size:13px;color:#435471}.interval-field select{font:inherit;color:#1e4dba;background:#ffffffc9;border:1px solid #fff;border-radius:10px;padding:7px 12px;cursor:pointer}.settings-body{margin-top:12px}.settings-label{display:flex;align-items:center;justify-content:space-between;gap:8px;flex-wrap:wrap;margin-bottom:9px}.interface-options{display:grid;grid-template-columns:repeat(auto-fit,minmax(142px,1fr));gap:8px;max-height:190px;overflow:auto;padding:2px}.interface-option{display:flex;align-items:center;gap:8px;background:#ffffff79;border:1px solid #ffffffb0;border-radius:10px;padding:8px 10px;min-width:0;cursor:pointer}.interface-option span{overflow-wrap:anywhere}.interface-option:has(input:checked){background:#e1ebff;border-color:#8daff7}.interface-option input{accent-color:#286df0;width:16px;height:16px;flex-shrink:0;margin:0}.settings-buttons{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-top:12px}.settings-buttons button{font:inherit;cursor:pointer;border:1px solid white;padding:7px 13px;border-radius:10px;background:#ffffffae;color:#435471}.settings-buttons button.primary{background:linear-gradient(105deg,#1d9bff,#365af4 65%,#a65aef);color:white;font-weight:600;margin-left:auto}.settings-buttons button:disabled{opacity:.5;cursor:not-allowed}.settings-note{font-size:12px;color:#63708e;margin:8px 0 0}.settings-note.warn{color:#9a4f18}.share-row{grid-template-columns:minmax(72px,auto) minmax(40px,1fr) 47px}.share-row>span{overflow-wrap:anywhere}@media(max-width:600px){.settings{padding:13px}.interface-options{grid-template-columns:repeat(2,minmax(0,1fr))}.settings-buttons button.primary{margin-left:0}.interval-field{flex-wrap:wrap}}
/* Inline SVG icons do not depend on Unicode glyphs or icon fonts. */
.ui-icon{width:20px;height:20px;display:inline-block;vertical-align:middle;flex-shrink:0}.refresh{display:grid;place-items:center}.refresh .ui-icon{width:20px;height:20px}.feature i .ui-icon{width:23px;height:23px}.back .ui-icon{width:15px;height:15px;margin-right:3px}.traffic-icon{width:17px;height:17px;color:var(--c);vertical-align:-3px;margin-right:6px}.rate-icon{width:17px;height:17px;flex-shrink:0}.counter-note{margin:12px 0 0;padding:9px 11px;border-radius:10px;background:#ffffff80;border-left:3px solid #7299ee;color:#586783;font-size:12px;line-height:1.65;white-space:normal}.counter-note strong{color:#344c87;font-weight:650}
</style>
</head>
<body><div class="wrap" id="home">
<header class="top glass"><div class="brand"><svg class="logo" viewBox="0 0 48 48" aria-hidden="true"><defs><linearGradient id="lg"><stop stop-color="#1ba6ff"/><stop offset="1" stop-color="#9948ee"/></linearGradient></defs><circle cx="24" cy="24" r="20" fill="none" stroke="url(#lg)" stroke-width="5"/><ellipse cx="24" cy="24" rx="10" ry="20" transform="rotate(30 24 24)" fill="none" stroke="url(#lg)" stroke-width="2"/><path d="M6 16Q25 28 42 16M6 32Q25 20 42 32" fill="none" stroke="url(#lg)" stroke-width="2"/><circle cx="38" cy="13" r="4" fill="#fff" stroke="#6488ff" stroke-width="2"/></svg><div><strong>NetWatch</strong><small>网络监控 · 更清晰的网络视图</small></div></div><div class="actions"><span class="status" id="status"><i class="dot"></i><span id="status-text">连接中</span></span><a class="back" href="/cgi-bin/luci/"><svg class="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M19 12H5m7-7-7 7 7 7"/></svg> 返回 LuCI</a></div></header>
<section class="hero"><div class="hero-copy"><h1>多WAN实时带宽监控</h1><p>在统一面板中查看各 WAN 口速率、累计流量与下行占比</p></div>
<svg class="hero-art" viewBox="0 0 650 250" aria-hidden="true"><defs><linearGradient id="platform" x2="0" y2="1"><stop stop-color="#f9fcff"/><stop offset="1" stop-color="#8eacee"/></linearGradient><linearGradient id="screen" x2="1" y2="1"><stop stop-color="#fff"/><stop offset="1" stop-color="#d5dff9"/></linearGradient><linearGradient id="blue"><stop stop-color="#0f94ff"/><stop offset="1" stop-color="#7451ed"/></linearGradient><linearGradient id="cable"><stop stop-color="#2ca8ff"/><stop offset="1" stop-color="#7a54ff"/></linearGradient><radialGradient id="orb" cx=".3" cy=".25"><stop stop-color="#fff"/><stop offset=".3" stop-color="#9ce6ff"/><stop offset=".75" stop-color="#4289f4"/><stop offset="1" stop-color="#7b4be5"/></radialGradient><filter id="shadow" x="-35%" y="-35%" width="170%" height="185%"><feDropShadow dx="0" dy="9" stdDeviation="9" flood-color="#557dd0" flood-opacity=".28"/></filter></defs><g opacity=".65" fill="none" stroke="#fff"><ellipse cx="350" cy="207" rx="275" ry="46" stroke-width="2"/><ellipse cx="350" cy="207" rx="310" ry="59"/><ellipse cx="350" cy="207" rx="215" ry="30" stroke-width="3"/></g><g filter="url(#shadow)"><ellipse cx="330" cy="204" rx="151" ry="37" fill="#6990dc"/><ellipse cx="330" cy="194" rx="151" ry="37" fill="url(#platform)" stroke="#fff" stroke-width="3"/><ellipse cx="330" cy="191" rx="124" ry="28" fill="#e9f4ff" stroke="#779ce5" stroke-width="4"/><ellipse cx="330" cy="190" rx="94" ry="20" fill="#c8dcfa"/><g transform="translate(214 13) rotate(8 115 90)"><rect x="7" y="7" width="239" height="155" rx="17" fill="#a5b9e8" stroke="#f4f9ff" stroke-width="2"/><rect width="239" height="155" rx="17" fill="url(#screen)" stroke="white" stroke-width="3"/><rect x="13" y="13" width="213" height="123" rx="10" fill="#f5f8ff" stroke="#ccd9f4"/><path d="M25 34H214" stroke="#d8e4ff" stroke-width="3"/><g fill="#bfd2f8"><circle cx="29" cy="24" r="3"/><circle cx="39" cy="24" r="3"/><circle cx="49" cy="24" r="3"/></g><g fill="url(#blue)"><rect x="34" y="83" width="10" height="32" rx="3"/><rect x="51" y="69" width="10" height="46" rx="3"/><rect x="68" y="51" width="10" height="64" rx="3"/><rect x="85" y="77" width="10" height="38" rx="3"/><rect x="102" y="59" width="10" height="56" rx="3"/></g><circle cx="174" cy="71" r="25" fill="none" stroke="#dfe8fb" stroke-width="12"/><path d="M174 46A25 25 0 1 1 151 81" fill="none" stroke="url(#blue)" stroke-width="12"/><path d="M140 110h66m-66 9h44" stroke="#cad8f6" stroke-width="4" stroke-linecap="round"/></g><g transform="translate(200 111) rotate(9 47 45)"><rect width="96" height="88" rx="13" fill="url(#screen)" stroke="#fff" stroke-width="3"/><path d="M20 52a28 28 0 0 1 56 0" fill="none" stroke="#d7e3fa" stroke-width="9"/><path d="M20 52a28 28 0 0 1 46-21" fill="none" stroke="url(#blue)" stroke-width="9" stroke-linecap="round"/><path d="M48 53l15-14" stroke="#3474eb" stroke-width="3" stroke-linecap="round"/><circle cx="48" cy="53" r="4" fill="#3474eb"/><text x="48" y="73" text-anchor="middle" font-size="13" fill="#3a62c4" font-weight="600">LIVE</text></g><g transform="translate(460 111)"><path d="M0 14 35 0 78 15 43 30Z" fill="#f9fcff" stroke="#fff"/><path d="M0 14 43 30v61L0 75Z" fill="#d5e6ff" stroke="#fff"/><path d="M43 30 78 15v61L43 91Z" fill="#adc6f7" stroke="#fff"/><text x="21" y="53" fill="#3455d9" font-weight="700" font-size="14" transform="rotate(18 21 53)" text-anchor="middle">WAN</text></g></g><g fill="none" stroke-linecap="round"><path d="M-12 166C55 160 74 115 135 120S192 159 207 170M406 183C466 190 526 225 660 231M453 163C533 156 577 150 654 183" stroke="#fff" stroke-width="10"/><path d="M-12 166C55 160 74 115 135 120S192 159 207 170M406 183C466 190 526 225 660 231M453 163C533 156 577 150 654 183" stroke="url(#cable)" stroke-width="5"/></g><g transform="translate(148 130) rotate(30)"><rect width="33" height="17" rx="3" fill="#3a8ded" stroke="#fff"/><rect x="24" y="3" width="14" height="11" fill="#e7f4ff" stroke="#9cbce7"/><path d="M4 4h14M4 8h14M4 12h14" stroke="#bce2ff"/></g><g transform="translate(530 207) rotate(15)"><rect width="36" height="16" rx="3" fill="#3a8ded" stroke="#fff"/><rect x="28" y="2" width="13" height="12" fill="#f3faff" stroke="#9cbce7"/><path d="M4 4h16M4 8h16M4 12h16" stroke="#bce2ff"/></g><g transform="translate(573 46)"><circle r="24" fill="url(#orb)" stroke="#fff" stroke-width="2"/><ellipse rx="41" ry="12" transform="rotate(-23)" fill="none" stroke="#fff" stroke-width="1.5"/><circle cx="34" cy="-14" r="4" fill="#8a9bff" stroke="#fff"/></g><g fill="#fff" opacity=".8"><circle cx="161" cy="41" r="3"/><circle cx="98" cy="79" r="2"/><circle cx="506" cy="29" r="3"/><path d="M121 42l8 9-8 9-8-9Z"/></g></svg></section>
<section class="glass settings" aria-label="监控设置"><div class="settings-head"><h2>监控设置</h2><label class="interval-field" for="interval-select">实时刷新间隔 <select id="interval-select"><option value="1">1s</option><option value="2" selected>2s</option><option value="5">5s</option><option value="10">10s</option></select></label></div><div class="settings-body"><div class="settings-label"><strong>网络接口选择</strong><span class="subtle" id="selection-count">正在识别接口...</span></div><div class="interface-options" id="interface-options"><span class="subtle">正在读取路由器接口...</span></div><div class="settings-buttons"><button type="button" id="select-all" disabled>全选</button><button type="button" id="select-none" disabled>取消全选</button><button class="primary" type="button" id="apply" disabled>应用设置</button></div><p class="settings-note" id="settings-message" role="status">请选择需要监控的接口。设置保存在当前浏览器。</p><p class="settings-note">接口列表来自 LuCI 网络配置；未连接接口可选择，上线后自动采样。同一设备的多个逻辑接口只计一次。</p></div></section>
<main class="dashboard"><div class="left"><section class="glass panel" id="links"><div class="panel-head"><h2><svg width="24" height="24" viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M3 21h18" stroke="#5179f4" stroke-width="2"/><rect x="4" y="11" width="4" height="9" rx="1" fill="#3699f8"/><rect x="10" y="7" width="4" height="13" rx="1" fill="#6769fa"/><rect x="16" y="2" width="4" height="18" rx="1" fill="#a16aee"/></svg>实时链路数据</h2><div class="tools"><span class="chip subtle" id="window">最近 60 次采样</span><button class="refresh" id="refresh" type="button" title="立即刷新" aria-label="立即刷新"><svg class="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 11a8 8 0 1 0-2.4 5.7M20 4v7h-7"/></svg></button></div></div><div class="table-scroll"><table><thead><tr><th>接口</th><th>下行 RX</th><th>上行 TX</th><th>累计 RX</th><th>累计 TX</th></tr></thead><tbody id="rows"><tr><td class="loading" colspan="5">正在连接路由器...</td></tr></tbody></table></div><p class="counter-note"><strong>累计说明：</strong>RX 为实际设备累计接收字节数，TX 为累计发送字节数；从设备计数器建立或上次清零时开始统计（通常为设备启动时），并非打开网页后或当天的流量。重启路由器、设备重建或计数器清零可能使累计值重置；刷新网页不会清零。</p></section>
<div class="lower"><section class="glass panel" id="distribution"><h2>下行流量分布</h2><div class="share-list" id="shares"><div class="loading">等待采样</div></div></section><section class="glass features" aria-label="监控功能"><div class="feature"><i><svg class="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M13 2 4 14h7l-1 8 10-12h-7l1-8Z" fill="currentColor" stroke="none"/></svg></i><b>速率监测</b><p>实时掌握网络速度变化</p></div><div class="feature"><i><svg class="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><ellipse cx="12" cy="5" rx="8" ry="3"/><path d="M4 5v14c0 1.7 3.6 3 8 3s8-1.3 8-3V5M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3"/></svg></i><b>流量统计</b><p>查看各接口累计流量</p></div><div class="feature"><i><svg class="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m12 3 9 5-9 5-9-5 9-5ZM3 12l9 5 9-5M3 16l9 5 9-5"/></svg></i><b>负载观察</b><p>多WAN负载均衡与状态观察</p></div></section></div></div>
<aside class="glass summary" id="stats"><h2>整体统计</h2><div class="metric-list"><div class="metric"><div><div class="metric-label">总下行速率</div><div class="metric-number"><span id="total-rx">--</span> <small>Mbps</small></div></div><svg id="chart-rx" class="spark" viewBox="0 0 100 40" preserveAspectRatio="none" aria-hidden="true"></svg></div><div class="metric"><div><div class="metric-label">总上行速率</div><div class="metric-number"><span id="total-tx">--</span> <small>Mbps</small></div></div><svg id="chart-tx" class="spark" viewBox="0 0 100 40" preserveAspectRatio="none" aria-hidden="true"></svg></div><div class="metric"><div><div class="metric-label">累计总流量</div><div class="metric-number" id="total-volume">--</div></div><svg id="chart-volume" class="spark" viewBox="0 0 100 40" preserveAspectRatio="none" aria-hidden="true"></svg></div></div><div class="donut-card"><svg class="donut" viewBox="0 0 120 120" id="donut" role="img" aria-label="各接口下行流量占比"><circle cx="60" cy="60" r="43" fill="none" stroke="#dbe5f6" stroke-width="24"/></svg><div class="donut-caption">实时下行占比<strong id="download-share">--</strong><span>下行 / (下行 + 上行)</span></div></div><p class="note">环图：各 WAN 实时下行分布。累计总流量 = 当前所选在线接口对应设备的累计 RX + TX（同一设备只计一次）。</p></aside></main>
<footer class="footer"><div class="glass footer-inner"><span><b id="iface-count">--</b> 个接口</span><span>·</span><span>实时数据 · <b id="footer-interval">2</b>s 刷新</span><span>·</span><span>最后更新 <b id="cur-time">--</b></span><span>·</span><span>趋势仅记录本次页面采样</span></div>__PROJECT_LINK__</footer></div>
<script>
(function(){
'use strict';
var interval=2000, limit=60, colors=['#1879f4','#13aa78','#f87924','#8552e8','#12afc5','#db579d'], light=['#79c5ff','#75e5aa','#ffc477','#c6a1ff','#74e9ea','#f7a7d1'];
var hist=Object.create(null), totals={rx:[],tx:[],volume:[]}, busy=false, last=null, rowKey='', rows=Object.create(null), shareRows=Object.create(null);
var $=function(id){return document.getElementById(id);};
var storageKey='netwatch-v6-settings', active=[], draft=[], available=[], previous=null, timer=null, discovered=false, optionKey=null, details=Object.create(null);
var storageOK=true;
try { var saved=JSON.parse(localStorage.getItem(storageKey)||'null'); if(saved){if([1,2,5,10].indexOf(saved.seconds)>=0)interval=saved.seconds*1000;if(Array.isArray(saved.interfaces))active=saved.interfaces.filter(function(x,i,a){return typeof x==='string'&&a.indexOf(x)===i;});} } catch(e){storageOK=false;}
draft=active.slice();
function save(){try{localStorage.setItem(storageKey,JSON.stringify({seconds:interval/1000,interfaces:active}));storageOK=true;}catch(e){storageOK=false;}}
function selectionCount(){var count=draft.filter(function(n){return available.indexOf(n)>=0;}).length;$('selection-count').textContent='识别 '+available.length+' 个 · 已选 '+count+' 个';$('apply').disabled=!discovered;$('select-all').disabled=!available.length;$('select-none').disabled=!available.length;}
function showOptions(){var names=available.slice();var key=JSON.stringify(names.map(function(n){var it=details[n];return [n,it.device,it.online];}));if(key!==optionKey){optionKey=key;var root=$('interface-options');root.textContent='';names.forEach(function(n){var it=details[n],label=el('label','interface-option'),cb=el('input');cb.type='checkbox';cb.value=n;cb.checked=draft.indexOf(n)>=0;cb.addEventListener('change',function(){draft=cb.checked?draft.concat(n):draft.filter(function(x){return x!==n;});selectionCount();});label.appendChild(cb);var info=el('span','',n),sub=el('small','',it.online?it.device:'未连接');sub.style.display='block';sub.style.color='#63708e';info.appendChild(sub);label.appendChild(info);root.appendChild(label);});if(!names.length)root.appendChild(el('span','subtle','未发现已配置的网络接口'));}Array.prototype.forEach.call($('interface-options').querySelectorAll('input'),function(cb){cb.checked=draft.indexOf(cb.value)>=0;});selectionCount();}
function message(){var offline=active.filter(function(n){return !details[n]||!details[n].online;});var seen=Object.create(null),duplicates=[];active.forEach(function(n){var it=details[n];if(!it||!it.online)return;if(seen[it.device])duplicates.push(n);else seen[it.device]=true;});$('settings-message').textContent=(active.length?'正在监控 '+(active.length-offline.length-duplicates.length)+' 个独立设备'+(offline.length?'；未连接或已删除：'+offline.join('、'):'')+(duplicates.length?'；重复设备已跳过：'+duplicates.join('、'):''):'请选择需要监控的接口，然后点击应用设置。')+(storageOK?' 设置保存在当前浏览器。':' 浏览器存储不可用，设置仅本次有效。');$('settings-message').className='settings-note'+(offline.length||duplicates.length?' warn':'');}
function resetHistory(){previous=null;hist=Object.create(null);totals={rx:[],tx:[],volume:[]};rowKey='';['chart-rx','chart-tx','chart-volume'].forEach(function(id){$(id).textContent='';});}
function emptyPanel(text){$('rows').textContent='';var tr=el('tr'),td=el('td','loading',text);td.colSpan=5;tr.appendChild(td);$('rows').appendChild(tr);$('shares').textContent='';$('shares').appendChild(el('div','loading',text));['total-rx','total-tx','total-volume','download-share'].forEach(function(id){$(id).textContent='--';});$('iface-count').textContent='0';var donut=$('donut');while(donut.childNodes.length>1)donut.removeChild(donut.lastChild);rowKey='';}
function consume(raw){if(!raw||typeof raw.uptime!=='number'||!isFinite(raw.uptime)||!Array.isArray(raw.interfaces)||!raw.interfaces.every(function(it){return it&&typeof it.iface==='string'&&typeof it.device==='string'&&typeof it.ifindex==='string'&&typeof it.online==='boolean'&&(!it.online||(typeof it.rx_bytes==='number'&&typeof it.tx_bytes==='number'&&isFinite(it.rx_bytes)&&isFinite(it.tx_bytes)&&it.rx_bytes>=0&&it.tx_bytes>=0));}))throw Error('Invalid counters');
 var map=Object.create(null);raw.interfaces.forEach(function(it){map[it.iface]=it;});details=map;available=Object.keys(map);discovered=true;showOptions();message();
 var seen=Object.create(null);var names=active.filter(function(n){var it=map[n];if(!it||!it.online||seen[it.device])return false;seen[it.device]=true;return true;});var key=JSON.stringify(names);if(key!==rowKey)resetHistory();
 if(!names.length){resetHistory();emptyPanel(active.length?'所选接口暂未连接':'请先在监控设置中选择接口');$('status').className='status live';$('status-text').textContent=active.length?'等待接口':'等待选择';document.querySelector('.dashboard').classList.remove('muted');return;}
 var dt=previous?raw.uptime-previous.uptime:0;var valid=dt>0&&dt<=Math.max(60,interval/1000*4)&&names.every(function(n){var p=previous.map[n],it=map[n];return p&&p.online&&it.device===p.device&&it.ifindex===p.ifindex&&it.rx_bytes>=p.rx_bytes&&it.tx_bytes>=p.tx_bytes;});var rx=0,tx=0;
 var list=names.map(function(n){var it=map[n],p=valid?previous.map[n]:null,a=p?(it.rx_bytes-p.rx_bytes)*8/(dt*1000000):0,b=p?(it.tx_bytes-p.tx_bytes)*8/(dt*1000000):0;rx+=a;tx+=b;return {iface:n,rx_mbps:a,tx_mbps:b,rx_mb:it.rx_bytes/1048576,tx_mb:it.tx_bytes/1048576};});previous={uptime:raw.uptime,map:map};render({delta:valid?dt:0,interfaces:list,total_rx_mbps:rx,total_tx_mbps:tx,shares:list.map(function(it){return {iface:it.iface,share:rx?it.rx_mbps/rx*100:0};})});}
function schedule(){clearInterval(timer);timer=setInterval(fetchData,interval);$('interval-select').value=String(interval/1000);$('footer-interval').textContent=interval/1000;$('window').textContent='最近 60 次采样';}

function push(a,v){a.push(v);if(a.length>limit)a.shift();}
function num(v){return typeof v==='number'&&isFinite(v)&&v>=0?v:0;}
function volume(v){return v>=1048576?[ (v/1048576).toFixed(2),'TiB']:v>=1024?[(v/1024).toFixed(2),'GB']:[v.toFixed(1),'MB'];}
function svg(tag,attrs){var e=document.createElementNS('http://www.w3.org/2000/svg',tag);Object.keys(attrs).forEach(function(k){e.setAttribute(k,attrs[k]);});return e;}
function spark(el,arr,color){while(el.firstChild)el.removeChild(el.firstChild);if(!arr.length)return;var max=Math.max.apply(null,arr),min=Math.min.apply(null,arr),range=max-min;var pts=arr.map(function(v,i){return [arr.length===1?50:2+i*96/(arr.length-1),range?35-(v-min)/range*30:20];});if(pts.length===1){el.appendChild(svg('circle',{cx:50,cy:20,r:2.6,fill:color}));return;}var p=pts.map(function(a){return a.join(',');}).join(' ');el.appendChild(svg('polygon',{points:pts[0][0]+',39 '+p+' '+pts[pts.length-1][0]+',39',fill:color,opacity:'.12'}));el.appendChild(svg('polyline',{points:p,fill:'none',stroke:color,'stroke-width':'1.7','stroke-linecap':'round','stroke-linejoin':'round','vector-effect':'non-scaling-stroke'}));var end=pts[pts.length-1];el.appendChild(svg('circle',{cx:end[0],cy:end[1],r:2.1,fill:color}));}
function el(tag,cls,txt){var e=document.createElement(tag);if(cls)e.className=cls;if(txt!==undefined)e.textContent=txt;return e;}
function rateCell(tr,arrow){var td=el('td'), box=el('div','rate'), a=svg('svg',{class:'rate-icon',viewBox:'0 0 24 24',fill:'none',stroke:'currentColor','stroke-width':'2','stroke-linecap':'round','stroke-linejoin':'round','aria-hidden':'true'}), b=el('b','','--'), unit=el('small','','Mbps'), chart=svg('svg',{class:'spark',viewBox:'0 0 100 40',preserveAspectRatio:'none','aria-hidden':'true'});a.appendChild(svg('path',{d:arrow==='down'?'M12 4v16m-6-6 6 6 6-6':'M12 20V4m-6 6 6-6 6 6'}));box.appendChild(a);box.appendChild(b);box.appendChild(unit);box.appendChild(chart);td.appendChild(box);tr.appendChild(td);return {value:b,chart:chart};}
function trafficCell(tr){var td=el('td','traffic'),icon=svg('svg',{class:'traffic-icon',viewBox:'0 0 24 24',fill:'none',stroke:'currentColor','stroke-width':'1.8','stroke-linecap':'round','stroke-linejoin':'round','aria-hidden':'true'}),value=el('b','','--');icon.appendChild(svg('ellipse',{cx:12,cy:5,rx:8,ry:3}));icon.appendChild(svg('path',{d:'M4 5v14c0 1.7 3.6 3 8 3s8-1.3 8-3V5M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3'}));td.appendChild(icon);td.appendChild(value);tr.appendChild(td);return value;}
function setup(list){$('rows').textContent='';$('shares').textContent='';rows=Object.create(null);shareRows=Object.create(null);list.forEach(function(it,i){var c=colors[i%colors.length],l=light[i%light.length],tr=el('tr');tr.style.setProperty('--c',c);var td=el('td'),port=el('div','port'),icon=el('i');var pic=svg('svg',{viewBox:'0 0 20 20',fill:'none',stroke:'currentColor','stroke-width':'1.3','aria-hidden':'true'});pic.appendChild(svg('rect',{x:3,y:4,width:14,height:12,rx:2}));pic.appendChild(svg('path',{d:'M6 7h8M6 10h2m2 0h4M6 13h8'}));icon.appendChild(pic);port.appendChild(icon);port.appendChild(el('span','',it.iface));td.appendChild(port);tr.appendChild(td);rows[it.iface]={rx:rateCell(tr,'down'),tx:rateCell(tr,'up'),rv:trafficCell(tr),tv:trafficCell(tr)};$('rows').appendChild(tr);var sr=el('div','share-row'),name=el('span','',it.iface),track=el('div','track'),fill=el('div','fill'),pct=el('strong','','--');sr.style.setProperty('--c',c);sr.style.setProperty('--c2',l);track.appendChild(fill);sr.appendChild(name);sr.appendChild(track);sr.appendChild(pct);$('shares').appendChild(sr);shareRows[it.iface]={fill:fill,pct:pct};});}
function render(data){var list=data.interfaces;if(!Array.isArray(list)||!list.length||!list.every(function(it){return it&&typeof it.iface==='string'&&typeof it.rx_mbps==='number'&&typeof it.tx_mbps==='number';}))throw Error('Invalid interface data');var key=JSON.stringify(list.map(function(it){return it.iface;}));if(key!==rowKey){setup(list);rowKey=key;}var rx=0,tx=0,v=0,valid=data.delta>0;list.forEach(function(it,i){var c=colors[i%colors.length],h=hist[it.iface]||(hist[it.iface]={rx:[],tx:[]}),r=rows[it.iface],a=num(it.rx_mbps),b=num(it.tx_mbps),rv=num(it.rx_mb),tv=num(it.tx_mb);rx+=a;tx+=b;v+=rv+tv;if(valid){push(h.rx,a);push(h.tx,b);}r.rx.value.textContent=valid?a.toFixed(2):'--';r.tx.value.textContent=valid?b.toFixed(2):'--';r.rv.textContent=volume(rv).join(' ');r.tv.textContent=volume(tv).join(' ');spark(r.rx.chart,h.rx,c);spark(r.tx.chart,h.tx,c);});rx=num(data.total_rx_mbps);tx=num(data.total_tx_mbps);if(valid){push(totals.rx,rx);push(totals.tx,tx);}push(totals.volume,v);$('total-rx').textContent=valid?rx.toFixed(2):'--';$('total-tx').textContent=valid?tx.toFixed(2):'--';var vol=volume(v);$('total-volume').textContent=vol[0]+' ';$('total-volume').appendChild(el('small','',vol[1]));spark($('chart-rx'),totals.rx,'#1678f4');spark($('chart-tx'),totals.tx,'#8654f2');spark($('chart-volume'),totals.volume,'#2d8bed');var map=Object.create(null);(data.shares||[]).forEach(function(s){map[s.iface]=num(s.share);});var donut=$('donut');while(donut.childNodes.length>1)donut.removeChild(donut.lastChild);var circumference=2*Math.PI*43,offset=0;list.forEach(function(it,i){var share=valid?Math.min(100,map[it.iface]||0):0,r=shareRows[it.iface];r.fill.style.width=share+'%';r.pct.textContent=valid?share.toFixed(1)+'%':'--';if(share>0){var len=Math.min(circumference-offset,circumference*share/100);if(len>0){donut.appendChild(svg('circle',{cx:60,cy:60,r:43,fill:'none',stroke:colors[i%colors.length],'stroke-width':24,'stroke-dasharray':Math.max(0,len-0.8)+' '+circumference,'stroke-dashoffset':-offset}));offset+=len;}}});$('download-share').textContent=valid&&rx+tx>0?(rx/(rx+tx)*100).toFixed(1)+'%':'--';$('iface-count').textContent=list.length;last=new Date();$('cur-time').textContent=last.toLocaleTimeString('zh-CN',{hour12:false});$('status').className='status live';$('status-text').textContent=valid?'实时刷新 '+(interval/1000)+'s':'采样中';document.querySelector('.dashboard').classList.remove('muted');}
function fail(){$('status').className='status fail';$('status-text').textContent='连接异常';document.querySelector('.dashboard').classList.add('muted');if(!last)emptyPanel('数据接口无响应');$('settings-message').textContent='数据接口连接异常，请稍后重试。';}
function fetchData(){if(busy)return;busy=true;$('refresh').disabled=true;var x=new XMLHttpRequest();x.open('GET','/cgi-bin/wan-bw-api?_='+Date.now(),true);x.timeout=Math.max(4000,interval*2);x.onload=function(){try{if(x.status!==200)throw Error('HTTP');consume(JSON.parse(x.responseText));}catch(e){fail();}};x.onerror=fail;x.ontimeout=fail;x.onloadend=function(){busy=false;$('refresh').disabled=false;};x.send();}
$('refresh').addEventListener('click',fetchData);
$('interval-select').addEventListener('change',function(){var value=Number(this.value);if([1,2,5,10].indexOf(value)<0)return;interval=value*1000;save();schedule();if(active.length)$('status-text').textContent='实时刷新 '+value+'s';message();fetchData();});
$('select-all').addEventListener('click',function(){draft=available.slice();showOptions();});
$('select-none').addEventListener('click',function(){draft=[];showOptions();});
$('apply').addEventListener('click',function(){var next=draft.filter(function(n){return available.indexOf(n)>=0;});active=next;draft=next.slice();save();resetHistory();emptyPanel('正在采集所选接口...');showOptions();message();$('status-text').textContent='采样中';fetchData();});
schedule();fetchData();
})();
</script></body></html>
HTML
EOF

# Substitute page configuration
sed -i "s/__TOP__/$TOP_MARGIN/" /www/cgi-bin/wan-bandwidth
# 项目地址：先转义 HTML 属性，再转义 sed 替换字符串
if [ -n "$PROJECT_URL" ]; then
    project_href=$(printf '%s' "$PROJECT_URL" | sed 's/&/\&amp;/g; s/"/\&quot;/g; s/</\&lt;/g; s/>/\&gt;/g')
    project_markup="<a class=\"glass project-link\" href=\"$project_href\" target=\"_blank\" rel=\"noopener noreferrer\" title=\"$project_href\">项目地址</a>"
else
    project_markup='<span class="glass project-link">项目地址：待配置</span>'
fi
project_replacement=$(printf '%s' "$project_markup" | sed 's/[\\&|]/\\&/g')
sed -i "s|__PROJECT_LINK__|$project_replacement|" /www/cgi-bin/wan-bandwidth
nw_codec html /www/cgi-bin/wan-bandwidth > /www/cgi-bin/wan-bandwidth.encoded
mv /www/cgi-bin/wan-bandwidth.encoded /www/cgi-bin/wan-bandwidth
chmod +x /www/cgi-bin/wan-bandwidth

# 4. Create legacy LuCI menu controller
printf '%s\n' "[4/5] 创建LuCI菜单入口..."
mkdir -p /usr/lib/lua/luci/controller/admin
cat > /usr/lib/lua/luci/controller/admin/wan_bandwidth.lua <<'EOF'
module("luci.controller.admin.wan_bandwidth", package.seeall)

function index()
    entry({"admin", "network", "wan_bandwidth"},
        call("redirect_monitor"),
        "多WAN带宽监控", 90)
end

function redirect_monitor()
    luci.http.redirect("/cgi-bin/wan-bandwidth")
end
EOF
nw_codec lua /usr/lib/lua/luci/controller/admin/wan_bandwidth.lua > /usr/lib/lua/luci/controller/admin/wan_bandwidth.lua.encoded
mv /usr/lib/lua/luci/controller/admin/wan_bandwidth.lua.encoded /usr/lib/lua/luci/controller/admin/wan_bandwidth.lua
chmod 644 /usr/lib/lua/luci/controller/admin/wan_bandwidth.lua

# 5. Restart web service
printf '%s\n' "[5/5] 重启服务并清理缓存..."
rm -rf /tmp/luci-* /tmp/luci-indexcache /tmp/luci-modulecache
/etc/init.d/uhttpd restart

LAN_IP=$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.100.1")
echo ""
echo "======================================"
printf '%s\n' "  [OK] 部署完成"
echo "======================================"
printf '%s\n' "  监控接口: 在网页选择并应用"
printf '%s\n' "  刷新间隔: 在网页选择（默认 2 秒）"
echo ""
printf '%s\n' "  访问方式:"
printf '%s\n' "  1. LuCI后台 → 网络 → 多WAN带宽监控（自动跳转）"
printf '%s\n' "  2. 直接访问: http://$LAN_IP/cgi-bin/wan-bandwidth"
echo ""
printf '%s\n' "  已完成部署，请强制刷新浏览器并重新选择逻辑接口"
echo "======================================"
exit 0
# Encoding fallback data (do not edit)
: <<'NW_ENCODING_DATA'
# NW_GB_TABLE_BEGIN
H4sIAAAAAAAC/yzdWZbsKBJF0f83ihxC0Fg3/4mV2F75YSuXOyjiATLp3GsQa6b+/ltf3OIR74vt/ztfnCXOf/vv+09c4hFT9O26
Yogl+nxrv7Xf/eLZok+OXsd1jm+vb6++oU24Zvg2fJ7ap5+SPk+fl59VrlCuXPqW9qV9aV/at5atZWvZWraWrWVrOf7t4/qj1/jd
Rq/Ra/QavYzYMmLLiC0jtozYWltsUUujtPYVQ9Ty+NzIrOsKV5urzfV5+CmhZbiycVvhClGilsZqGZ9lZJaRWcZk+bcv//bl3778
S9f4ifP75P22279o/4WYYom+9a/by+dWwvYv3ftP9K1/6fZv3Fub/WvjCkdL//ZttezjZ1kn2wrZRmMbjW009vWtEdhGYPu3b2tm
p5appXHY1swuP6u0NybbOtlWyG6/Q/vW+Gzjs43Ptja2tbGN1bYqtlWxrYptVWyjt43esSqOcTt/7/OzfGINHONzjMwxJsdoHKNx
3DXHXXNOidpc3xqTY0yOMTnG5LibjpE5RuaENsbnWBvHKJ3Uxlgdd9kxVscoHffXMVbH/XWsn2PEjlV0Wkt31jFux511Ov+9qI3x
OUbmGo1rRd2/LR7xiin+Wrb4fs9rxO7Sy3q7Sy9Z6Fp719q71t41qlcWutbedZdda+/uXxtXNrbXervW2zXO1zhf43yN83X3XXff
NbbX2F756hrPm741ntd4XuN5rb1rVK9RvUb1WoHXqF6jeq3Da1Sv1XiN7TW2V+66Rvhan9f6vMb5Wp/X+rxy13UvXyvz/sbfmgzj
H8Y/jH8Y8zDaYbTDOIcRDnk+jHPIYGFsw3iG8QzjGVZvWL3hXg5rOIxzGOcwzmGc4+hlnMM4h/Uc1nNYz2Hkw6oO4x9GPqzqMP5h
bYfxj3Q1aztSSzMSZiTy19I1zUuYkTAjYZ2HeQnzEuYlrPYwO2F2wryEeQnzEuYlzEuYlzAjYUbCjIS8EfJGmJ1wd4Q5CnOU7pE0
R2mO0t2RMnCaozRH6Y5IM5VmKs1UuhfSvZDmK2XjdF+kuUv3RbovUv5Js5lmM81mms00m2k202ym2UyzmWYzzWa6a9Kc5tXXzKYc
nmY2zWmax/QUS7OZZjPNZsavjWu6s9LMpplNM5tmNs1syvOZ/e9F7d1raWbTEzDNb5rfNL9pftP8pvlN85vmN919aZbTLKdZTrOc
Zjndd2mW0yynWU6znGY5zW+a3/zNr3uwzHKZ5TLL5U4sc13muuTDcm+WfFhmv8x4yYFl3su8l7kuc12eL2XGy1yXWS6zXGa5zHKZ
5TK/ZX7L/Jb5LfNb5rfMb5nfMr9lfsvMlnu2zG+5Z8s9W+a6zHXJnGXGy1yXuS5zXZ5NZcbLjJcZLzNeZrzMeJnxckeXO7rc0WXe
y7yXeS/zXua9zHuZ9zLvVb9efqJ5L/Ne5r3Me5n3Mu9l3svdXWa/zH6Z/TL7ZfbL7Jd7vKyBsgbKGihvCG3e2/y2O7rNbJvTNqct
67Z7uc1vu3/bnLb7t81pm802m+2ebXPa5rTNZpvNNo9tHtsMtju0r+uYrzYXbeTbyLdxbuPcxrmNcxvbNrZdv29d2Xi28Wwj2Uay
jVsbsTZKbZTaKLXxaffIGJ9xX4z7YtwX474Y98IYtzFKY+WPlT9W/uzf5yVqb3zG+IyRGWMyxmSMxhiNsarHeh4jM/fXxnWM0sT6
96L2VvXIY2NVjzEc63mM5BjJsXrH6h2jOkZ15K4xtmP1jrEda3WM7RjVMZ5jDMe6mjduC68tvPbFK/4+7xeXb98a+6I2b8S+6JP9
+yTEFPV94/YBjZbHFY4rH22Ob6/Pr+tc317XCZ+ET9IVUsv0efqJ+ftW+/QTS8vSsnxbvq3ft35ia9PatKu1q7WWrWX7V4+Wo+Vo
Oa45fv+30hZ2W9jti1u8Yogltqj90t544rsvHlGvpddbkwv3fU20N8K4b+G+hfu+6PrGeRlnJPhFVz56GfN19DraH1e+2hv/ZfyR
40KOCzl+0U+52of/D1eI3yd+bvrc+CPHhRy/6GpmAUUuFPlFLevX0hXMyDIjq7U3F0hzYcwvamlG8ObCm1/UxhrGngt7Luz5xSNe
McQStTEX21yg0S9qby6Q6UKmC5l+Ua+tvZW/zQtK/aLrmxesurDqwqoLqy6s+kW9zAtiXYj1i3qZne3u2OYIwy4MuzDsF30bvg3X
dL/s8K052uYI1X6LRcvc/17Uxqxts4Zzv6XkCmZqm6ldv89dwZ2yzc42Owh3IdyFcL9l6DcxOwh3IdyFcBfCXQh3IdyFcL+4xC0e
8Yotaml2jnk55uWYkWP8j/E/xh8Lfwtfe6OKf7/oOlY7zl04dyHcL2pp3LDtQrVf1FI+OcYH1S5Uu1DtQrVf1FImOUbpWL3Hij1G
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
+IPiD4o/KP5w5A9H/iD6g+gPR/5w5A+6/6K+5hTdH3R/uPMH4x+MfzD+wfhHtfDh1x/Vwgf1H9R/ePeHd39494d3f6gBhxpw+PiH
j38oA4ePfygDhzJwaAKHJvDF/vei9u7ZMfv0gUMfOGqJD5XgUAkOleBQCQ6V4FAJDpXg8P0PreDQCg6t4KgB+KK+VgXd4NANvqiX
9TDWw1gPqpQPPeH89AT7TK+agUtb+OIWj3jFFEtsUa+l19Jr6bW0f+8PX9Rr6bX0WnptvbZeW6/tZ219t75b363X0fJoeXx7fHt9
cvW6Pr/ah6uFz0PL8DvE71u/Q/odUsvUMn1bflb5vHxerlyuUNq0n9vatM9Hy9Fy/MT5fa69EVbbfGkFV1XzpRJcKsGlElwqwaUP
XPrAVcl8qQSXSnCpBJdKcCkDlzJwqQGXGnCpAZcacKkBlwJwKQBXDcClAFw1AJcOcCkAlwJwVQJcOsClA1yVAJcacCkAlwJwKQCX
AnApAFcNwFUDcFU1X2rApQNcOsClA1w6wFUDcKkBlxpwqQGXGnCpAZcacKkBlxpwqQGXGnCx/0X9F+9fdH8R/eXmX27+xfUXy18s
f/H7xe8Xv19O/UXllwt/+e8XiV8kfpH4ReIXfV8++1WHfJH4ReIXg18MfjH4F13NOKtDvjz3i7gv5/3i7ou7v+g6xhN9X/R91SF/
cf17US8jzJG/HPmLxC8Sv3bdXjx+8fhF4heJXwx+Mfi1A/ci8YvBLwa/GPxi8IvBLwa/GPxi8IvBLwa/GPxi8Lt/I+9ewN0Xd1/c
fXH3xd2XU3/R90XfF3dfrH2x9kXZF2VflH1x9MXRF0dfBH1R80XNFzVfvHyR8sXIFx1fRHzt3v3i71tXMDuI+CLii4gvIr48+ot8
L/K9mPei3YtzL869OPfi3ItzL869Kp+vmucPLrU08uqfLzf/cvO/6N9l5Hn6FxdfFdEXHV90fPn7V0X0VRF9ef2X13+x8+XyXxXR
l79/8fK1w/ei5ouaL2q+qPni5cvfv0j5cvavKuiLly8f/6Lmq+b5YueLnS92vqj5qna+qPny9y9P/3LzL7/+8usvmr44+otaGmEc
fbHztZP38uW/+PvWb2tVY+qLqS+mvvbwXn795ddffH3x9eXaf1EbY4i1L9a+WPuGlYy1L9f+Yu3Ltb9c+4u1L9a+WPti7Yu1L4/+
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
Th5r8lgTmycqT1SeqDxReeLxxOCJwb/oOnKXM6YSiSf6Ttyddk8n+k70nXZPJwZPDJ7oO50xlbzXRN+JuxN3J+JOxJ1YO+2JTk5r
8lhTDXPi7nRCcqLvxN3JY837G0NrHmsn1k7uavJVE2unSuZE3MldTb5q8lUTg6ca5rQbOpF4cldT9XI6zyqRePJY0wnJib6Tu5rc
1XQSciLuxNqJtVN9ciLuRNyJuNNpV4m7E3cn4k6UndzVxNqpVjl5rIm7U8Vyou9E34m+08lXibUTaye+TmSdyDoxdWLqxNTJe03e
a/JeE2Wn+uRE2YmpE1Mnpk77kdOZV4mvE1+nGubkzybKTmSdyDp5ssmTTZ5sounE0aluOXmvyXtNBJ0IOhF0IujkuiaCTgSdCDpV
LyeCTgSdqpcTRycHNtF04ujkwKYa5uTDJh82+bCJshNfJ75OfJ3O0UpMnTg6kXLi4kTEaUdwYuHEv4l/E/8m/k38+8X49+KvZYkt
uppR4rSmPbyJcNMe3sS5iXMT5ybOTYSbqDZ5r8l7TYSbCDfVJyc3NtFuot1Eu4lzE+Emwk2Emwg3EW6qSU6cmzg3EW5yZhPnJk82
VSOnauTkzCbmTcybmDcxb3JpE/kmlza5tImCEwUnlzaxcOLfVJ+cKDhRcKLgRL6JfBPzpjrkRL6pDjnxb/JtEwUnCk4UnCg4nfGb
WDhRcKLgRMFpV29i4cTCqSY5ObzJ200snFg4sXCi4ETBiX8T/ybyTcybmDcxb2LexLyJdhPtJs5NnJs4N3FucnsT7SbaTbSbaDfR
buLcRLiJcBPhJrZNbJvYNlFt4tnEs4lnk+ebeDbxbOLZRLKJZBPJJpJNJJsYNtFr4tbk5yZuTdya6pCTn5sYNjFsYtjEsKkOOTm8
qQ75i9qbNQ5votrk8CaHNxFuItxEuIlwE+Emwk2Em7zdxLmJcxPnJs5NFciJdhPtJtpNtJu83US7ydtNrm5i3lRvnLzdxL+JfxP/
Joc3ObyJhRMLJ4c3EXEi4kTEiYiTw5u4OHFxcnUTFycuTq7uF1/OQcSJiBMLJxZOFJwoOFFwouDEv4l/k3ub+DeRb/Jtk2+bKDhR
cOHf4tsW/i38W3zb4tgWr7ZQcCHfQr7Fky38WzzZQsHFky0sXJzZwsLFjS1EXIi4UHCh4ELBhYLLCWOFhQsLlzrh4s8WLi6ebCHi
4sYWH7bQcaHjwsXFgS10XPYjF0YujFy818LIhZGL61pc18LLhZQLKRdSLqRcSLmQcnFdCy8XXi5Oa6kxLh5rYefisRZ3tdQeF4+1
1B4Xp7WQdWHqwtRlh3Jh6lJ1XMi6kHUh60LWhaxLBXLh61KHXOqQC2sXr7awdmHtwtqFtcsO5ULcxcMtHm6h70Lfhb6Lk1t2KxcS
LwxenNxC4oXEC4kXV7fweKlSLt5uYfNC5YXKy27lwualVrnUKhdOL5xeOL1wenF+C62XncuF1gutl7rlUrdc6pYLuRdmL8xeapUL
uRePuPB78YjLbuXC74XfC78Xci/MXvYpF3e4kHvZoVz4vfB7qWcu9cxlt3LZoVy4vnB98ZEL3ReuL1xfuL7sSi50X+i+7E0ujF/2
JhfSL6RfSL+QfiH9QvrFZS4u8xfz34taml/+cvGXC/uX6ujC/oX9S3V0Yf/C/oX9S3V0UQCKE110gKIDlN3KRQ0oOkDRAUrtdFED
ihpQ1ICiBhQ1oKgBRQcobnVxq4saUNSAogaUqumiBhQ1oKgBRQ0oakBRA4oaUNSAUkdddICiAxQdoOgApYK66ABFByg6QNEBSu10
UQOKGlDUgOJ6FzWgqAFFDShqQKmgLppA0QSKGlAUgKIAFAWgKABFASgKQFEAigJQFICiABQFoCgARQEoCkBRAIoCUBSAogAUBaAo
AKXuuugAZedyqcEuzntRBooyUJSBogwUZaAoA0UZKMpAqc0u+kDRB0qddlEJikpQVIKiEhSVoKgEZS9z0QqKd1+8++LdF/WgqAfF
wS8aQtnRXJSEoiQUH7/oCaW6u7j5xc0vCkNRGEqld1EYisJQFIaiMJRK73LGddndXKq+i/JQar+L/lD0h3KeW1EhigpRVIhSIVAq
BIoiUSrAiy5RdImiS5RqgaJOlGqBolGUaoGiVBSloigVRakoSkVRKkr9QNErSv1AUS1KrXipFS+1BOVcuKJmlLqCommUfdZF2SjK
RtltXWrIi8pRVI5yFlzRNEqNQdE0So1BqTEo+kbRN77Y/17Uy5qxI7toHaX2oCgepfag1B6UqoOifhT1o6gfRf0o6kdRP0rtQVE/
Su1B0UCKBlJqD4oGUjSQclJcqUAoFelFFSmqSKlDKNpIqUsvdemlLr1UJhS1pNQnFM2k1KUX5aQoJ0UnKfUJRScplQlFLSlqSalM
KJpJqU8oykmpSC/6SdFPin5S9JNSnV70k3KOXFFOSiVDqVEvNQxFOSmaSdFMSvVCOTuu6CdFPyl1C6VuodQtFC2lqCilRr3UqJdT
40qletFViq5SdJWiqxRdpegqRVcp9QylkqFUMhSNpWgsRWMpGkvRWIrGUhSVUslQdoWXs+NKVUOpaih6S9FbSlVD0VtKlXvZIV60
l1LxXhSYUttQFJiiwBTtpZwOVyoZit5Sat2L6lJUl6K6FNWl6C1Fbyl6S6ltKKpLqW0otQ1FgSmqS6ltKNpLqYQvlfClzqFUOJRK
+FLhUJSZosyUCoeiz5Q6h1LnUFSaotIUlaaoNEWlKcpMqW0o+kzRZ4o+U5SZUttQtJeitxS9pegtpZKh6C2lhqHUKpRahVKrUOoT
igJTqhGKAlMq4YsOU2oSSk1C0WSKJlMqEIoCUxSYUgNfag9K7UGpPSi1B6X2oFQdFH2m1B4UZeaL7z2HJlM0maK9FO2lqC5FdSmq
S6krKHpLqSsolfBFeymqS9FbitJSagmK0lI0llJLUJSWUlFQNJaiqBQVpVS5F/2kKCeliqDoJ0U/KXu6i3JS6gdK/UDRT4p+Uqrc
i4pS9JOinJS920UVKUpIUUKKBlLqAYoSUpSQUglQvP6ieBSvv+geResoWkfx94unX1SOonIUlaPoG0XfKH59qWAvmkZRM4pfX9SM
4ssXBaMoGMWRL6pFceGLRlE0iqJOFBWiqBBFfyj6Q1EeivJQasuL/lD0h6I8FM2haA5FcyhqQ1Ebyg7oojmUevJSQ150hqIwFIWh
VJIXnaHoDEVnKDpD0RmKzlAUhqIwFG2haAtFSSgaQtEQioZQ1IPioRfFoFSAF62gqARFHyiaQFEAigNedICiAxQFoOY3Ym/9tP3C
TQFoDnhTABr7Nwe8sX+r024KQHPAW4V2UwOaGtBqs5sa0BSApgA0BaBVZTcdoOkAbUdwUwOaM96c8aYGNDWgKQBNAWjs39zw5oY3
9m/U36i/UX/zxBv7t7rrxviN7hu/N35vzN6YvTF787hbdXQj90bujdwbubfq6Mbvjd8bszdmb254c8AbrX/xyzmN0BuhN0JvhN7Y
vLF5Y/Pmgzc2b7uDG5U3Km8k3ui70Xero24OeKPvRt+NvhtxN9ZurN0c8EbZjbIbZTe+bmTdaLrRdNsF3BzwRtaNrBtZN7JuTN08
8UbWzRNvZN04ujngjaMbQTd2bq53Y+fGzo2dGzs3Xm5neTVSbqTcGLl5342OGx03Om5c3Ii4EXEj4kbEjYUbCzcWbizcWLhVXDcf
vPngjYgbETcibkTc3PDGxY2LGxc3Im5E3Ii4EXGj4Ma/zQdv/NvIt5FvI9/GvK1Cu5FvI9/mgzf+bfzb+Ld54o2CGwU3N7xRcOPf
xr+Nfxv/Nv5t/Nv4t7nhjYJbLXdzxhsRNyJuRNyIuLFwY+HGwo2CG/k2H7yRbyPfRr6NfBv5Nge8MW9zwJsD3vi38W/j30a+jXwb
+TbmbczbaLfRbuPcxrmNcBvbNrZtVNuotlFto9rGs41hG702Ym3E2ii18Wnj08anjUkbkzYmbUzaaLTRaKPRxqGNQxuHNgJt7NlI
szFmY8xGl40uG102fmy02AixEWIjxEaIjRC/OF/OQYiNEBshNkJsbNjYsLFhY8NGhY0KGxU2KmxU2KiwUWGjwsaDjQcbDzYSbH53
q0JvfnfzuxshNkJshNgIsRFi21/ceLDxYOPB5oA3KmxU2KiwUWHbd9xOFG/OeCPExoZtJ3IjxEaIjQrbruRGhY0KmyfeqLDxYOPB
xoONBxsPNh5sPNhIsJFgc8wbDzYebDzYeLAxYGPA5p63qvV2rnirWm9s2NiwOemNEBshNkJshNgIsbFhY8PGho0KGw82HmyuevPT
m5/e2LBRYaPC5q23KvfmsLfzxpvP3mix+eyt4r1VvDdybOTYmLHVujdmbM57I8dGjo0cmwvf6t4bPzZ+bPzYyLGRY+PExomNE5sL
32ix0WKjxUaLjRYbLTZabLTYHPnmxTdybJXwjR8bOTZybOTYyLGRYyPHVg/fTh1vFNkostXGN5ZsLNlYsrFkY8nGku3MsebmN6Js
bn5z81vNfPP0m6ffKudbzXzbW914s/Fm483Gm403G2823my82Xiz8WbjzcabzeVvvNl4s/Fmq6hv1Nmos1Fnq65v7NnqARp7Nups
1Nmo84vx70UtzS/2bOzZ2LOxZ2PPVmnfCLQRaCPQRqCNQFuFQOPQViHQKgTaXytuZNqqBVq1QKsWaNUCjVhbtUCrFmh/ubhV5jeS
bSTbSLZV5jeebZX5rZagsW07D60RbqvSb9UF7azyVqXfyLeRbyPfdjZaq0BotfqNhVt9fqtGaETciLhV6TcublzciLjtE29c3Li4
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
o+SOkjtK7ii5o+SOkjtK7ii5o+SOkjtK7ii5o+SOkjtK7ii5o+SOkjtK7ii5o+SOkjtK7ii5o+SOkjtK7ii5o+SOkjtK7rC2n9xK
bSW20lpJrZRWDyDPH4+f39NnXhXoi/7//abzPK/wvvTit4bfg9dz12PXU3eeZTLPMfH4nVfDN8808Rz2GPYUnmebeBLPM03m1e7N
M07mVe55OHs2e53wNuFlwruEVwlvEl4kvEd4jfAW4SVijt/vvh739bivx3097utxX494Pd4d+Eow5/lQXoK8A80rv/Qe5DXIW5CX
IO9ATJ83CO8GfVLMi0e84u/zFEts8eXMJ8W8+BvMFN/Qvyz4xHRaOim9Xz0WOZ2aTkzvV4vVb6MbVZ2oHl5ZX5x/IbGGtBlktCCj
BRktyGhBRgvp8UXLRAopKaSkkJJCSgopKaSkkJJCSgopKaSkkJJCSgopKaSkkJJCSgopKaSkkJJCSgopKaSkkJJCSgopKaSkkJJC
SgopKaSkkJJCSgppKaSlkJZCWgppKaSlkJZCWgppKaSlkJZCWgppKaSlkJZCWgppKaSlkJZCWgppKaSlkJZCWgppKaSlkJZCWgpp
KaSlkJZCWgppKaSlkJZCWgppKaSlkJZCWgppKcRaIuu9qK8U0lJISyEthbQU0lJISyEthbQU8gTAdMzXi1s8HnPj/0NMscQWffvN
WjoW7EV9x9XmivqOvqPv6Duv73uLSAeIvej95O+IVwwxxRJb1Hfpu/T9vdssfZe+S9+l79J36bv03fpufbe+W9+t79Z367v13fpu
fY++R9+j79H36Hv0PfoefY++R9+r79X36nv1vfpefa++V9+r79U39PU68vLvi/qGvqFv6Bv6hr6hb+qb+qa+qa9XmpeMX9Q39U19
U9/St/St3zvkb22815P22GmPnfbYaa+sLRe1XNRyUctFLRe1XNRyUctFLRe1XNRyUctFLRe1XNRyUctFLRe1XNRyUctFLRe1XNRy
UctFLRe1XNRyUctFLRe1XNRyUctFLRe1XNRyUctFLRe1XNRyUctFLRe1XDRy0chFIxeNXDRy0chFIxeNXDRy0chFIxeNXDRy0chF
IxeNXDRy0chFIxeNXDRy0chFIxeNXDRy0chFIxeNXDRy0chFIxeNXDRy0chFIxeNXDRy0chFIxeNXDRy0chFIxeNXDRy0chFIxeN
XDRy0SuZW+9vUIlIIbz2RoolIpHQMpEF8Hlr+EV9U9/UN/VNfQHQW8PLn2tf/lz7i/qWvqVv6Vv6lr6lb+nb+ra+rW/r2/q2vq1v
6wvKDih72wFe1Hf0HX1H399rPsI6COsgrIOwLsK6COsirIuwLqp6JR8vplhii/qisIvCXuHH8mfilz8Tv/yZ+OXPxC9/Jv5FfZe+
W18k+LYDLH8yfvmT8cufjF/+ZPyL+m59t75H36Ovt6Pr7eh6O3pbBoKwFoS1IKwFYS0Iay/+2ng7epmEyBZEtnce0t+/dw6T9eb5
NZ5f4xV45KKRi0YuGrlo5KKRi0YuGrlo5KKRi0YuGrlo5KKRi0YuGrlo5KKRi0YuGrlo5KKRi0YuGrlo5KKRi0YuGrlo5KKRi0Yu
Grlo5KKRi0YuGrlo5KKRi0YuGrlo5KKRi0YuGrlo5KJntQSrJVgtL27xiFcMMcUSW9R36bv0XfoufZe+S9+l79J36bv03fpufbe+
W9+t79Z367v13fpufY++R9+j79H36GsVPYMmGDQv6gtY/gDLn3fsP8Dyyk2DZRMsm/X+WsCLYa2GtRrWqlx05aIrF1256MpFVy66
ctGVi65cdOWiKxdduejKRVcuunLRlYuuXHTloisXXbnoykVXLrpy0ZWLrlx05aIrF1256MpFVy66ctGVi65cdOWiKxdduejKRVcu
unLRlYuuXHTloisXXbnoykVXLrpyUchFIReFXBRyUchFIReFXBRyUchFIReFXBRyUchFIReFXBRyUchFIReFXBRyUchFIReFXBRy
UchFIReFXBRyUchFIReFXBRyUchFIReFVfRKLoNoH0T7INoH0f5F+Sfln+x/weYLNt+L1tu13mSzP9nsTzb7k83+ZLM/2exPNvuT
zf5ksz/Z7BUzB/sv2H/B/gv2X7D/XtTXb/JMwGACBhPwRX1L39K39C19S9/St/QtfVvf1rf1bX1b39a39W19W9/Wd/QdfUff0Xf0
HX1H39F39JWLlly05KIlFy25aMlFSy5actGSi5ZctOSiJRctuWjJRUsuWnLRkouWXLTkoiUXLbloyUVLLlpy0ZKLlly05KIlFy25
aMlFSy5actGSi5ZctOSiZRUtuWjJRUsuWnLRkouWXPQKtt873HuDe+9v7+3tvbu9N7f33vbe2t4723tje+9r723tvau9N7X3nvbe
0t472ns3m58m8nSMp2A8zeQ/72OspXdSoGerVbGtim1VbKtiWxXPbHrvZO+N7L2Pvbex9y72nqrvmfqeqO95+p6m71n6nqTvOfqe
ou8Z+p6g7/n5npvvqfmeme+J+Z6X72k5//9N/FZW3bbqtlW3rbpt1f0Y863PdOB5OuQ8HXL+os/793mIKT4q+UOdf6jztw631bv/
39KV+7qy9q39bzR+1ykt3SPbOt/W+bbOt3W+rfP9u751vq3zj2r/Bcs4WMbBMg6WcbCMg2UcLONgGQfLOFjGL+orVyy5YskVS65Y
csWSK5ZcseSKJVcsuWLJFUuuWHLFkiuWXLHkimUullWxrIplVSzjsKyKZVUs47DM2jJry6wts7bM2jJrS65YRnvJFUuuWMZwGcNl
DJcxXMZwGcNlDJcxXHLFkiuWXLHkiiVXbLliyxVbrthyxZYrtlyx5YotV2y5YssVW67YcsWWK7ZcseWKLVdsuWLLFVuu2HLFliu2
XLHlii1XbLliyxVbrthyxZYr9v4Jp/rKFVuu2HLF/j1xfm+/csU7ZG+9V5X13lTWe1FZ7z1lvdeU5S3lvSKt99RZ76Gz3jNnvUfO
ek+c9R446z1v1nvcrPe0We9hs96zZr1HzXpPmvUeNOs9Z9Z7zKz3lFnvIbPeM2a9R8x6T5j1HjDrPV/We7ys93RZv4fLNkHbBG0T
tE3QMUHHBB0TdEzQMUHHBB0TdEzQMUHHBDGJ3lNrvRtyvWfWerfjenfjeglhvafBeklhvft3vdt3veywXnJY7/5e7/ZeLzOslxjW
yxfrpYv1MsR6CWK9/LBeeljvKbXeQ2q9Z9R6j6j1nlDrPaDWez6t93ha7+m03sNp/Z5Nxyo6VtFZv0/8A62iYxUdq+hYRccqOlbR
sYqOVXT2+fcsiWdIPAPBjhYbWuxGsZVEjXtfsv08/ff7rfiqbFV+BGOBi0BFJWlSNEkSE3K35P3L3j57+VsCl8FfCn+uwDxXYJ4r
MM8VmOcKzHMF5rkC81yBea7APFdgniU9z5GeZ0jP86Pn2dHz3Oh5ZvQ8L3qeFT3PiZ5nRM/zoefZ0PNc6Hkm9DwPep4FPc+Bnvdv
m+cYzzOM5/nF8+zieW7xPLN4nlc8zyqe5xTPM4rn+cTzbOJ5LvE8k3ieIzzPEJ7nB096UnlUjefS9+2zmuY5TfNsGcLnc9oguNfP
/0+j2/243Y/b/bjdz/59a5Ld7sftftzux+1+fqdi//eShX0J9h76G+r/qetQJ+FvAv/3+3vk+d///yLef/YufNng9xcL/v77/VW1
+e9Bw4OFBwm/c/T9RfL/+PO8kfcb++2eaPq7y7wYHC8kxwvJYUAE/An4E/An4E8Yi4A/AX8C/gT8CfgT8CfgT8CfgD8BfwL+BPwJ
+BPwJ+BPwJ+APwF/Av4E/An4E/An4E/An4A/AX8C/gT8CfgT8Cfgj9oGTlCwgoIXFMyg4AYFOyj4QcEQCo5QsISCJxTMreBuBXsr
+FvB4AoOV7C4gscVTK4X179v9fwMdKhyoMqBKgeqHKhyoMqBKgeqvFep7xXzZaLzHn/fi+YDpfPSw4tXrBfD5/mLIaboJYc8GwTz
+OXbZ/r9eLF//9BnAO7/f+ff5tXhJ5yF9fF25rxoTK+xfs+nvX+g+H+E9gpF0P8j6P8R9BdBfxH0F0F/EfQXQX8R9Jffb5HyFyl/
kfIXKX8R8RcRfxHxFxF/EfEXEX8R8RcRfxHxFxF/EfEXEX8R8RcRf5HvF/l+ke8XLDzugW0VbqtwW4XbKtxW4bYKt1W4rcJtFe7+
VWDoaxVuLzTHC9PxwnS8MB0vTMcL0/mtUS9MxwvT8cJ0vDAdL0zHC9OTC+fd8vPkgXk3/jxxYK7395drnzIwTxiYpwvMm+Z5qsA8
UWCeJjBPEpinCMwTBObpAfPkgHlqwDwxYK4fNK/HK4F4QsA8HWCeDDBPBZgnAszTAOZJAPMUgHkCwDz+n5dx5i26efA/b+HNQ/95
5D8P/Odx/zzsn0f986B/HvPPQ/55xD8P+Ofx/jzcn0f782B/HuvPQ/15pD8P9Odx/jzMn0f58yB/HuPPQ/x5hD9vH9O8AzDm7WWa
98c75u1nmrfI563rect63o6meRbsPAt2ngU78csPv9zqZfX85ta70Jnft+bNu9D1LnS9C13vQtfLw/UudL0LXe9C96/+bZ9vn7/4
KsTs1Bs79cZOvbFTb+zUGzv1xpktY4/e2Hk3dt6NPXfjDJax527suRt77sZuu7HPbuyzG/vsxj67cQbL2G039tmNk1jGbruxz27s
sxsnsYyTWMaeu/HsGn//ZTy3xj47i3Zbq9ti3RbqtlK3pbqty21NbotyW5DbitxW47YctwW4rcBtCW5rcFt629rbFt+2+rblt62/
bQFuK3Bbgtsa3Bbhtgq3ZbgtwW0NbutvW3vb4ttW37b8tqW3rb1t8W2rb1t+2/rbFuC2ArfVty2/bf1tC3BbgdsS3Nbgtgi3Vbgt
w20dflHFo5NYvNuFk5fCyUvh5KVw8lI4eSmcvBROXgonL4WTl8LJS+HkpXDyUjh5KZy8FE5eCicvhZOXwslL4eSlcPJSOHkpnLwU
Tl4KJy+Fk5fCyUvh5KVw8lI4eSmcvBROXgonL4WTl8LJS+HkpXDyUjh5KZy8FE5eCicvhZOXwslL4eSlcPJSOHkpnLwUTl4KJy+F
k5fCyUvh5KVw8lI4eSmcvBROXgonL4WTl8LJS+HkpXDyUjh5KZy8FE5eCicvhZOXwslL4eSlcPJSOHkpnLwUTl4KJy+Fk5fCyUvh
5KVw8lI4eSmcvBROXgonL72o79Z367v13fpufY++R9+j79H36Hv0Pfqel3PsxEQEGxJsTLBBwUYFGxZsXLCBwUYGGxpsbLBxwQYG
GxlsaLCxwcYFGxhsULABwQYDGw1sJLChwIYBGwe8+GvpmvKA3Zdj9+XYfTl2X47dl+M8n7H7EkRsALERxIYQG0NsELFRxEYQGz1s
+PCib9U522U5dlmO/ZXjPJ+xv3Lsrxz7K8f+ShV9L2qjztmeynGqz9hZOfZUjj2VYzelwr+tBvBFP0u+dcbyOGN57KMcOyjHDko4
s/HMi9qbEbsmx67JsWtSseGLrmwu7JEceyQVJW71iV80L3ZHjn2RY1/k2Bc59kWOWr93updo7V1r71p719q71p68dOWlKy9deenK
S1deuvLSlZeuvHTlpSsvXXnpyktXXrry0pWXrrx05aUrL1156cpLV1668tKVl668dOWlKy9deenKS1deuvLSlZeuvHTlpSsvXXnp
yktXXrry0pWXrrx05aUrL93fWMlLV1668tKVl668dOWlKy9deenKS1deuvLSlZdCXgp5KeSlkJdCXgp5KeSlkJe88ztJLJwkFk4S
CyeJvaivvBTyUshLIS+FvBTyUshLIS+FvBTyUshLIS+FvBTyUshLIS+FvPQ9E/+9lWOluaPtqB07aseO2rGjduyoHTtqx47asaMW
sm+4/uIRr1ji79t3Zbtox87ZsXN27JwdO2fHztmxc3bsnB07Z8fO2bFbdpw3NfbMjj2zY8/sOHVq7Jkde2bHPlnSwYu+9Ry3H3bs
hB07Ycd5U2P369j9Ona/jt2vY9/r2Pc69r2Ofa9jx+vY8Tp2vI4dr+PE77Hvdex7Hftex77Xse917Hsd+17Hvtex73Xsex37Xse+
13EG+DixauyBHed+j7OqFEG/6Dpmx77Xcdb32P069Zsdb2XOrRr7Ycd+2LEfduyHHfthx37Ycfr3OMNq7Iodu2LHrtixH3bsh53+
rUbPtfBcY9s51y6caxfOtXvx19Lak5dCXgp5KeSlkJdCXgp5yRu+U+/CqXfh1Ltw6l049e5FfeUlxZbOvgtn34Wz78LZd+Hsu3D2
3Yv6ykshL4W8ZK+HE/DCCXjhBLxwAt6L+spL9no4E+9FfeUlez2cjBdOxgsn44WT8cLJeC/qKy/RQ8peD2flhbPyXtRXXrLXw4l5
4cS8cGLei/rKS/Z6OD3vxdfXXg9n6L24xSNeMcQUS2xRX3nJXg9n7oUz98KZe+HMvXDm3ov6Wgn2ejh5L5y8F07eCyfvhZP3Xox/
b+VYY+5xJ8aPXdVjP/U4IW2ckDZ2VY/91GM/9dhPPXZSj53UYw/12D09dk+PM9PGWfHjrPhxfto4P23srR4nxo8d1uMstbHDepyi
Ns6KH2epjd3W46z4cVb8OCt+7L8e56qNs+LHLuyxC3vswh67sMeJ8WMv9viL4WNH9tiRPXZkjx3ZY0f22JE9dmSPvdhjL/bYiz32
Yo+92OMk+XGS/DilbfxNtLE7e+zOHruzx9nyY4/22KM99miPPdrjnPmxU3ucMz9OeBsnvI1z5scJb+OE+XHO29jNPf5u2tjTPfZ0
jz3dY0/32M09znwbp72NE97G3u2xd3vs3R57t8fe7Zmf/mrG7dcep72NkrayV6jsFXKKYzjFMZzi+KK1Jy/ZK+QsxxetW3nJXiHn
OoZzHcO5ji/qKy/ZK+R0xxf1lZfsFXLGYzjjMZzxGM54DGc8vqivvGSvkFMfw6mP4dTHcOpjOPXxRX3lJftIyj6Sso/EaZAv6isv
2UdS9pE4JfJFfeUl+0jKPhKnR4bTI8PpkS/qKy/ZR1L2kThP8kV95SX7SOr3bmkfSdlHUvaROHMynDkZzpx8UV95yT4Sp1C+qK+8
ZB9J2UfiXMpwLuWLVwwxxRJb1Fdeso+k7CMp+0jKPhKnVoZTK8OplS/qu97eYfv9x07/cTbg2OM/9viPv0QwdvqPcwLHXyIY5wSO
v0Ew/gbBOAFg7P0fe//H3v+x93/s/R97/8fe/7H3f/z1gbHrf+z3Hzv9x07/sdN//E35sdN/7PEff4Nv7PEfe/zHHv+xx3/s8R+7
+8fu/rGjf15p2fl7xWMvpjgvfiP24hFDLFH7pc2Xk1/Ucmu5tdyus7U5vj2+Pf+j6U6SJNdxIIDu6xR9BJHgIN3/Yp14Hn9DK8uS
IiMlAiThA/yWck35tPJp5crl05b/XT5huWa5Zrlmu+Yvdnr0ydv12/Xb9duVx5XHlceVx3c4vsNx13H9cf11/XX9dc11zfXJ15XX
N3ld+bry9cmv61/Xm/90SJcO6dIhcUPd3FA3N9TNDXVzQ+3R3JOX6JB4ovboXnmJDunSIV06JC6pm0tqj+6Vl+iQLh3SpUO6dEiX
Domf6uan2qN75SU6JK6qPbpXXqJD4rO6+axuPqubz+rms/o3ykvEKZc4hedqj+6Vl4hT+K9u/qs9uldeIk7hwtqje+Ul4hSOrD26
V14iTuHR2qN75SXilEuccolTeLdu3q09uldeIk65xCmXOIWb6+bm2qN75SXiFM6um7Pr5uza4zBOYxmXcRuP8Rpfo3vlJeKUS5zy
N9a/njmZXWbjZ459Ztdn3n7m2Gc2fn1NYzI9LuM19ic09tKjn4/8xPWitdGVHqexZ+wQlaPyb9eLx6bB9Oh/ReUQfWPn38foehE3
RNwQcUOsDfE1xNcQX01W6dH/iq8hvob4GmJqiKPhaQxPY3gaTTvp0ff5XPO5SwYbnkmTTHqcxjJuY/+W6clMmW16PlNma+pIj9fo
czyl6SlNmW16VlNma6JIj/17myLSo08r/yuzTU+ydXY9+gTZbMpmU+5qgnSPPlnump7nlK+mZzhlqsYEe3SN5zk9wylTTdFB3HSJ
m/gJ92juWdeImzgM92juyUvETdyGe3SvvETcxH948x/e/Ic3/+Ee3SsvETdd4qZL3HSJmy5x0yVu4lS8ORVvTsWbU3GP7pWXiJu4
Fm+uxT26V14ibrrETXyMNx/jzce4R/fKS4Qql1DlEqpcQpVLqHIJVXgdb17Hm9dxj+6VlwhVLqEK3+Me3SsvEapcQhV+yD26V14i
VLmEKryRe3SvvESowie5R/fKS4Qql1CFf3KP7pWXCFUuocolVLmEKtyVe3SvvESocglVLqEK7+XNe7nHbTzG+69njhllXWss9G+0
uk2ROK1ujYX2aAa+rhebU2xOsTnF5pSppticMtUUoVOEThFaslaJzZK7SoSWCC0ZrOxASrQ2XafHaXSXyC0xW2K2ZLmS30rklsgt
kYtH8ZT4LfFb4rfsT0r8ll0K1sVTorhEccmEJYpLDiw7kxLFZU9SdiMloktEl9xYIrrkxpIbS1yXuC77kBLdJbpLdDfy0qO75Myy
JynxXuK9ZM6SOcsbLG+wvMHyBssbLO+u7E/Kuytvrby18tbKKlPeXcmu5Q2WN1jeYHmDS3Zd3iCf0tGx//fpvXdFjJ9bT42hgjdU
tMbJ5+zMor/rV9ap3s9XLe89Z+Tm0xRVbMWTzTniL7f2ye7h8LnTmZQrS108m/R69ltmuoZl7YO0Pr8+1PEC6u/f7RP+voPd+6Ma
P9M9/IlbZv/tBS3dfFM3354B3xxdffqbf71zft6sj13jWryhiB9LP9mKT922XkyVN4KmomivGcxirsy99KDM3Ou7VPszDw+nIzLJ
Gum9G5ctvogbBrGtdGWex8/qcCslumnefXfT5i3zxJeGN9rQcWZY00khKl3AVro/x0X/8YSb2lpEEN1lr59tn9NrNTpQ8WF+uoZT
+rb/RVG/2ems0ez8v59zo2rK3r+eOd6OHcsS6UuMLzG+rL9LFC8xu8TsstouMbvE7BKzy8li+VZL/C7xu6y/S/wuz3mJ4kY3enSX
vc0S10tEL7G8zNUllpfV2fN5llhedjhLFC9RvMTvEr9L5C6Ru0TrEqdLhC4RukToEqFLjl3idInTZf+z5NslZpd8u0TrEq1LtC7R
ukTokl23CN0idMuxW3xtT3uLuy2vbk97y6hbvGx7oS2vbs9/y5/bW9gzP/c5nv/2/Lfnvz3/7cnvyjV+l+e/Pf/t+W/PXxw9Wy7d
9kXb898y6rbP3N6FbPBsb6SrtX/Zo59ePEu9u4m3Vojo8xe5nJr2r291P7HdZ+31xEstPbvzLvQ7WCr5g/fRaLJ96f5ZDRh0DPYT
eJ/8xjgCdZab/CRX3CC/ZJU+a7flaEdBugz3cx44BtX7mSK06XO3zgv9Ho+ZpuNk6aL4Fxs6VnT1tXRe+/uErqQl4p7eM/wlzsfT
0EMBNqoeO9VpW0fYf9d/u+K/vygO1Vu9YuketRon+vtLO293+7G/79zE6dKdsL9sj733K31Ci9Cm0rF9c0h78FgG3sgoLMc+qZX+
pKUz6d+nyUjQ1SWWy55/tUxiOVO0Pml0fqjshB9XdtaK0+CJQ/iHIdk1jQ0JfdRgH7XEg6n4tYzub8fQvz1uWi2K/9czxxwTxVsU
byvyFr9b5G6Ru0Xuttpu8ZvMvEXxttpusbzNny2Wt1jeYnmL5S2WtyjeoniL4i1yt8i11jz7y8/70474PeL3OMUcUXzE7xG/R7Y8
4veI3yN+j/g94vfYF52R632y3ZEs/Ry7oyOuj4g+susR10dcH+/iiOVT+V+fI4qPKD5m4xHFRxQfUXxE8RHFR/weufTYFx3v4ngX
x7s43sWRV4890pFdj7dz7JGOHHu8qWOPdLypY3d0nCuPt3a8teOtHW/teGvHWzve1/G+jvd15NvjTR1v6ry50neTbzkErvjveWIF
3duwOeYDle4VTgd/sdBsgcGRb3svr0rRwCh4+MWtprL/rdodU6XeVb+uDXob9amnwi/auGGDu9roTPUXO10nj7gv1b/1pGeW+d81
h0q3yoVTsYOMNHr+txanK3rvf3bLTHqPkTmPpdyfkP50y/pbV9ZV74rr4LCGrvT2wpVa8L4Vd9yukPz9Vf1US0Z90pmxT6Z/OaL3
MLsrJH+/I10gK93k+2nIYMOec+Cc2KP+Rbq+M6qdZVanZ/rGgRnNQ/jLt/1mi9f32dZEOMXGr0g2Lujz8rQ3z14mGN13O2tE7+Lw
T7Y1bjUiUPQO1TZhnQPteThSpmbCb79I8/62dTMMuvmvZ455aPd7vux4y7iM23iM+d+eb1d0X3F9xfUV11dcXyvydaK54vfO/Pwa
fY632fXDHl0plu2WnyuKryi+dj5X5F7RekWrHfJjpj3e/nNF6BWbV2zek5+7V+a84vGKxysSr0i8Yu3KilesXbF2xdoVa9d55Io1
a81zPb0rQ15v07x6Xrnx9SRfT/L19F5P77W3eT3DV4Z8PUNz73k9w1dufOXGV2585cZXbnzlxtdzfj3n13N+Pc9XbnztebITfiv/
65Nly1e2fO15Xs/5lS1zXng981fOfD35d+V638RbgDBOa3RhWC21u3QJyVowYWFDl8P9pSreeNmAyGdfd3hm7pnspP8198KZbjvY
j8upZ2COscGp9FvfvEA3xsLGw1zp72A/pqftX3BvO6XOCYUbdjh8rvSM8671aOhvsq34dBT2M66c6dbnBIFR/vdN+nNSzx/6k643
HRP6KW1shK1qd7oeUvhsf1fm3lRBO++xXum9nP5cy/5KpmpeZaERV7dR+duB+LkTeueWPsENZ0lclJOuSc6nj+5dT+OVf9mvd30l
hxQ+7VZLuakKtvDqL5f2+jV4hy5zZshvqYuSWve6f+Xwzpa6xgy/8fnSybTXnSHDHGcBXYHq133AmTq9J853n389c8w08fuKX7vK
57Xavjs7Xv9rbX1PTt/+VxS/ovgVv69187VuvtbN14r5vtmFuvfN/7pXFL/OKa9Ytr99vKnnFcuf+P3sbT5R/HkOn0z4Pcnbr/Fz
0nS9WPbkn08sf2L5E8WfKP5E8SdmPzH7yY2f3Pg5OX5y4yeWv5xkxe8nfj+R+8mQn/j9xO8nfj/x+9nzfKL4E8WfKP5E8SeKE4+f
84tzwfN5F5+z5Gf/83kjnzfyya6f/c/n7Xz2PJ+383k7n7fzya5OJc/nHX1y7Ge389ntfN7XZ3f6eWuft/bJwJ93Z76ZYz36PsnD
Hcv/7eJ6td32k6ycWjLR2WZn99LPc1R6qfcO/+lqQ+9n2hjSnvyHFbZi4+/KZiYsO5ylPv/6yeDsPdI9BI9oNw/wb543q4FNyl9U
pNt7P/90HB7pF9CC3GJO0tsNWavfnX1RoxhdFcm+vZkGxbm0zzudo35chf7MfX99P7seAmE8Ix1FexZ184O/z8FqmFRgg2Pw02Lb
PnHICXKaGa4D8t8Rp3N4qhk5aQ5r+uAuu/HfCnclO+Quejqp9ZVxp+9zVk0dHA4+f1UybWZg13B2qky6imwc+F3JEse76291Grfq
3ZRabn/O5kE9sWjGr1Nn798evNbtfLfSzdwaEbTltMz5L4f387f3+zvZjc45n9j/xL6T4/OJfWex5xP7nzfyZVdmL9RmJjXazKTH
YZzGMi7jNl7ja3TXcNdwl6faBiY9ur5n7IBWDzPQHPsbp7umu6bfNd073Tvda662gUmP7ip3lbvKXTI5/HpArql9i9y36H2L4Lfo
fCszir63CHyLwrdIfIvGt0bWO/g1mW+R+BaNb5H2Fm1v0dcWbW0R1xZNbZHS1sgpo8W0RU1blLRFRVtktEVHW4S0RUlbpLRFS1sk
tEU+W/SzRUBbFLRFQtvjMfaV0MYxvIuh1jG8keFdDO9ijFzZ38FOZkAhBwf45VQ73+xVusqKRdBnqI533vK76yc18SIOl3vskb88
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
Qo9nuMIGTP3ZOuLnFzcDW6nxsuEUtp3sOkcF88V5bo3zv545Zto206APwRH4JEw8k4lnMvkkTD4JE+dkOqnhi/boXtUwiNuESkwV
winjTeyUqd44cVQmjsrknzAxVewta3JRmFgrE2tlYq1MrJXJS2HirnRJzuhesxqDZWKwTAyWicEyMVjm41ROKT+xWTpNG/veaABx
WiZOy1TDnKqaPUGNx3iNr9G98gyWy8RymZSGE9dl4rpMuO2EI0xcl4nrMiGPE29h4i1MvIWJtzDxFibewsRbmFarib0wsRcm9sIM
qmINmtgLE3thYi/M8N/CHMNemNgL0z5k4jBMs2XCj2YYdDgM02l9Rg9oZZzDfgbKXCoAYR9p//G3etqT6Fb/PjiB+s7jpXc3aVw1
KkKOJZwo2t+gY+FLdWhSX9rzJNvAQG90oE5MazhnveGMXSesE9UnDl4/mYvPfL/fKa9PFg/uClbwbm1UV0RxGvtkEQ1sy+GcaHrn
AJfRIqSwcWr+cog9gBX5YiYcXPqTnVVQADvAjaetvWYnxTAfKDUef4sKD9XA4I1QKyrLPk8dDro7isLUP2U8eu2iqy3tNbseNTGl
uxKF+VBRLz5OQ85Wz4Dvm4c7iPYJ0/tXaw3W38/5P3WGbAzbStU652JqF6e/2nbsx7lGG9m/PVV4Jo9KTk6+1B9/q+e/njnmmzUL
sjaxXyb2S06+015uYr9MrhF9qDO611vw22e+FV7E5CYxMWSmv3TiyUw8mYknM/FkJhXYdDLtTXCPcg6XiYk5MzFnJpxi8p2Y9snT
XzexaCYPiimvTvW0OeQcjJqJUTMxamZ44xg1E6Nm0t9NvJqJVzPxaqZzt/nZ4zYe4zW+RvcO98o8mAwNihjdK/Pwr5jYODOVfGyc
Ca+Z2DgTG2dCb6eZOXFyZhTKHC0mZs6c8g9+zsTPaWKZ0b3yz5R/MHamuLCH79G98k/2DNClyQEj/JA55Z8p/2DyTEyeaT5Pu/qC
H4UHVSdrK53Uf8rQXkknrk7n2N7u2aVn11o5wcFr7OoTCypCxxPQ8Kv05Z6TF+tuJPcvkvu8sGCLjzmsm3fDVlA8vF/KizdnbYzc
TQ84KkrquE/3bNFgdHI6mtofz/gR3Rl0fqiK9/8ea1xhhhTmidp+d8gM+tM7DTsHjXTnFw2+mnbR9HGZ7pr26+mpBUXHp6JC2c3x
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
TSOdkekCUm3D1dH7JpjLhox8+CSvndX7pkeGbp7y2KaseVL3g9q/KjDxkOfA1kS/4e/FZVrpsUWj6vyYPoA6U9RPLXv06qKotYvj
1tLPJ12taWD5mHHReaJUjbP3wdnGBX3VeW7UK1Dmh2LucXo9fCBfFdQT3tpIPQcv620P9o1JstOhHpNkY5Jse8WNSRLXkY0dsfFJ
Nkxh24/tEX9mGhYrwsYn2fF+t1fc+CRbTXtjlWyV+XRxha/16F5Rj1uycUs2bslOTyLcko2tsXFLNmfm8Bw2bfiOL7ScH0XMxqTa
6oq4oD26XmZQ69vYJhtzgMtlC6fclZrh6y75AZdg4xLs9C7BJdi4BBuXIPz/HYZ/PAowCjZGgXda0UJuXIKwXrc63qYZ36lCWF/2
TH+0+IGbt/GipBzfWAQbi2BjEeh00KN7ZY/wYzEKNkbB5rq80zOXrpzzbY/uleFxDDaOwVb13TTmG9Ng23vvA11VAzzp61HZvd94
rU9+pHEPphxZ+YvisJQ6atcWnh8GrZ7Q8+rqR/PEiUu2/5707P67svFuaHuPp+L1wYeclvNtllc39Hg5i6qiQJdo09706YOnPOFL
iKZPLSXOSCeupzOsOZVwq+ejr9a9MgmsP/sTWMzftuINqlJwLt7mmJMYbg+H0ie+ATx28gyPiLv2Sxz5muGs/10U1jP9ysM3hmeF
U5Q1l1K1z7xtZPXZp6X/FL9QbD3o8HaK3zcequkdn46rcW/j1KSaN6Ne3NH7LBW5PiVdaMJrD/n+/naqBxjHy9nsHelz8cWNn+dz
eMsrPUA753jmG0dl46jsn8eyrOLtbxyATWOePrCUsD26N30l5JaZGSW30JhTtfToXrkFX2Xjq2z6PirXHt3rmVCdw1h7dO+Ju4h7
5ZYZx3sz3Ml9Y1NszJMd1hnOCd/LFvz5HLGPYaKXYo9xzu8rYYKbrpyHdo/beIy5pj/tt2aJegyBOFZt3ICNGxCfTMrrXt2yxg2j
u8Q7hsCPjUaNvvEE0sVyYwjQBVSYLRtDYGMIbNyAjRuwcQM2vDIqyO0tY9YVl4Ye3eV9pbMknsC2A9l4AhtPYEOaNp7AxhPYeAJb
dG88gV36VUXbHmyFezDnkCaTPlxZOH/GFRCzXa2p3p/yLogAVCudm/jupn/c+vkSw7udztIb/eYUNqKeDloEz9Ive2Y3peNAGAtq
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
6IbWo3uj/ZF/btav6IuD+6z0xnVvPKzkn5vdiHfNLWfjMu37Q5RUIFeQaFFPY5j5CcX7er80VQjbyEE2WDgwr1OGM8LFWMOkOurw
I330dEKJXm9jGwZ5V/mcnPy7fnJkIRqfN5oCe37uoOlnlF3oSxcZtl764lWwrfQJxfC/P+e0qw5zMIF1mps5a6QHKH9mdQxz+Iyw
gp0dKDLeRg9nXO/iYf6M9KM/UUM4baWWnm4OuDdqCJ/OWYezxIFlx5Vubtkm/VCcmi/U9aTn12sfkm5ZWHmHT8jAfTrpzxW8FTPt
dYqZTspvuuhiEKX37v2pO5N7aU7tNM6H+5damZzz6C50nK2enTmg33qlnvb3bP9W+r9vuHVB/Rv/oqNHP2+91Xaa23gsG49lh9vg
nLid4DY2i9WqR6f1cK1FH07LlnU3Hsvm17HT449XxsZs2ZgtWwV+f2EZiTKuAptjxsbr3hgveB09uqvCSnK9yMJ74Qjdo7tEE8bL
TrfTOMLxZtzfr87geis4D42ND7O/dIq3gmPF7Kwp9qUbC2Ljxmyr0saHSU/JDa/ZeBEbK4aKtkdXilzd2Dc+zMaH2fgwGxNmY8Js
PI0d701MmI0JszlpbDG7OWls3IYwZjfflY3b4LTSo+u903AbuGocDIejCnowHA6Gw0kfFgjvwXM4eA4HUqNzStu5uXe4d7g3OPLD
3+lNlSb+VJzi0h1y8E55w5P3v/19RPrkMzl1T258+VXJ5EpXKiG6RD1BkHVliocnft21Xv+6kfp7v7ik2qM+HREtag/nX2VmXj+B
Ih1jEKKfj2V628UfA47GrWvEsedNxyh1J3sPKNVQKXpvqh/h7t6gaYWRiG8ThvaIgyhXh41ZtFJ70WcT10iH8UGnMMJMxs0bTzyF
DudSn6k+M+KHr4YzBoYz35vheQ47sQFFetIxxHnnoat6RrqmesJ55lOdTfX7wXB4xhevkvQZN9Kd8ZV9nBCfmS7kPi0cwqmmRCn/
hHP16T+YztF/8+FfzxzzjTIdZwZDu0fzjfIUc+ZgzhxeJQd/5uDP/M7UeFDHLuvod3BUFA9GDbVvnShnOboc7JqDXXOwaw52zYEI
HPWxg2NzoH4n6l1776NKyRWhR/dynObuEr/Zkx70GDgHA0cnkR7dq1sQp44Tl0tsHMylboHrXqunlSKrxomSDqvzYOkcLJ1jpThW
+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
mQ+zVDkpHsvCEiz+zArjApOnVISpW98BY6fEo6tXX219K9IqNl0i18V7XDiEhV1WPJnFS1xmjTQXULRrS01UDTt6F/JSpxzYKZdw
yp6bcvqmvMIpc3DKxZvy6frI8fl1nN3qV97KLMn6W9T8ZMRM2UNTXsyU4zNl203ZMVNW0ZRhN+UWTZl3U1bRlIkzZcxNOXdTPtGU
TTNl1U35O1MeypSH0lpn6jLPq0U2ffar6n7uM/EE5M5M7P0+rpZ63s/hs7vIW2Pd53JcrSvv7u19R1d29he3q4W/SwmtV9oT93Vi
sE/7x4k53EfWr5XWaKvqaXg4iXVzFeyTUkTi1SSFxqTtkNgyedVf6TAknkxSYEgKDEmBgSetbbKuI/te7DLFLlPsMsUuU+wy8WcS
fybxZxJ/JvFncupjt0qjKGfi0qjR3Fbb1FaUgWJDXv1tjJoUD+XTa6utGISdcopIJo5NipYmPYfEt+GRW1cJPPFtUhQ1sW4S6yZF
VHPdOrOep+hqrqseDBnEWFOMNbFuEuuGl++zkEG28q0Vkng4qU4EL2Jbbae2U1tvCksnsXQSSyexdBJLJ/+qTNIowNLh52yrrfd7
K4Pg6vBMttV2a6uaEr8ltvm8lbtfHD/ejInXPXk/JpXviX09ccsnRvfku5j0wyc29cTZnljWM26NPDssHo8pA31SUZgY1xPvdFJR
mNjgEzN84nJPnOqJRz2xW7vMr+NiN3Znt4oBVdWJyzrls0887YmbOmk1TIzQiSH5WVEeezFcza566Yj40dRqiOOIceOtTSy1GVcb
h6r8VecLPmT8zInP1lVNXZOPvXv+xOyaeGITv6vZBQeXYKpXNdj7Wd0Z1+G5FXmcYpRTnGiKE03xoHnjOy8/4ctDCLsW1Gor6+fq
Tsu74QOEUYuuY+ccyRVaV0n+ZiH5lgeM9wY6tY1f9xz9jdoGrk7i6iSuTuLq8Hi31d+O/qZ6IK5O4uokrk7eitW4OjQb22oLhXB1
+NLbavveuKS2oS0swtVJXB1++I5R3ugkVRCje99qqsYgXkrioqR1fmKe3EpkvPFtxSXX1RVxppGFc5I4J0nzITEH0h4hb+VHrABe
+sVv3/Sxq0ziW3d0a8mJ3afYfe6rCQkhRe1FCpZIQVtnQkWR+pR3f6t4p91EitGnuHyKyKd9RNpBpJh72kekmHuKuac9RdpNpH1E
iq2n2HraU6Q9RdqbpNh62l+k2HraZYg7tNXWU72VjOw4RCK6F+l1ck949l6eujduhnvHOI7KU6r4tT2sI/ImxIPU6WsrR0mWolhP
8RdVWdsUZg40K4ziEiM7t3bDYz0g9kSdbNJ06upRd03iM+X2catKiQrduXupB6dK3dUdfbEZX/UL3nFr7976C1dZ/V4/7mdnWhXg
5LxDzQXM3vfWC+YFomg0aR99f9Fq5Kqk9rww6b20pVi1r5Iw7SnPlnbH+1eR4b3VHxy51RZ4m+WjvZQ9Xpzz92q33lpseErH/C7z
a6k82FY9Jho+ZvYD60qUrcTCamJSUT6sCetUPy9abbhJn7XiFVMrMbWiknqumj0mYVci+C2RrLZ6lBF3bk1A487+NO1P0840r9q/
PWneCmV2pnkroduZJuRMO9MUGU+R8Ty38jK0Obc6KrThv0ox8RQTz3NrOkMbMfEUE89z6/UYyzxayaOVPFrJo5V8WSnGnWLc+d7a
qUarKHaKVqdodYpTpzh1ilCnCHXeqiUi1ClCnSLUKUKdItQpQp0i1Ck2nWLTKTadYtMpNp1i0yk2nSLRKRKdItF5q+iKQYv1tHVl
SCiSmO+t3HRuHVjnmBfEDUWC2t5z/EXvQhwwxQFTHDBF/VLUL0X9UrwvxftSpC9F+lKkL0X68v2r/e2veM63dsOtDsCP3TSRVgfF
3HitCujmibbPv9i6tb345hTrnOKYU3RyikhOEckpIjlFG6cY4hRnnCKJU5RwUsSddGgntdhvRNjfqdhbfLlFmW2rFTXsPSef1ayr
Xs7PI9/hqirNuhWQeWzqap9uSun7futz0cqj4WB3rHrgdzy1fW+9Y9dP1wma8/ZumKvTrnzdbG775WWPzJfedWR4uek/2EcvNX2u
ptN6ruLuVbAP51DbkKPED9/HHZGzb4+8ZA8tGTpr3JryctVl8SxZQksG0JKbs64eoNyf1VlCswsA85/3/cK9RdFojT/N51un3tXk
p4v+Xy2pRTevSw7/uufoY+ZZEeEUEc5bHVU+eL535JpzxYVFNpsA/rBUYY1lUWDRz7aqURvX4r8p/ptivmktl2K+aUWXor0p2ptW
dxlXb9aIFu0VRW2rlXFtpSfG2pIA2hrXVnop2pvWeynam6K9ae2XVn0pZpfWfilal7cSqwhdmsfFbdu6gjWPGFyKwaWZPc3sKfqW
om8p+iba29ZfNOpvNWrRt7x1Q2S1p4hbiriliFuKuOXV0BZrS7G2FGtLsba8lUHE2lKsTZWitlp5m6JsKcpGV3yprNS2ry+ylqJp
5v22Lxusc7xBEbQUQUsRtEWzcdHIwn+e+KUTs3TiiE680Hm5mjUuZ7jfbMmAKxlwpbfXWLdepJgshLk1PtatLPNQOc77WZ1xq4ge
cZMC7aRGO6nLTrqyk4rspBk73WnXa0jWOkd0Hm8t7RAzxfET1yWxX9rD/33G4al9bcf3MYuy8GFkpBYd44IPZW+YVfd4e67kbZXY
XKnvWbcq37BXwver59Yo5xOjfF7ypMo+rsZdb/Ah24WlnI4sZ6oNUfKb1MmdauZOVXGn6rfzVr8dMnkHP57aFm2LZnuwrXoqB3PQ
4B0QbPzpuvecNXj/BoWKIV9yyIUccGzIWxzyDcfNhblVab4l1G+pldxWTzP2xVtTpDVFWr2dtvqksS/SmiKt3mAnlDjfSBdXTXHV
xHZI0bEUHUvRsRQdS9Ex77etK5vTsSNSjCzFyLz9z5rlxchSjCzFyFKMTG9Zt45SipGlGJke9VnIIEaWYmQpRqantdUWPoiRpRhZ
ipGlGFmKkaUYWYqR6YdttYUYYmQpRpZiZClGlmJk+efthBtiZClGluJieWsZiHylyFeKfKXIV4p5pTiXUdD2sC97q7ndM/vvinOl
OFeKc6U4V4pz5a09Lc6V4lwpzpXiXCnOleJcKc6V4lxpbZDiXFnzMt5Z+T60f7eK1duqZvM9bn7OLWd58xhvGccbf0PV+w5D4Qav
yw0edmSqCfdzmJcNG3+cWDy9W7NJvUssJvrqi8bXoi3ctqui0OK7St2PWeAxmzxmkyf+at45omaT+eXBrHhwPB4zyGPGebA7Hoj9
4BXc6lQPfH7MRLTo+5x7pm8n2/3k0bsePefRYx8959FDHn2DymuTAnzbPeQRMXxEeR7v5blVq6ypqBf2574mfs6waqLr/tlvhG71
xL81RwXbn60ZHhHGRwzxwe1/+BAe8UTK0k1ScKZfxRvw2Nc/dvrPrY1lF/+I2j92TI+d+GNv/tglPd8e59c9R3+DG2Kjac2WYqPp
TlNsNMVGU5wrxbnUi2+rLTwR50pr0RTnSnEus0NbbeGJOFdar6Y4l1mjrbbwRLQrRbtStCs957T6TdGuFO1K0a4U7UpvIUW70ltI
0a4U7UrRrhTtStGuFO1K0a4U7Uor4RTtMostteaXuayttvBEtCu98RTtStGuFO1K6+oU7Uqr7hTtSuvqFO1K0a4U7UrRrhTtSj0n
xbzMlW21xXyzqi+rerNnW5V2G4vK+rz0txLzKjGvsoYva/US8yo9s8S8yr6jnlu5W/aQmFeJeZWYlxm8rbZTf3uv1buMMrzr59ye
qdYePvZjJ/vYhz6Y0o+9JN3yrqC3xIIfVox4+XxjxM6nrPuYeVVt6BLivWexd56uP9+/6quO2PHZ4U4734lrPe1e5/tXm08VKmo/
d8Zxd+nukgZI+g35/NWhE+kzUiiBJCWQpAOcageknVHaAaXfrFrxwpRemNJtnakPU3NNCq5pLYFf3dY19VXa/kn9VY2/ts7US+k8
JJ2HtPZIiq9JzyFvvWBKsPncSqb6G22HhO1pF5Z0HtK6BU+7rRilmY7OQ9J8SDu1pPCQFB6Smnpa5yRth6SgnhQe0t7ts/PXPedW
n9ffrHI92/KcyxMuz6rsGctTKk+p6F0UhVurxLaOp56MQeTeS82Com5RVmVWj2315NK2tC1t5dl5GiV6a83ZVlv1SsRzy161PJ/y
fMrzKU+mPKUS7bWCbZustkafJ1aemHVpW22NPk+vPL3y9MrTKwq9RROjaGIUBYzi/yy74KJ6UfbLRfWixJqtltvezETnb38Lp4vn
sOypy566eBGL6oX1dlvX90Z4F8u8f6u+FgUMq/FOd9bW+6KAURQwigJG8UNe1d/ieyzeyOKNLGoYRQ2jbl02nsmihlHUMGQEtNUn
jUpPIz0N1bfb+tZs5WmkJ5CeQFqBp7tOTyDdb7rfdKfpTtPdpbtLd5fuKN1RuqN0R+mO0r2k36+e1JLj0NY55g4cmOSFSL7WVD08
R914rvONx3FHot2o2gFJdSHpLaR6AXIZVt4KwvQWclpbTiPRPjTVC0jaC0l7Ifk6kvaCDIiOETvHM+SPSrpkSZNBbkXbG03WypOk
1SCroq0zPU+VAvLWPqbbkHQbbj3TpNsgO6OtMz1humepMsLDu3LXRdjmXQ1QhcG+u0GDYoh3j3kz8e25/NrxV5Gw39S3jW7MoaBi
n9hWf8M/pKNSFFRKPL28kfKOyjsqb6f89VJJuWhiFE2M8tbKWyux+PLuyhspb7C8wfIGi4ZGucdyF+Wdlgh+ebPlzRY9jaKnUd5y
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
gm+FdVZQrrDOCuuseOcK60yEoq22sIjXruB/YZ0V1llhnRV1hcIgKgyiMpsUL19hEJVZo8wahUEkQ6ettrAIg6gwiGTutNUWFpll
ysxSGETFZ1gYRGX2KbNPYRDJ+mmrLSzCICoMosIgKgyiwiAq81R5U4VBVBhEhUFUGES3EllhEMknaqstLPJ+5Ra11RYWYRAVBlGZ
B9VnaastLMIgKgyiwiAqDKLCICoMosIgKgyiulVxMYgKg6gwiEqPKgyiwiAqDKJj1B/5rccIPbzf52aF2D0lVkzaV+Z7j7w3a+Nm
ZNz8Cxz4uHz4y2DHo34uax2rzfybYkY9y7S9xztylCJHPcu0debemG/9uXnvbWXHiIlTicxzefjPzXPBF7pZJFfrdVzdy6taefXZ
roLZVYC5ek1XJ+FqC/RfaY7NxiNq27+tfVltBytq/IbPzo++i0e0rtkmbSe7WeeI2T1ids0haXuP+ysid48o3oPv1+yRLebVdrGb
PWywzhTR67hYW2eK6w1PbIjuNVekbbJaTeeL7g3RvQHth3c0RPdaZbHtPa7tqsYc8xePd2Gd0VvrQn/u0S9//PLHL3/88scvf0Qh
H7+/WWdttXUXj3Xa414e9/K4l8e9PO7lcS+Pe3ncyyNe+YhXPu7rcV+P+3rc1yN22QyittqKYzaLrK227v1x7497f9z7oyLto8c+
nsOjxz567KPHPnpsRx/aaru13dqKhHb0oa22oqKPqOgjKvqIij6ioo+o6CMq+oiHNseprbbipM3Sb+v82xtf54TrhOPhCqFVOp6O
pPPz9lvf1u1jestz+4keOK913NMbnt7w9IanNzyf4fkMdz3c9XAvw70056etq3luY9/P+pvnNjy3se91/BXPanhKw1MantI49/rO
9Ewu68YuMu0K054u7enSyjytftPaOK2oEwLkXffybBSuYL365/k7zpor+VdLPl1hDxb/RsmtKxlzZX9R792Vm3co1xWuclGoK36n
wlim5tGsKvyQvPyNy2rAQLg+Olfgay1el6KWWbwoRfGy+GBp17Tfw2+w2uS/pVrT9tgH4RWLH61x13gi+HrIgVpHD7kqu+ltvsbv
fTLve22yuMphbwUhX33vzfv5fut8qPi6chhH4S2H9xv6Rnib7WdoqxJ0zF+/X+9dbx/v7VH6gF8y/JLhlwxYPfyS4VcNI2L4VQNi
D+Ni+FXDvQ+/c8Dw4ZcPv3Z4JsMzGZB8GEHDXQwjaBhBA8IPCD+wMsYdU9B+QPsB7Qe0H9B+QM4JOSfknJBzQs4JOacnP43N6flP
I3RCzgk5p9E6IeeEnBNyTu93Qs4JOSfknJBzQs5pjE/IOSHnhJwTck5jfxr709ifxv409ifknJBzQs4JOSfknJBh6m/TG5+Qc0KA
CQEmBJgQYEKACUOmXjehwdRPJjSYkHPqMxMmTJgwoc2ENhM+TPjQXKBDVexQFTtUxQ5VsUNV7FAVO1TFDlWxQ1XsUBU7VMUOVbFD
VexQFTtUxQ5VsUNV7FAVO1TFDlWxQ1XsUBU7VMUOVbFDVexQFTtUxQ6FqEMh6lCIOhSiDoWoQyHqUIg6FKIOhahDIepQiDoUog6F
qEMh6lCIOtY2h07UoRN16EQdOlGHTtShE3XoRB06UYdO1KETdehEHTpRh07UoRN16EQdOlGHTtShE3XoRB06UYdO1KETdehEHTpR
h07UoRN16EQdOlGHTtShE3XoRB06UYdO1KETdehEHTpRh07UoRN16EQdOlGHTtShE3XoRB06Ucca71CLOtSiDrWoQy3qUItqO34b
O+KzZq4JnaY5d8KiCYsmLJqw6K4JJyyasGjCogmLJiyasGjCogmLJiyasGjCogmLJiyasGjCogmLJiyasGjCogmLJiyasGjCogmL
JiyasGjCogmLJiyasGjCogmLFixasGjBogWLFixasGjBogWLFixasGjBogWLFiy6XLgFi+5cs2DRgkULFi1YtGDRgkULFi1YtGDR
gkULFi1YtGDRgkULFi1YtGDRgkULFi1YtGDRgkULFi1YtGDRgkULFi1YtGDRgkULFi1YtGDRgkULFi1YtGDRgkXNjDrUxg61sUNt
7FAbO9TGDrWxQ23sUBs71MYOtbFDbexQGzvUxg61sUNt7FAbO9TGDrWxQ23syE04chOO3IS22k5tp7ZT26nt1HZpu7Rd2i5tl7ZL
26Xt0nZpu7Td2m5tt7Zb263t1nZru7Xd2m5tj7ZH26Pt0fY+vaPt0fZoe7Q92r7avtq+2r7avtq+2r7avtq+2r7ahrahbWgb2oa2
oW1oG9qGtqFtapvaprapbWqb2qa2qW1qm9qWtqVtaVvalrZ1fhsvtK3+Zv5aVv4LFi1YtGDRgkULFi1YtGDRgkULFi1YtGDRgkUL
Fi1YtGDRgkULFi1YtGDRgkULFi1YtGDRgkULFi1YtGDRgkULFi1YtGDRgkULFi1YtGDRgkULFi1YtGDRgkULFm1YtGHRhkUbFm1Y
tGHRhkUbFm1YtGHRhkXX879h0YZFGxZtWLRh0YZFGxZtWLRh0YZFGxZtWLRh0YZFGxZtWLRh0YZFGxZtWLRh0YZFGxZtWLRh0YZF
GxZtWLRh0YZFGxZtWLRh0YZFGxZtWLRh0YZF+46m0vdK3yt9z7w2zGvtVThydo6cnSNb58jcORQIj8ydtslqC5cGXBpwacClAZcG
XBpwacClAZcGXBpwacClAZcGXBpwacClAZcGXBpwacClAZcGXBpwacClAZcGXBpwacClAZcGXBpwacClAZcGXBpwacClAZcGXBpw
acCl4UkOuDTg0oBLAy4NuDTg0oBLAy4NuDTg0oBLAy4NuDTg0oBLAy4NuDTg0oBLAy4NuDTg0oBLAy4NuDTg0oBLAy4NuDTg0oBL
Ay4NuDTg0oBLAy4NuDTg0rdz+XXP0d/MX9v8ta2lNyzasGjDog2LNizasGjDog2LNizasGjDog2LNizasGjDog2LNizasGjDog2L
NizasGjDoh2X/e5bCLOhx4YbB0qcu2d/Lo8dz/zGL+ZlpzvHqDxG5TEejzF4jLhjrB1j7Rhrx1g7xtdx78e9H/d73Olxp+e9DPbL
XXemOz3u9LjT406POz3u7ri7A2MPjD0w9sDYA1cPXD15d+jOhKgHoh6IeiDquU/jZgFA0QNFX8/nhaIvFH2h6AtF3+fu7u3lIecL
Od8bM/Uk35vRcL0HMPOFme8d6ea1YV4b5rVhXhvmtd75HvlKRxbSkbV0ZC0dWUttBzvZxW72sC8bbLLawqUJlyZcmnBpwqUJlyZc
mnBp+rUTLk24NOHShEsTLk24NOHShEsTLk24NOHShEsTLk24NOHShEsTLk24NOHShEsTLk24NOHShEsTLk24NOHShEsTLk24NOHS
hEsTLk24NOHShEsTLk24NOGSna+cqUPP89DzbKstXJpwacKlCZcmXJpwacKlCZcmXJpwacKlCZcmXJpwacKlCZcmXJpwacKlCZe+
Xcyve46eZp59zbPvvNF5Pc08+xq/r3n2Nc++ZtjXWH7Xjek731h+zaqvmfQ1k77G9WsmfY3u17h+r0fLHPqaQ18r+RcSvpDwhXvv
ud+6Jqx7jf0X1r3G/mvsv0b6a3S/EOyNe9wVjO7XqunN6x9zjtH95j3nZv070+h+je7X6H4h3mu99BrprzEexnUY0fHciAnvmXEd
UDGeeybfmtEdRneMG1vR1roojO7wdsJ7Ce8lvJHwRsIbCbga3kV4FwFXwxsJbySsdmJdj59rei/hvYT3Et5L3FiPtxPeTng7AXvD
2wnvJW6fN69N89o0r03z2jSvTevtCZcmXJpwacKlCZcmXJpwacKlCZcmXFpwacGlBZcWXFpwacGlBZcWXFpwacGlBZcWXFpwacGl
BZcWXFpwacGlBZcWXFpwacGlBZcWXFpwacGlBZcWXFpwacGlBZcWXFpwacGlBZcWXFpwacGlBZcWXFpwacGlBZcWXFpwacGlBZcW
XFpwacGlBZcWXFpwaXlHdxe84NKCSwsuLbi04NKCSwsuLbi04NKCSwsuLbi04NKCSwsuLbi04NKCSwsuLbi04NKCS9+O5tc9Rx+z
qgmjO6xqwhgP65kwusPMHmbzeO+3+qExHmbzMNLDiiWM94jrr9bKqA8ze+TVX9LKzB5wIIz9uP5wCBAQICBAQICAAAEBAgIEBAgI
EOb6uDhgrk9zfcKENNcnZEjIkJAhIUNChoQMCRkSMiRkSMiQkCEhQ5r9Ez6k2T9vVBdWJCRPiJEQIyF5wo2EGwk3EpLn1TmB5wlD
Em4k3Eg4cOMOCQcSSic0SGiQsDphQlq1pveb3m96v+mdJtxObzYhdr73W1f2fps11OJ5+dk+p2Xq1mfbS9kUktuX9D3z2jKvLfPa
Mq8t6+0Fl9Y9Hy4tuLTg0oJLCy4tuLTg0oJLCy4tuLTg0oJLCy4tuLTh0oZLGy5tuLTh0oZLGy5tuLTh0oZLGy5tuLTh0oZLGy5t
uLTh0oZLGy5tuLTh0oZLGy5tuLTh0oZLGy5tuLTh0oZLGy5tuLTh0oZLGy5tuLTh0oZLGy5tuLTh0oZLGy5tuLTh0oZLGy5tuLTh
0oZLd0e84dKGSxsubbi04dKGSxsubbi04dKGSxsubbi04dKGSxsubbi04dKGSxsubbj07W5+TSaa/7Rd7GYPG2y1/Z5tW99+T6mt
Vkur5fzv+bR1/nb+90y+PXa/cRmCR4bgkSHYx/Ofb5/8vYtvz/z1zO/I90vaOud7g6PJYZ/t0TRUq+9vte1Wu3kX3w65+4Nsr+/I
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
# NW_GB_TABLE_END
NW_ENCODING_DATA
