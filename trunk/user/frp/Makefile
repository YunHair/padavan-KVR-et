THISDIR := $(shell pwd)
FRP_VER := 0.51.3
FRP_URL_BASE := https://github.com/fatedier/frp/releases/download

FRP_NAME := frp_$(FRP_VER)_linux_mipsle
FRP_URL := $(FRP_URL_BASE)/v$(FRP_VER)/$(FRP_NAME).tar.gz

all: download_test extra_test
	@echo "frp build done!"

download_test:
	(mkdir -p /tmp/frp_dl; if [ ! -f /tmp/frp_dl/$(FRP_NAME).tar.gz ]; then \
		wget -t5 --timeout=20 --no-check-certificate -O /tmp/frp_dl/$(FRP_NAME).tar.gz $(FRP_URL); \
	fi )

extra_test:
	(if [ ! -d /tmp/frp_dl/$(FRP_NAME) ]; then \
		tar xf /tmp/frp_dl/$(FRP_NAME).tar.gz -C /tmp/frp_dl; \
	fi )

clean:
	rm -rf /tmp/frp_dl/$(FRP_NAME).tar.gz /tmp/frp_dl/$(FRP_NAME)

romfs:
	$(ROMFSINST) -p +x $(THISDIR)/frp.sh /usr/bin/frp.sh
	$(ROMFSINST) /etc_ro/frp_script.sh
