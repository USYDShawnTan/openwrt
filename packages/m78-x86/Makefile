include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-m78accelerator
PKG_VERSION:=3.0.0
PKG_RELEASE:=202604101735
PKGARCH:=x86_64

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-m78accelerator
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=M78 Accelerator for OpenWrt (x86_64)
  DEPENDS:=+luci-base +luci-compat +luci-lua-runtime +curl
endef

define Package/luci-app-m78accelerator/description
 M78 Accelerator client repackaged for OpenWrt 25.12+ APK builds.
 This local variant intentionally supports x86_64 only.
endef

define Build/Compile
endef

define Package/luci-app-m78accelerator/install
	$(INSTALL_DIR) $(1)
	cp -fpR ./files/. $(1)/
	$(INSTALL_DIR) $(1)/usr/bin
	chmod 0755 $(1)/usr/bin/netflow_x86_64
	chmod 0755 $(1)/etc/init.d/netflow
	chmod 0755 $(1)/etc/uci-defaults/luci-app-netflow
	ln -sf netflow_x86_64 $(1)/usr/bin/netflow
endef

define Package/luci-app-m78accelerator/postinst
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] && exit 0
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
if [ -x /etc/uci-defaults/luci-app-netflow ]; then
	/etc/uci-defaults/luci-app-netflow || true
fi
/etc/init.d/netflow enable 2>/dev/null || true
/etc/init.d/netflow restart 2>/dev/null || true
exit 0
endef

define Package/luci-app-m78accelerator/prerm
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/netflow stop 2>/dev/null || true
/etc/init.d/netflow disable 2>/dev/null || true
iptables -t nat -D PREROUTING -j NETFLOW 2>/dev/null || true
iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 7874 2>/dev/null || true
iptables -t nat -D PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 7874 2>/dev/null || true
iptables -t nat -F NETFLOW 2>/dev/null || true
iptables -t nat -X NETFLOW 2>/dev/null || true
iptables -t nat -D OUTPUT -p tcp -j NETFLOW_OUT 2>/dev/null || true
iptables -t nat -F NETFLOW_OUT 2>/dev/null || true
iptables -t nat -X NETFLOW_OUT 2>/dev/null || true
nft delete table ip netflow 2>/dev/null || true
killall mihomo 2>/dev/null || true
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache /tmp/netflow_*
exit 0
endef

$(eval $(call BuildPackage,luci-app-m78accelerator))
