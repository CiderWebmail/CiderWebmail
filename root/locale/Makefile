LANGS := $(wildcard */)
all: extract update
extract:
	find ../templates |egrep '\.xml' | xargs i18nfool-extract
update: $(LANGS:%=%LC_MESSAGES/CiderWebmail.mo)
%/LC_MESSAGES/CiderWebmail.po: CiderWebmail.pot
	i18nfool-update
%/LC_MESSAGES/CiderWebmail.mo: %/LC_MESSAGES/CiderWebmail.po
	i18nfool-build
