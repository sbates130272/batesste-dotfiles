(require 'package)

;; Proxy: respect HTTP_PROXY / http_proxy from the environment so that
;; package installs work behind ZScaler without manual intervention.
(let ((proxy (or (getenv "HTTP_PROXY") (getenv "http_proxy"))))
  (when (and proxy (not (string-empty-p proxy)))
    (setq url-proxy-services
          `(("http"  . ,(replace-regexp-in-string "^https?://" "" proxy))
            ("https" . ,(replace-regexp-in-string "^https?://" "" proxy))
            ("no_proxy" . "localhost,127.0.0.1")))))

(setq package-archives '(("gnu"   . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

(unless (package-installed-p 'rust-mode)
  (package-refresh-contents)
  (package-install 'rust-mode))

(unless (package-installed-p 'yaml-mode)
  (package-refresh-contents)
  (package-install 'yaml-mode))
